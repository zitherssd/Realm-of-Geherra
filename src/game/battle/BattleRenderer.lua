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

return BattleRenderer



