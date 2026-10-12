-- Observe the game's compass markers, including markers created in its normal
-- map. Never read unsupported TMaps or hook the marker's Blueprint functions.
local G=require('geometry')
local R={};R.__index=R
local class='WBP_IngameCompass_CustomMarker_C'
local valid=Engine.valid
local function position(v)return {x=v.X,y=v.Y,z=v.Z}end
local function guid(v)return table.concat({v.A,v.B,v.C,v.D},':')end
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)end
local active
api.watch(class,function(o)
    if active and #active.widgets<512 then active.serial=active.serial+1;active.widgets[#active.widgets+1]={object=o,seq=active.serial}end
end)
function R.clear()active=nil end
function R.new(ownerKey)
    local self=setmetatable({widgets={},serial=0,mode='none',points={},nextPoll=0,nextPath=0,queries=0},R)
    local function add(o,seq)if #self.widgets<512 then self.widgets[#self.widgets+1]={object=o,seq=seq}end end
    for _,o in ipairs(api.objects('WBP_IngameCompass_CustomMarker_C') or {})do add(o,0)end
    active=self
    self.cacheKey=ownerKey and ('minimap.route.'..ownerKey)
    if self.cacheKey then self.preferred=api.cache[self.cacheKey] end
    -- Multiplayer clients may have no navigation system at all. In that case
    -- don't submit repeated synchronous path searches that can never succeed.
    self.hasNavigation=false
    for _,o in ipairs(api.objects('NavigationSystemV1') or {})do if valid(o)then self.hasNavigation=true;break end end
    self.nav=Engine.find('/Script/NavigationSystem.Default__NavigationSystemV1')
    self.filter=Engine.find('/Script/NavigationSystem.NavigationQueryFilter')
    return self
end
function R:poll(origin,now)
    if now<self.nextPoll then return end;self.nextPoll=now+.5
    local found,selected
    for i=#self.widgets,1,-1 do
        local w=self.widgets[i];local o=w.object
        if not valid(o)then table.remove(self.widgets,i)
        elseif valid(o:GetParent())then
            w.attached=true
            local p=position(o['Target Location']);local id=guid(o.MyLocationID)
            if G.position(p) and id~='0:0:0:0' then
                w.position=p;w.id=id
                if (self.target and id==self.target.id) or (not self.target and id==self.preferred)then selected=w end
                if not found or w.seq>found.seq or (w.seq==found.seq and distance(p,origin)<distance(found.position,origin))then found=w end
            end
        elseif w.attached then table.remove(self.widgets,i)end
    end
    if selected and (not found or selected.seq>=found.seq)then found=selected end
    if not found then self.target=nil;self.points={};self.mode='none';return end
    if not self.target or self.target.id~=found.id or distance(self.target.position,found.position)>1 then
        self.points={};self.lastOrigin=nil;self.nextPath=0
    end
    self.target={id=found.id,position=found.position,seq=found.seq}
    if self.preferred~=found.id then
        self.preferred=found.id
        if self.cacheKey then api.cache[self.cacheKey]=found.id end
    end
end
function R:update(pawn,origin,mapData,mapName,now)
    if now<(self.nextUpdate or 0)then return end;self.nextUpdate=now+.5
    self:poll(origin,now)
    if not self.target then return end
    local dest=self.target.position
    if mapData:GetMapNameByWorldLocation({X=dest.x,Y=dest.y,Z=dest.z})~=mapName then self.mode='other_map';self.points={};return end
    self.distance=distance(origin,dest)
    if self.distance<1200 then self.mode='arrived';self.points={};return end
    if not self.hasNavigation then self.mode='direction';self.points={};return end
    if now<self.nextPath then return end
    if self.lastOrigin and distance(origin,self.lastOrigin)<1000 and self.mode~='arrived' and self.mode~='other_map' then return end
    self.nextPath=now+3;self.lastOrigin=origin;self.points={};self.mode='direction'
    -- Restrict native work to nearby, loaded navigation. A distant target has a
    -- bearing, not an invented walkable path across an unloaded world.
    if self.distance>50000 then return end
    self.queries=self.queries+1
    local target={X=dest.x,Y=dest.y,Z=origin.z}
    local ok,out=self.nav:K2_ProjectPointToNavigation(pawn,target,nil,nil,self.filter,{X=600,Y=600,Z=10000})
    if not ok then return end
    local path=self.nav:FindPathToLocationSynchronously(pawn,{X=origin.x,Y=origin.y,Z=origin.z},out,pawn,self.filter)
    if not valid(path)then return end
    local points={}
    for _, entry in ipairs(path.PathPoints) do
        if #points<128 then points[#points+1]=position(entry) end
    end
    if #points<2 then return end
    self.points=points;self.mode=path:IsPartial() and 'partial' or 'path'
end
function R:status()
    return {mode=self.mode,target=self.target,distance_m=self.distance and math.floor(self.distance/100),
        path_points=#self.points,queries=self.queries,navigation_available=self.hasNavigation}
end
return R
