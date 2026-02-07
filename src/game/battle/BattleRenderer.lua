local BattleRenderer = {}

function BattleRenderer:drawUnits(units)
    -- Sort units by Y for proper depth
    table.sort(units, function(a, b)
        return a.battle_y < b.battle_y
    end)

    -- Draw each unit, highlight player unit if needed
    for _, unit in ipairs(units) do
        unit:draw()
    end
end

function BattleRenderer:drawProjectiles(projectiles)
    if not projectiles then return end
    for _, p in ipairs(projectiles) do
        if p.draw then p:draw() end
    end
end

return BattleRenderer
