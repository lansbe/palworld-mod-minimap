local S = {defaults={size=288,zoom=1,dezoom='1',x=12,y=20,guild=true,poi=true,
    bosses=true,teleporters=true,dungeons=true,shape='square',transparency=0,
    follow=true,playersize=48,poisize=48,route=true,hidebeaten=true}}
S.fields={
    {key='shape',label='settings.shape',options={'square','round'},optionKeys={'shape.square','shape.round'}},
    {key='follow',label='settings.follow',type='boolean'},
    {key='dezoom',label='settings.dezoom',options={'1','2','4','8'}},
    {key='transparency',label='settings.transparency',min=0,max=90,step=10},
    {key='size',label='settings.size',min=128,max=512,step=32},
    {key='playersize',label='settings.playersize',min=24,max=80,step=8},
    {key='poisize',label='settings.poisize',min=24,max=80,step=8},
    {key='guild',label='settings.guild',type='boolean'},
    {key='bosses',label='settings.bosses',type='boolean'},
    {key='hidebeaten',label='settings.hidebeaten',type='boolean'},
    {key='teleporters',label='settings.teleporters',type='boolean'},
    {key='dungeons',label='settings.dungeons',type='boolean'},
    {key='route',label='settings.route',type='boolean'},
    {key='x',label='settings.x',min=0,max=100,step=5},
    {key='y',label='settings.y',min=0,max=100,step=5},
}
function S.validate(input)
    local out={}
    for key,default in pairs(S.defaults) do
        local value=input[key];if value==nil then value=default end
        if key=='dezoom' then
            value=tostring(value)
            assert(value=='1' or value=='2' or value=='4' or value=='8','Invalid range')
        elseif type(default)=='string' then assert(value=='square' or value=='round','Invalid shape')
        elseif type(default)=='boolean' then assert(type(value)=='boolean','Expected boolean: '..key)
        else assert(type(value)=='number' and value==value and math.abs(value)<math.huge,'Expected finite number: '..key) end
        out[key]=value
    end
    assert(out.size>=128 and out.size<=512 and out.zoom>=.5 and out.zoom<=3,'Size or zoom is out of range')
    assert(out.x>=0 and out.x<=100 and out.y>=0 and out.y<=100,'Position is out of range')
    assert(out.transparency>=0 and out.transparency<=100,'Transparency is out of range')
    assert(out.playersize>=24 and out.playersize<=80,'Player icon size is out of range')
    assert(out.poisize>=24 and out.poisize<=80,'Map icon size is out of range')
    return out
end
return S
