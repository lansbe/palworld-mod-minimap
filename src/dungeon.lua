-- A local navigation view when no interior map texture exists. The line is
-- the player's observed trail, never a guessed floor plan or walkable route.
local D={};D.__index=D
function D.stageKey(ps)
    if not ps:IsInStateByStageType(1) then return nil end
    local id=ps:GetEnteringStageInstanceId()
    if not id.bValid then return nil end
    local g=id.InternalId
    return table.concat({g.A,g.B,g.C,g.D},':')
end
function D.new()return setmetatable({points={},revision=0},D)end
function D:update(key,p)
    if self.key~=key then self.key=key;self.points={};self.revision=self.revision+1 end
    if not key then return end
    local a=self.points[#self.points]
    if a and (p.x-a.x)^2+(p.y-a.y)^2+(p.z-a.z)^2<500^2 then return end
    local v={x=p.x,y=p.y,z=p.z}
    -- Never connect a teleport or a drop between distant floors.
    v.gap=a and ((p.x-a.x)^2+(p.y-a.y)^2>10000^2 or math.abs(p.z-a.z)>2000) or false
    local b=self.points[#self.points-1]
    local replace=false
    if b and a and not a.gap and not v.gap then
        local dx,dy=p.x-b.x,p.y-b.y;local length=math.sqrt(dx*dx+dy*dy)
        -- Extend a straight section; keep turns, reversals and floor changes.
        replace=length>0 and math.abs((a.x-b.x)*dy-(a.y-b.y)*dx)/length<80
            and (a.x-b.x)*(p.x-a.x)+(a.y-b.y)*(p.y-a.y)>0
            and math.abs(p.z-b.z)<500
    end
    self.points[#self.points+(replace and 0 or 1)]=v
    if #self.points>512 then table.remove(self.points,1) end
    self.revision=self.revision+1
end
function D.nearFloor(a,b)return math.abs(a.z-b.z)<6000 end
function D.sameArea(inside,key,otherInside,otherKey,a,b)
    if inside then return key~=nil and key==otherKey and D.nearFloor(a,b) end
    return not otherInside
end
return D
