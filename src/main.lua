local G=require('geometry');local V=require('view');local S=require('settings');local P=require('poi');local R=require('route')
local Roster=require('roster')
local D=require('dungeon');local dungeon=D.new();local dungeonExits={}
local clock=Engine.clock
local settings=S.validate(api.settings)
for key,value in pairs(settings) do api.settings[key]=value end
local valid=Engine.valid
local loadingGuard=require('loading').new()
local pc,gameState,view,mapData,mapName,bounds
local bossLoader,route
local progress,nextProgress={},0
local bossCacheKey='minimap.bosses'
local calibrating,calibrationName;local mapBounds={}
local controllers,states={},{}
local members,points,pointQueue,pointSeen={},{},{},{}
local head,tail=1,0
local outdoorScale=288*settings.zoom/(40000*tonumber(settings.dezoom));local scale=outdoorScale
local nextSlow,nextSample,nextMap,nextPOI,nextLayout=0,0,0,0,0
local status={members={},visible=false}
local function objectKey(o)return valid(o) and o.key or nil end
local function vec(v)return {x=v.X,y=v.Y,z=v.Z}end
local function text(v)return v end
local function cachedBounds(name)
    return mapBounds[name] or api.cache['minimap.bounds.'..name]
end
local function enqueue(o)
    local key=objectKey(o)
    if key and not pointSeen[key] and tail-head<2048 then
        pointSeen[key]=true;tail=tail+1;pointQueue[tail]={object=o,key=key}
    end
end
local function reset()
    if view then view:destroy()end
    pc,gameState,view,mapData,mapName,bounds=nil,nil,nil,nil,nil,nil
    bossLoader,route=nil,nil;R.clear()
    progress,nextProgress={},0
    calibrating,calibrationName=nil,nil
    members,points,pointQueue,pointSeen={},{},{},{};head,tail=1,0
    nextSlow,nextSample,nextMap,nextPOI,nextLayout=0,0,0,0,0
    status.members={};status.visible=false;Roster.members={}
    dungeon=D.new();status.dungeon=false;status.stage=nil;status.mapReady=false
end
api.on_stop(reset)
api.on_toggle(function(enabled) if not enabled then reset() end end)
api.on_travel(reset)
api.watch('PalLocationPoint',enqueue)
-- One bounded-category seed when installed into an already running world.
controllers=api.objects('PalPlayerController') or {};states=api.objects('PalGameStateInGame') or {}
for _,o in ipairs(api.objects('PalLocationPoint') or {})do enqueue(o)end
dungeonExits=api.objects('PalDungeonExit') or {}
local function locate()
    controllers=api.objects('PalPlayerController');states=api.objects('PalGameStateInGame')
    if not valid(pc)then
        for i=#controllers,1,-1 do
            local candidate=controllers[i]
            if not valid(candidate)then table.remove(controllers,i)
            elseif candidate:IsLocalController()then pc=candidate;break end
        end
    end
    if not valid(gameState)then
        for i=#states,1,-1 do
            if valid(states[i])then gameState=states[i];break else table.remove(states,i)end
        end
    end
    if not valid(pc) or not valid(gameState)then return end
    local rider,body,mounted=api.game.subject(pc)
    status.mounted=mounted==true
    if rider then return body end
end
local function refreshMap(pawn,now)
    if not valid(mapData)then mapData=pc.PlayerState:GetWorldMapData()end
    if not valid(mapData)then return false end
    local name=text(mapData:GetCurrentPlayMapName())
    if name=='None' or name=='' then return false end
    if name~=mapName or view.mapName~=name then
        local b=cachedBounds(name)
        if not b then
            if calibrationName~=name then
                calibrationName=name
                calibrating=G.calibration(vec(pawn:K2_GetActorLocation()),function(p)
                    return text(mapData:GetMapNameByWorldLocation({X=p.x,Y=p.y,Z=p.z}))==name
                end)
            end
            return false
        end
        if not view:terrain(name,b,scale)then return false end
        bounds,mapName=b,name;status.bounds=b;status.map=name
    end
    return true
