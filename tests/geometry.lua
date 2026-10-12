package.path='src/?.lua;'..package.path
local G=require('geometry')
local S=require('settings')
local function near(a,b)assert(math.abs(a-b)<.001,tostring(a)..' != '..tostring(b))end
local origin={x=0,y=0,z=0}
local x,y=G.project({x=100,y=0,z=0},origin,1,200,10,false,0,false)
near(x,200);near(y,100)
x,y=G.project({x=100,y=0,z=0},origin,1,200,10,false,90,false)
near(x,300);near(y,200)
assert(G.project({x=300,y=0,z=0},origin,1,200,10,false,0,false)==nil,'Off-map guild members must be hidden')
assert(G.project({x=150,y=150,z=0},origin,1,200,10,false,0,true)==nil,'Round clipping must reject corners')
local a,b,c,d=G.clipLine(-200,0,200,0,100,true)
near(a,-100);near(c,100);near(b,0);near(d,0)
assert(G.clipLine(-200,200,200,200,100,false)==nil)
assert(not G.sameGuild('', ''));assert(G.sameGuild('example','example'))
local calls=0
local calibration=G.calibration(origin,function(p)calls=calls+1;return p.x>=-1000 and p.x<=2000 and p.y>=-3000 and p.y<=4000 end)
local bounds
for _=1,150 do local before=calls;bounds=calibration:step();assert(calls-before<=1);if bounds then break end end
assert(bounds);assert(math.abs(bounds.minX+1000)<1 and math.abs(bounds.maxY-4000)<1)
assert(S.validate({}).hidebeaten)
for _,bad in ipairs({{size=0},{transparency=101},{playersize=1},{shape='triangle'},{dezoom='3'},{x=0/0}})do
 assert(not pcall(S.validate,bad),'Invalid setting was accepted')
end
print('PASS: camera rotation, guild clipping, round routes, bounded calibration and settings')
