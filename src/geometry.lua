-- Screen north is +world X; screen east is +world Y. Pure, engine-free maths.
local G={}
function G.finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
function G.position(p)return p and G.finite(p.x) and G.finite(p.y) and G.finite(p.z)end
function G.rotate(x,y,degrees)
    local a=math.rad(degrees or 0);local c,s=math.cos(a),math.sin(a)
    return x*c-y*s,x*s+y*c
end
function G.project(p,origin,scale,half,padding,clamp,angle,round)
    local x,y=(p.y-origin.y)*scale,(origin.x-p.x)*scale
    if angle and angle~=0 then x,y=G.rotate(x,y,angle)end
    local limit=half-padding;local extent=round and math.sqrt(x*x+y*y) or math.max(math.abs(x),math.abs(y))
    local outside=extent>limit
    if outside and not clamp then return nil end
    if outside then local factor=limit/extent;x,y=x*factor,y*factor end
    return half+x,half+y,outside,math.sqrt((p.x-origin.x)^2+(p.y-origin.y)^2)/100
end
function G.interpolate(previous,next,t)
    t=math.max(0,math.min(1,t))
    return {x=previous.x+(next.x-previous.x)*t,y=previous.y+(next.y-previous.y)*t,z=previous.z+(next.z-previous.z)*t}
end
function G.sameGuild(a,b)return a~=nil and b~=nil and a~='' and a==b end
function G.mapPoint(p,bounds,scale)
    return (p.y-bounds.minY)*scale,(bounds.maxX-p.x)*scale
end
-- Clip a line to the visible map, including segments whose two ends lie
-- outside it. Keep a stroke margin so round maps never leak at the boundary.
function G.clipLine(x1,y1,x2,y2,r,round)
    local dx,dy=x2-x1,y2-y1;local a,b=0,1
    if round then
        local q=dx*dx+dy*dy
        if q<1e-12 then if x1*x1+y1*y1<=r*r then return x1,y1,x2,y2 end;return end
        local c=x1*dx+y1*dy;local d=c*c-q*(x1*x1+y1*y1-r*r)
        if d<0 then return end
        d=math.sqrt(d);a=math.max(a,(-c-d)/q);b=math.min(b,(-c+d)/q)
    else
        for _,v in ipairs({{-dx,x1+r},{dx,r-x1},{-dy,y1+r},{dy,r-y1}})do
            if math.abs(v[1])<1e-12 then if v[2]<0 then return end
            elseif v[1]<0 then a=math.max(a,v[2]/v[1]) else b=math.min(b,v[2]/v[1])end
        end
    end
    if a>b then return end
    return x1+a*dx,y1+a*dy,x1+b*dx,y1+b*dy
end
-- Recover rectangular map limits from the game's own membership query. Each
-- step performs one query so initial calibration is spread across frames.
function G.calibration(origin,contains)
    local task={axis=1,inside=0,outside=nil,distance=10000,bounds={},calls=0}
    local axes={{'x',-1,'minX'},{'x',1,'maxX'},{'y',-1,'minY'},{'y',1,'maxY'}}
    function task:step()
        if self.axis>4 then return self.bounds end
        local spec=axes[self.axis];local distance=self.outside and (self.inside+self.outside)/2 or self.distance
        assert(distance<1e8,'Map boundaries are unavailable')
        local p={x=origin.x,y=origin.y,z=origin.z};p[spec[1]]=p[spec[1]]+spec[2]*distance
        self.calls=self.calls+1
        if contains(p)then self.inside=distance else self.outside=distance end
        if self.outside and self.outside-self.inside<1 then
            self.bounds[spec[3]]=origin[spec[1]]+spec[2]*(self.inside+self.outside)/2
            self.axis=self.axis+1;self.inside=0;self.outside=nil;self.distance=10000
        elseif not self.outside then self.distance=self.distance*2 end
        if self.axis>4 then return self.bounds end
    end
    return task
end
return G
