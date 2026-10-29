local RenderSystem = require("src.systems.battle.render_system")
local Mode = require("src.debug.mode")
local CombatSystem = require("src.systems.battle.combat_system")
local RangeUtils = require("src.systems.battle.range_utils")

local Scenario = {}

function Scenario.run()
    local player = {hp = 100, visualX = 120, visualY = 80, collisionRadius = 18,
        skillList = {"attack", "fireball", "on_me"}}
    local context = {data = {playerUnit = player, selectedSkillIndex = 1, unitList = {}}}
    local oldCircle, oldEnabled = love.graphics.circle, Mode.enabled
    local circles = {}
    love.graphics.circle = function(mode, x, y, radius)
        circles[#circles + 1] = {x = x, y = y, radius = radius}
    end
    local ok, err = xpcall(function()
        local function draw(expected)
            circles = {}
            RenderSystem.draw(context)
            assert(#circles == (expected and 1 or 0), "unexpected ability range preview")
            if expected then
                assert(circles[1].x == player.visualX and circles[1].y == player.visualY)
                assert(circles[1].radius == expected, "preview differs from combat range")
            end
        end
        Mode.enabled = false
        draw()
        Mode.enabled = true
        for index = 1, 2 do
            context.data.selectedSkillIndex = index
            local skill = CombatSystem.getEffectiveSkill(player, player.skillList[index])
            assert(skill and skill.range)
            draw(RangeUtils.effectiveSkillRange(player, nil, skill))
        end
        context.data.selectedSkillIndex = 3
        draw()
        context.data.selectedSkillIndex = 99
        draw()
        context.data.selectedSkillIndex = 1
        player.hp = 0
        draw()
        context.data.playerUnit = nil
        draw()
    end, debug.traceback)
    love.graphics.circle, Mode.enabled = oldCircle, oldEnabled
    assert(ok, err)
end

return Scenario
