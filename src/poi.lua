-- Static metadata, not an actor/enemy scan. Names and positions come from the
-- same typed master table as the game's world map. No save or network writes.
local P={}
function P.enabled(kind,settings)
    if not settings.poi then return false end
    if kind=='boss' or kind=='bounty' or kind=='tower' then return settings.bosses end
    if kind=='travel' or kind=='warp' then return settings.teleporters end
    if kind=='dungeon' then return settings.dungeons end
    return true
end
function P.readProgress(record)
    local flags={}
    if not Engine.valid(record)then return flags end
    for _, row in ipairs(record.NormalBossDefeatFlag.Items) do
        if row.Value then flags[row.Key]=true end
    end
    return flags
end
function P.presentation(kind,defeated,unlocked,hidebeaten)
    local boss=kind=='boss' or kind=='bounty' or kind=='tower'
    if boss and defeated and hidebeaten then return false end
    return true,boss and defeated and 'cleared' or kind=='travel' and not unlocked and 'locked' or 'normal'
end
function P.classify(class)
    class=class:lower()
    if class:find('bosstower',1,true)then return 'tower' end
    if class:find('boss',1,true)then return 'boss' end
    if class:find('base',1,true)then return 'base' end
    if class:find('dungeon',1,true)then return 'dungeon' end
    if class:find('travel',1,true)then return 'travel' end
    if class:find('warp',1,true)then return 'warp' end
    if class:find('supply',1,true)then return 'supply' end
    if class:find('quest',1,true)then return 'quest' end
    return 'point'
end
function P.loader(cached)
    if cached then return {points=cached,done=true,cached=true}end
    local self={rows={},index=1,points={},seen={},done=false}
    local objects=api.objects('PalMasterDataTableAccess_BossSpawnerUIData') or {}
    for _,o in ipairs(objects)do if Engine.valid(o)then self.source=o;break end end
    if self.source then
        for _,entry in ipairs(self.source:GetRowNames())do
            self.rows[#self.rows+1]=entry
        end
    end
    function self:step()
        if self.index>#self.rows or not Engine.valid(self.source)then self.done=true;return end
        -- One row per sampling tick. Asset loading is never done here.
        local data=self.source:BP_FindRow(self.rows[self.index],nil)
        self.index=self.index+1
        local p=data.Location
        if p and p.X==p.X and p.Y==p.Y and p.Z==p.Z then
            local id=data.SpawnerID
            local character=data.CharacterID
            local key=table.concat({id,math.floor(p.X),math.floor(p.Y),math.floor(p.Z)},':')
            if not self.seen[key]then
                self.seen[key]=true
                self.points[#self.points+1]={key='boss:'..key,spawner=id,character=character,
                    position={x=p.X,y=p.Y,z=p.Z},kind=character=='None' and 'bounty' or 'boss',static=true}
            end
        end
    end
    return self
end
return P
