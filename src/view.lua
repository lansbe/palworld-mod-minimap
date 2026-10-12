-- Native UMG primitives and Palworld's own textures only. No cooked mod assets,
-- render target, scene capture, external window or third-party minimap shader.
local V={};V.__index=V
local G=require('geometry')
local valid=Engine.valid
local function color(r,g,b,a)return {R=r,G=g,B=b,A=a or 1}end
local WHITE=color(.92,.97,1);local GUILD=color(.2,1,.75)
local POI_TEXTURES={boss='T_icon_compass_KeyBoss',bounty='T_icon_compass_Bounty',tower='T_icon_compass_tower',base='T_icon_compass_camp',
    dungeon='T_icon_compass_dungeon',travel='T_icon_compass_FTtower',warp='T_icon_compass_Teleport',
    supply='T_icon_compass_TreasureMap_01',quest='T_icon_compass_00',point='T_icon_compass_00'}
local function asset(path)
    local object=Engine.find(path)
    if valid(object)then return object end
    -- AssetRegistry can load existing cooked game assets on this Mac port.
    local package,name=path:match('^(.*)%.([^%.]+)$')
    local lib=Engine.find('/Script/AssetRegistry.Default__AssetRegistryHelpers')
    if valid(lib)then
        object=lib:GetAsset({PackageName=package,AssetName=name})
    end
    return valid(object) and object or nil
end
function V:widget(kind)
    local object=Engine.construct(Engine.find('/Script/UMG.'..kind),self.tree)
    assert(valid(object),'Unable to create widget: '..kind);return object
end
function V:add(parent,widget,x,y,w,h,z)
    local slot=parent:AddChildToCanvas(widget)
    slot:SetPosition({X=x,Y=y});slot:SetSize({X=w,Y=h});slot:SetZOrder(z or 0)
    return slot
end
function V:box(parent,x,y,w,h,tint,z)
    local b=self:widget('Border');b:SetBrushColor(tint)
    self:add(parent,b,x,y,w,h,z);return b
end
function V:text(parent,text,x,y,w,h,size,tint,z)
    local t=self:widget('TextBlock');t.Font.Size=size
    local c=tint or WHITE
    t.ColorAndOpacity.SpecifiedColor.R=c.R;t.ColorAndOpacity.SpecifiedColor.G=c.G
    t.ColorAndOpacity.SpecifiedColor.B=c.B;t.ColorAndOpacity.SpecifiedColor.A=c.A
    t.ColorAndOpacity.ColorUseRule=0
    t:SetShadowColorAndOpacity(color(0,0,0,.85));t:SetShadowOffset({X=1,Y=1})
    t:SetText(text);self:add(parent,t,x,y,w,h,z);return t