end
local function consumePoints()
    local deadline=clock()+.0005;local count=0
    while head<=tail and count<4 and clock()<deadline do
        local item=pointQueue[head];pointQueue[head]=nil;head=head+1;count=count+1
        local o=item.object
        if valid(o) and o:IsShowInMap() and o:ShouldDisplay()then
            local class=o.class.name:lower()
            -- Player locations use the explicit guild path above. No enemies,
            -- unreplicated players or hidden POIs are revealed.
            if not class:find('player',1,true)then
                local p=vec(o:GetLocation())
                if G.position(p)then
                    local kind=P.classify(class)
                    local point={object=o,key=item.key,position=p,kind=kind}
                    if kind=='boss' or kind=='tower' then point.bossActor=o:GetBossTower()end
                    points[#points+1]=point
                end
            end
        end
    end
    if head>tail then pointQueue={};head,tail=1,0 end
    if bossLoader and not bossLoader.done then
        local before=#bossLoader.points;bossLoader:step()
        if #bossLoader.points>before then points[#points+1]=bossLoader.points[#bossLoader.points]end
        if bossLoader.done then
            local cached={}
            for _,p in ipairs(bossLoader.points)do cached[#cached+1]={key=p.key,spawner=p.spawner,character=p.character,position=p.position,kind=p.kind,static=true}end
            api.cache[bossCacheKey]=cached
        end
    end
end
local selectedPOI={};local pruneCursor=1
local function choosePoints(origin)
    for _=1,math.min(8,#points)do
        if pruneCursor>#points then pruneCursor=1 end
        local p=points[pruneCursor]
        if not p.static and not valid(p.object) then pointSeen[p.key]=nil;table.remove(points,pruneCursor)else pruneCursor=pruneCursor+1 end
    end
    selectedPOI={};if not settings.poi then return end
    local half=settings.size/2
    if status.dungeon then
        if not settings.dungeons then return end
        for i=#dungeonExits,1,-1 do
            local o=dungeonExits[i]
            if not valid(o) then table.remove(dungeonExits,i)
            else
                local p=vec(o:K2_GetActorLocation())
                local x,_,_,distance=G.project(p,origin,scale,half*math.sqrt(2),0,false,0,true)
                if x and D.nearFloor(p,origin)then
                    selectedPOI[#selectedPOI+1]={point={position=p,kind='dungeon',style='normal',key=objectKey(o)},distance=distance}
                end
            end
        end
        table.sort(selectedPOI,function(a,b)return a.distance<b.distance end)
        for i=#selectedPOI,25,-1 do selectedPOI[i]=nil end
        return
    end
    for _,p in ipairs(points)do
        if P.enabled(p.kind,settings) and p.position.z> -15000 then
            -- Select the rotation-invariant circumscribed area, then clip precisely
            -- each frame. Turning the camera cannot make a POI pop in late.
            local x,y,_,distance=G.project(p.position,origin,scale,half*math.sqrt(2),0,false,0,true)
            if x then
                if p.static then p.defeated=progress[p.spawner]==true
                elseif valid(p.bossActor)then p.defeated=p.bossActor:IsLocalBossDefeated()end
                if p.kind=='travel' and valid(p.object)then p.unlocked=p.object:IsEnableFastTravel()end
                local show,state=P.presentation(p.kind,p.defeated,p.unlocked,settings.hidebeaten)
                p.style=state
                if show then selectedPOI[#selectedPOI+1]={point=p,distance=distance}end
            end
        end
    end
    table.sort(selectedPOI,function(a,b)return a.distance<b.distance end)
    for i=#selectedPOI,25,-1 do selectedPOI[i]=nil end
end
local function tick()
    local now=clock()
    local loading,reason=loadingGuard:blocked(now)
    status.loading=loading;status.loading_reason=reason
    if loading then
        -- Always hide before returning: an early return alone leaves the last
        -- Slate frame visible over teleport/loading screens.
        if view then view:show(false)end
        status.visible=false;nextSlow=0;nextMap=0;nextSample=0;nextPOI=0
        return
    end
    local pawn=locate()
    if not pawn then
        -- Possession can briefly be empty while mounting/dismounting. Keep the
        -- map and POI caches; world teardown is handled by onTravel/onStop.
        if view then view:show(false)end
        status.visible=false;nextSlow=0
        return
    end
    if view and not valid(view.user)then reset();return end
    if not view then
        for _,object in ipairs(api.objects('PalLocationPoint')) do enqueue(object) end
        dungeonExits=api.objects('PalDungeonExit')
        view=V.new(pc,settings)
        local cached=api.cache[bossCacheKey]
        bossLoader=P.loader(cached)
        if cached then for _,p in ipairs(cached)do points[#points+1]=p end
        end
        if settings.route then route=R.new(objectKey(pc.PlayerState)) end
    end
    if now>=nextSlow then
        nextSlow=now+.5;Roster.update(settings,pc,gameState);members=Roster.members
        local state=api.game.state()
        status.blocked=not state.playable
        local interior=state.in_dungeon==true
        local stage=interior and D.stageKey(pc.PlayerState) or nil
        if interior~=status.dungeon or stage~=status.stage then
            nextPOI=0;nextMap=0;selectedPOI={};status.mapReady=false
        end
        status.dungeon=interior;status.stage=stage
        scale=outdoorScale*(interior and 4 or 1)
    end
    if status.blocked and bounds and not calibrating then view:show(false);status.visible=false;return end
    local origin=vec(pawn:K2_GetActorLocation())
    local show=not status.blocked
    dungeon:update(status.stage,origin)
    status.trail_points=#dungeon.points
    if calibrating and not status.dungeon then
        local result=calibrating:step()
        if result then
            mapBounds[calibrationName]=result
            api.cache['minimap.bounds.'..calibrationName]=result
            calibrating=nil;nextMap=0
        end
    end
    if status.dungeon then
        view:interiorMap();status.mapReady=true;status.map='Dungeon';status.map_mode='local_trail'
    elseif now>=nextMap then
        nextMap=now+1;status.mapReady=refreshMap(pawn,now);status.map=mapName;status.map_mode='terrain'
    end
    show=show and status.mapReady==true
    view:show(show);status.visible=show
    if not show then return end
    if now>=nextLayout then view:layout(pc,settings);nextLayout=now+2 end
    if now>=nextSample then nextSample=now+.1;Roster.sample(now);consumePoints() end
    if now>=nextProgress then nextProgress=now+2;progress=P.readProgress(pc.PlayerState.RecordData)end
    if now>=nextPOI then choosePoints(origin);nextPOI=now+.5 end
    local half=settings.size/2
    local yaw=pc:GetControlRotation().Yaw;local angle=settings.follow and -yaw or 0
    if status.dungeon then
        view:pan(0,0,yaw);view:dungeonTrail(dungeon,origin,scale,angle)
    else
        local x,y=G.mapPoint(origin,bounds,scale)
        view:pan(half-x,half-y,yaw)
        if route then route:update(pawn,origin,mapData,mapName,now)end
        view:route(route,origin,scale,angle)
    end
    status.camera_yaw=yaw;status.map_angle=angle
    local count=0;status.members={}
    for _,m in ipairs(members)do
        if m.next and now-m.sampleAt<2 then
            local p=G.interpolate(m.previous,m.next,(now-m.sampleAt)/.1)
            local mx,my,outside,distance=G.project(p,origin,scale,half,settings.playersize/2+4,false,angle,settings.shape=='round')
            local sameSurface=D.sameArea(status.dungeon,status.stage,m.dungeon,m.stage,p,origin)
            if mx and sameSurface then
                count=count+1
                view:member(count,mx,my,outside,(m.yaw or 0)+angle)
            end
            status.members[#status.members+1]={source=m.source,distance_m=math.floor(distance or math.sqrt((p.x-origin.x)^2+(p.y-origin.y)^2)/100),visible=mx~=nil and sameSurface}
        end
    end
    view:trim(count)
    local poiCount=0;status.visible_points={}
    for _,entry in ipairs(selectedPOI)do
        local mx,my=G.project(entry.point.position,origin,scale,half,settings.poisize/2+4,false,angle,settings.shape=='round')
        if mx then
            poiCount=poiCount+1;view:poi(poiCount,mx,my,entry.point.kind,entry.point.style)
            status.visible_points[#status.visible_points+1]={kind=entry.point.kind,key=entry.point.key,character=entry.point.character,
                defeated=entry.point.defeated,unlocked=entry.point.unlocked,style=entry.point.style}
        end
    end
    view:trimPOI(poiCount)
end
api.provide('status',function()
    local out={};for k,v in pairs(status)do out[k]=v end
    out.settings=settings
    out.route=status.dungeon and {mode='dungeon_trail'} or route and route:status() or {mode='disabled'}
    out.allocated_segments=view and #view.segments or 0
    out.allocated_markers=view and (#view.guild+#view.pois) or 0
    return out
end)
api.provide('settings',function() return S.fields end)
api.provide('configure',function(values)
    local merged={};for key,value in pairs(settings) do merged[key]=value end
    for key,value in pairs(values) do merged[key]=value end
    local validated=S.validate(merged)
    for key,value in pairs(validated) do settings[key]=value;api.settings[key]=value end
    outdoorScale=288*settings.zoom/(40000*tonumber(settings.dezoom));scale=outdoorScale
    reset()
end)
api.every(0,function()
    local ok,failure=xpcall(tick,api.traceback)
    if not ok then
        if view then pcall(function()view:show(false)end)end
        status.visible=false;status.error=tostring(failure)
        error(status.error)
    else status.error=nil end
end)
