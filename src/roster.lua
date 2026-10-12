local G=require('geometry');local D=require('dungeon')
local R={members={}}
local valid=Engine.valid
local function objectKey(o)return valid(o) and o.key or nil end
local function vec(v)return {x=v.X,y=v.Y,z=v.Z}end
function R.update(settings,pc,gameState)
    local members=R.members
    local own=pc.PlayerState
    if not valid(own)then R.members={};return end
    local guild=objectKey(own.GuildBelongTo);local fresh={};local old={}
    for _,m in ipairs(members)do old[m.key]=m end
    if settings.guild and guild then
        for _, ps in ipairs(gameState.PlayerArray) do
            if #fresh<64 and valid(ps) and objectKey(ps)~=objectKey(own) and not ps.bIsInactive
                and G.sameGuild(guild,objectKey(ps.GuildBelongTo)) then
                local key=objectKey(ps);local m=old[key] or {key=key}
                m.state=ps;m.dungeon=ps:IsInStateByStageType(1)
                m.stage=m.dungeon and D.stageKey(ps) or nil;fresh[#fresh+1]=m
            end
        end
    end
    table.sort(fresh,function(a,b)return a.key<b.key end)
    R.members=fresh
end
function R.sample(now)
    local members=R.members
    for _,m in ipairs(members)do
        if valid(m.state)then
            local info=m.state:GetPlayerInfoForMap()
            local p=vec(info.Transform.Translation)
            local pawn=m.state.PawnPrivate
            if valid(pawn)then p=vec(pawn:K2_GetActorLocation());m.source='character' else m.source='replicated_map' end
            if G.position(p) and (p.x~=0 or p.y~=0 or p.z~=0)then
                local old=m.next or p
                -- Teleports snap. Normal network samples interpolate over 100 ms.
                if (old.x-p.x)^2+(old.y-p.y)^2>10000^2 then old=p end
                m.previous=old;m.next=p;m.sampleAt=now
                local q=info.Transform.Rotation
                m.yaw=math.deg(math.atan(2*(q.W*q.Z+q.X*q.Y),1-2*(q.Y*q.Y+q.Z*q.Z)))
            else m.next=nil end
        else m.next=nil end
    end
end
return R