end
function V.new(pc,settings)
    local self=setmetatable({size=settings.size,playerSize=settings.playersize,poiSize=settings.poisize,round=settings.shape=='round',follow=settings.follow,guild={},pois={},segments={},textures={},visible=false},V)
    self.user=Engine.find('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(pc,Engine.find('/Script/UMG.UserWidget'),pc)
    assert(valid(self.user),'Root widget is unavailable')
    self.tree=self.user.WidgetTree;self.root=self:widget('CanvasPanel');self.tree.RootWidget=self.root
    self.panel=self:widget('CanvasPanel');self.panelSlot=self:add(self.root,self.panel,24,24,self.size,self.size)
    self.panel:SetRenderOpacity(1-settings.transparency/100)
    local n=self.size
    local frame=self:widget('Image');self:add(self.panel,frame,-2,-2,n+4,n+4,0)
    self:rounded(frame,self.round and (n+4)/2 or 0)
    -- Outline only: a filled backing would make a 50%-transparent map appear
    -- 75% opaque by drawing two translucent layers on top of each other.
    frame.Brush.TintColor.SpecifiedColor.A=0;frame.Brush.TintColor.ColorUseRule=0
    local outline=frame.Brush.OutlineSettings
    outline.Width=2;outline.bUseBrushTransparency=false
    outline.Color.ColorUseRule=0
    outline.Color.SpecifiedColor.R=.35;outline.Color.SpecifiedColor.G=.85
    outline.Color.SpecifiedColor.B=.95;outline.Color.SpecifiedColor.A=.9
    self.crop=self:widget('CanvasPanel');self.crop.Clipping=1;self:add(self.panel,self.crop,0,0,n,n,1)
    -- A single native textured brush. Square rotation needs a diagonal-sized
    -- quad; the rounded brush clips its own pixels in Slate's existing shader.
    self.renderSize=n*(self.follow and not self.round and math.sqrt(2) or 1)
    local margin=(self.renderSize-n)/2
    self.map=self:widget('Image');self.mapSlot=self:add(self.crop,self.map,-margin,-margin,self.renderSize,self.renderSize,0)
    self.map:SetRenderTransformPivot({X=.5,Y=.5});self.map.bIsVolatile=true
    self.overlay=self:widget('CanvasPanel');self:add(self.crop,self.overlay,0,0,n,n,2)
    self.north=self:text(self.panel,'N',n/2-5,n/2-10,18,20,14,WHITE,8)
    self.arrowTexture=asset('/Game/Pal/Texture/UI/InGame/T_icon_map_player.T_icon_map_player')
    self.arrow=self:widget('Image');self:add(self.overlay,self.arrow,(n-self.playerSize)/2,(n-self.playerSize)/2,self.playerSize,self.playerSize,10)
    if self.arrowTexture then self.arrow:SetBrushFromTexture(self.arrowTexture,false)end
    self.arrow:SetColorAndOpacity(color(1,.88,.25));self.arrow:SetRenderTransformPivot({X=.5,Y=.5})
    self.routeLabel=self:text(self.panel,'',0,n+5,n,22,12,WHITE,8)
    self.destination=self:text(self.overlay,'◆',-12,-16,30,32,24,color(1,.76,.24),7)
    self.destination:SetVisibility(1)
    self.user:SetVisibility(1);self.user:AddToViewport(-100)
    self:layout(pc,settings)
    return self
end
function V:rounded(image,radius)
    image.Brush.DrawAs=4
    local o=image.Brush.OutlineSettings
    o.RoundingType=0;o.Width=0
    o.CornerRadii.X=radius;o.CornerRadii.Y=radius;o.CornerRadii.Z=radius;o.CornerRadii.W=radius
end
function V:layout(pc,s)
    local lib=Engine.find('/Script/UMG.Default__WidgetLayoutLibrary')
    local extent=lib:GetViewportSize(pc);local dpi=lib:GetViewportScale(pc)
    if not dpi or dpi<=0 then dpi=1 end
    local w,h=extent.X/dpi,extent.Y/dpi
    local x=math.max(8,math.min(w-self.size-8,w*s.x/100-self.size/2))
    local y=math.max(8,math.min(h-self.size-8,h*s.y/100-self.size/2))
    if x~=self.layoutX or y~=self.layoutY then self.panelSlot:SetPosition({X=x,Y=y});self.layoutX,self.layoutY=x,y end
end
function V:terrain(name,bounds,scale)
    if self.mapName==name then return true end
    local paths={MainMap='/Game/Pal/Texture/UI/Map/T_WorldMap.T_WorldMap',Tree='/Game/Pal/Texture/UI/Map/T_TreeMap.T_TreeMap'}
    local path=paths[name];if not path then return false end
    local texture=asset(path);if not texture then return false end
    if self.interior then self.interior:SetVisibility(1)end
    self.map:SetVisibility(4);self.panX=nil;self.yaw=nil
    self.map:SetBrushFromTexture(texture,false)
    if self.round then self:rounded(self.map,self.size/2)end
    self.textureWidth=(bounds.maxY-bounds.minY)*scale;self.textureHeight=(bounds.maxX-bounds.minX)*scale
    self.mapName=name;return true
end
function V:interiorMap()
    if self.mapName=='Dungeon' then return end
    if not self.interior then
        self.interior=self:widget('Image');self:add(self.crop,self.interior,0,0,self.size,self.size,0)
        self:rounded(self.interior,self.round and self.size/2 or 0)
        self.interior:SetColorAndOpacity(color(.018,.038,.048,.94))
    end
    self.interior:SetVisibility(4);self.map:SetVisibility(1)
    self.mapName='Dungeon';self.yaw=nil
end
function V:show(show)
    if self.visible~=show and valid(self.user)then self.user:SetVisibility(show and 4 or 1);self.visible=show end
end
function V:pan(x,y,yaw)
    if self.mapName~='Dungeon' and (not self.panX or math.abs(x-self.panX)>.05 or math.abs(y-self.panY)>.05) then
        local cx,cy=self.size/2-x,self.size/2-y;local half=self.renderSize/2
        local uv=self.map.Brush.UVRegion
        uv.Min.X=(cx-half)/self.textureWidth;uv.Max.X=(cx+half)/self.textureWidth
        uv.Min.Y=(cy-half)/self.textureHeight;uv.Max.Y=(cy+half)/self.textureHeight;uv.bIsValid=1
        self.panX,self.panY=x,y
    end
    if not self.yaw or math.abs((yaw-self.yaw+180)%360-180)>.1 then
        local angle=self.follow and -yaw or 0
        self.map:SetRenderTransformAngle(angle)
        self.arrow:SetRenderTransformAngle(self.follow and 0 or yaw)
        local nx,ny=G.rotate(0,-self.size/2+13,angle)
        self.north:SetRenderTranslation({X=nx,Y=ny});self.yaw=yaw
    end
end
function V:dungeonTrail(trail,origin,scale,angle)
    local count=0
    local function line(a,b,grid)
        if count>=64 then return end
        local x1,y1=G.rotate((a.y-origin.y)*scale,(origin.x-a.x)*scale,angle)
        local x2,y2=G.rotate((b.y-origin.y)*scale,(origin.x-b.x)*scale,angle)
        if self:segment(count+1,x1,y1,x2,y2,false)then
            count=count+1
            local m=self.segments[count]
            if m.grid~=grid then
                m.widget:SetRenderOpacity(grid and .12 or .8);m.grid=grid
            end
        end
    end
    -- World-aligned reference grid, bounded at 14 lines at every zoom level.
    local step=self.size*.24/scale;local extent=self.size*.72/scale
    local x0=math.floor(origin.x/step)*step;local y0=math.floor(origin.y/step)*step
    for i=-3,3 do
        line({x=x0+i*step,y=origin.y-extent},{x=x0+i*step,y=origin.y+extent},true)
        line({x=origin.x-extent,y=y0+i*step},{x=origin.x+extent,y=y0+i*step},true)
    end
    local points=trail.points
    local function trailLine(a,b)
        if a and not b.gap and math.abs(a.z-origin.z)<6000 and math.abs(b.z-origin.z)<6000 then line(a,b,false)end
    end
    local last=points[#points]
    if last and (last.x-origin.x)^2+(last.y-origin.y)^2<10000^2 and math.abs(last.z-origin.z)<2000 then trailLine(last,origin)end
    for i=#points,2,-1 do trailLine(points[i-1],points[i]);if count>=64 then break end end
    for i=count+1,#self.segments do local m=self.segments[i];if m.shown then m.widget:SetVisibility(1);m.shown=false end end
    self.destination:SetVisibility(1)
    if self.routeText~='' then self.routeLabel:SetText('');self.routeText='' end
end
function V:guildMarker(index)
    local marker=self.guild[index];if marker then return marker end
    local group=self:widget('CanvasPanel');self:add(self.overlay,group,0,0,1,1,5)
    local icon=self:widget('Image');self:add(group,icon,-self.playerSize/2,-self.playerSize/2,self.playerSize,self.playerSize,2)
    if self.arrowTexture then icon:SetBrushFromTexture(self.arrowTexture,false)end
    icon:SetColorAndOpacity(GUILD)
    marker={widget=group,icon=icon};self.guild[index]=marker;return marker
end
function V:member(index,x,y,outside,yaw)
    local m=self:guildMarker(index)
    if not m.shown then m.widget:SetVisibility(4);m.shown=true end
    if not m.x or math.abs(m.x-x)>.1 or math.abs(m.y-y)>.1 then m.widget:SetRenderTranslation({X=x,Y=y});m.x,m.y=x,y end
    local angle=outside and math.deg(math.atan(x-self.size/2,self.size/2-y)) or (yaw or 0)
    if m.angle~=angle then m.icon:SetRenderTransformAngle(angle);m.angle=angle end
end
function V:trim(count)
    for index=count+1,#self.guild do local m=self.guild[index];if m.shown then m.widget:SetVisibility(1);m.shown=false end end
end
function V:poi(index,x,y,kind,state)
    state=state or 'normal'
    local marker=self.pois[index]
    if not marker then
        local group=self:widget('CanvasPanel');self:add(self.overlay,group,0,0,1,1,3)
        local t=self:widget('Image');self:add(group,t,-self.poiSize/2,-self.poiSize/2,self.poiSize,self.poiSize,0)
        local badge=self:widget('Image');self:add(group,badge,0,0,self.poiSize/2,self.poiSize/2,1)
        marker={widget=group,icon=t,badge=badge};self.pois[index]=marker
    end
    if not marker.shown then marker.widget:SetVisibility(4);marker.shown=true end
    if marker.kind~=kind then
        local name=POI_TEXTURES[kind] or POI_TEXTURES.point
        if self.textures[kind]==nil then self.textures[kind]=asset('/Game/Pal/Texture/UI/InGame/'..name..'.'..name) or false end
        if self.textures[kind]then marker.icon:SetBrushFromTexture(self.textures[kind],false)end
        marker.kind=kind
        marker.state=nil
    end
    if marker.state~=state then
        local boss=kind=='boss' or kind=='bounty' or kind=='tower'
        local tint=state=='locked' and color(.65,.68,.72) or state=='cleared' and color(.35,.95,.6) or
            boss and color(1,.36,.25) or kind=='travel' and color(.2,.85,1) or WHITE
        marker.icon:SetColorAndOpacity(tint)
        if state=='cleared' then
            local path='/Game/Pal/Texture/UI/InGame/T_icon_compass_ClearCheck.T_icon_compass_ClearCheck'
            if self.textures[state]==nil then self.textures[state]=asset(path) or false end
            if self.textures[state]then marker.badge:SetBrushFromTexture(self.textures[state],false)end
            marker.badge:SetColorAndOpacity(color(.4,1,.55))
            marker.badge:SetVisibility(4)
        else marker.badge:SetVisibility(1)end
        marker.state=state
    end
    if marker.x~=x or marker.y~=y then marker.widget:SetRenderTranslation({X=x,Y=y});marker.x,marker.y=x,y end
end
function V:segment(index,x1,y1,x2,y2,partial)
    local half=self.size/2
    x1,y1,x2,y2=G.clipLine(x1,y1,x2,y2,half-5,self.round)
    if not x1 then return false end
    local dx,dy=x2-x1,y2-y1;local length=math.sqrt(dx*dx+dy*dy)
    if length<.25 then return false end
    local m=self.segments[index]
    if not m then
        local w=self:widget('Border');w:SetPadding({Left=0,Top=0,Right=0,Bottom=0});w:SetRenderTransformPivot({X=0,Y=.5})
        m={widget=w,slot=self:add(self.overlay,w,0,0,1,4,1)};self.segments[index]=m
    end
    if not m.shown then m.widget:SetVisibility(4);m.shown=true end
    if m.partial~=partial then m.widget:SetBrushColor(partial and color(1,.76,.24) or color(.2,.95,1));m.partial=partial end
    local angle=math.deg(math.atan(dy,dx))
    if m.x~=x1 or m.y~=y1 then m.slot:SetPosition({X=half+x1,Y=half+y1-2});m.x,m.y=x1,y1 end
    if m.length~=length then m.slot:SetSize({X=length,Y=4});m.length=length end
    if m.angle~=angle then m.widget:SetRenderTransformAngle(angle);m.angle=angle end
    return true
end
function V:route(route,origin,scale,angle)
    local count=0;local label=''
    local targetX,targetY
    local function line(a,b,partial)
        if count>=64 then return end
        local x1,y1=G.rotate((a.y-origin.y)*scale,(origin.x-a.x)*scale,angle)
        local x2,y2=G.rotate((b.y-origin.y)*scale,(origin.x-b.x)*scale,angle)
        if self:segment(count+1,x1,y1,x2,y2,partial)then count=count+1 end
    end
    if route and route.target then
        if route.mode~='other_map' then
            targetX,targetY=G.project(route.target.position,origin,scale,self.size/2,18,false,angle,self.round)
        end
        if route.mode=='path' or route.mode=='partial' then
            for i=2,#route.points do line(route.points[i-1],route.points[i],route.mode=='partial')end
            if route.mode=='partial' then label='Partial path' end
        elseif route.mode=='direction' then
            local p=route.target.position
            local dx,dy=(p.y-origin.y)*scale,(origin.x-p.x)*scale
            local distance=math.sqrt(dx*dx+dy*dy)
            local length=math.min(distance,self.size*.71)
            if distance>0 then
                dx,dy=G.rotate(dx/distance,dy/distance,angle)
                for start=18,length,16 do
                    local stop=math.min(start+9,length)
                    if self:segment(count+1,dx*start,dy*start,dx*stop,dy*stop,true)then count=count+1 end
                end
            end
        end
    end
    if targetX then
        self.destination:SetVisibility(4);self.destination:SetRenderTranslation({X=targetX,Y=targetY})
    else self.destination:SetVisibility(1)end
    for i=1,count do local m=self.segments[i];if m.grid~=nil then m.widget:SetRenderOpacity(1);m.grid=nil end end
    for i=count+1,#self.segments do local m=self.segments[i];if m.shown then m.widget:SetVisibility(1);m.shown=false end end
    if self.routeText~=label then self.routeLabel:SetText(label);self.routeText=label end
end
function V:trimPOI(count)
    for i=count+1,#self.pois do local m=self.pois[i];if m.shown then m.widget:SetVisibility(1);m.shown=false end end
end
function V:destroy()
    if valid(self.user)then self.user:RemoveFromParent()end
    self.user=nil;self.guild={};self.pois={};self.segments={}
end
return V
