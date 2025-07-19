-- Battle module
-- Handles battle scene logic, drawing, and state management

local Game = require('src.game')

local Battle = {
    state = "inactive",
    battle_type = nil,
    units = {},
    player_army_units = {},
    lost_units = {},
    background_type = nil,
    width = 800,
    height = 600,
    ally_spawn_x = 100,
    enemy_spawn_x = 700,
    spawn_y_base = 300,
    spawn_spacing = 40,
    ui = {
        victory_text = "Victory!",
        defeat_text = "Defeat!",
        continue_text = "Press SPACE to continue",
        text_timer = 0,
        text_duration = 3.0
    },
    on_battle_end = nil,
    on_battle_finished = nil,
    background = nil
}

function Battle.createBackground(backgroundType)
    local backgrounds = {
        forest = {
            color = {0.2, 0.5, 0.2, 1.0},
            features = {
                {type = "tree", x = 50, y = 450, width = 30, height = 60, color = {0.3, 0.6, 0.3, 1.0}},
                {type = "tree", x = 750, y = 450, width = 30, height = 60, color = {0.3, 0.6, 0.3, 1.0}},
                {type = "bush", x = 200, y = 480, width = 20, height = 15, color = {0.4, 0.7, 0.4, 1.0}},
                {type = "bush", x = 600, y = 480, width = 20, height = 15, color = {0.4, 0.7, 0.4, 1.0}}
            }
        },
        desert = {
            color = {0.8, 0.7, 0.5, 1.0},
            features = {
                {type = "rock", x = 100, y = 450, width = 40, height = 30, color = {0.6, 0.6, 0.6, 1.0}},
                {type = "rock", x = 700, y = 450, width = 40, height = 30, color = {0.6, 0.6, 0.6, 1.0}},
                {type = "cactus", x = 300, y = 420, width = 15, height = 80, color = {0.3, 0.7, 0.3, 1.0}},
                {type = "cactus", x = 500, y = 420, width = 15, height = 80, color = {0.3, 0.7, 0.3, 1.0}}
            }
        },
        village = {
            color = {0.6, 0.4, 0.2, 1.0},
            features = {
                {type = "house", x = 50, y = 400, width = 60, height = 80, color = {0.7, 0.5, 0.3, 1.0}},
                {type = "house", x = 700, y = 400, width = 60, height = 80, color = {0.7, 0.5, 0.3, 1.0}},
                {type = "fence", x = 200, y = 450, width = 100, height = 10, color = {0.5, 0.3, 0.1, 1.0}},
                {type = "fence", x = 500, y = 450, width = 100, height = 10, color = {0.5, 0.3, 0.1, 1.0}}
            }
        },
        mountain = {
            color = {0.4, 0.4, 0.4, 1.0},
            features = {
                {type = "mountain", x = 50, y = 350, width = 100, height = 150, color = {0.5, 0.5, 0.5, 1.0}},
                {type = "mountain", x = 650, y = 350, width = 100, height = 150, color = {0.5, 0.5, 0.5, 1.0}},
                {type = "rock", x = 300, y = 450, width = 30, height = 20, color = {0.6, 0.6, 0.6, 1.0}},
                {type = "rock", x = 500, y = 450, width = 30, height = 20, color = {0.6, 0.6, 0.6, 1.0}}
            }
        }
    }
    
    return backgrounds[backgroundType] or backgrounds.forest
end

function Battle.spawnUnits(battle, playerArmy, enemyArmy)
    local ally_y = battle.spawn_y_base
    local ally_spacing = 50
    for i, armyUnit in ipairs(playerArmy) do
        local unitType = "soldier"
        if armyUnit.battle_type then
            unitType = armyUnit.battle_type
        elseif armyUnit.type then
            unitType = armyUnit.type:lower()
        end
        local unit = require('src.battle_unit'):new(1, unitType, battle.ally_spawn_x, ally_y, armyUnit)
        table.insert(battle.units, unit)
        unit.original_army_unit = armyUnit
        table.insert(battle.player_army_units, unit)
        ally_y = ally_y + ally_spacing
    end
    local enemy_y = battle.spawn_y_base
    local enemy_spacing = 50
    for i, enemyUnit in ipairs(enemyArmy) do
        local unitType = enemyUnit.type or "soldier"
        local tempArmyUnit = enemyUnit.army_unit or enemyUnit
        local unit = require('src.battle_unit'):new(2, unitType, battle.enemy_spawn_x, enemy_y, tempArmyUnit)
        table.insert(battle.units, unit)
        enemy_y = enemy_y + enemy_spacing
    end
end

function Battle.getBackgroundTypeForBattle(battleType)
    if battleType == "encounter" or battleType == "bandit_encounter" then
        return "forest"
    elseif battleType == "village_attack" then
        return "village"
    elseif battleType == "hideout_attack" then
        return "mountain"
    else
        return "forest"
    end
end

function Battle.update(dt)
    if Battle.state ~= "active" then
        Battle.ui.text_timer = Battle.ui.text_timer - dt
        if Battle.ui.text_timer <= 0 then
            Battle.state = "finished"
        end
        return
    end
    for _, unit in ipairs(Battle.units) do
        local wasAlive = unit:isAlive()
        unit:update(dt, Battle.units)
        if wasAlive and not unit:isAlive() and unit.team == 1 then
            table.insert(Battle.lost_units, unit.original_army_unit)
        end
    end
    Battle.checkBattleEnd()
end

function Battle.checkBattleEnd()
    local allies_alive = 0
    local enemies_alive = 0
    for _, unit in ipairs(Battle.units) do
        if unit:isAlive() then
            if unit:getTeam() == 1 then
                allies_alive = allies_alive + 1
            else
                enemies_alive = enemies_alive + 1
            end
        end
    end
    if enemies_alive == 0 then
        Battle.state = "victory"
        Battle.ui.text_timer = Battle.ui.text_duration
        Battle.handleBattleEnd(true)
    elseif allies_alive == 0 then
        Battle.state = "defeat"
        Battle.ui.text_timer = Battle.ui.text_duration
        Battle.handleBattleEnd(false)
    end
end

function Battle.handleBattleEnd(victory)
    local lostUnits = Battle.getLostUnits()
    for _, lostUnit in ipairs(lostUnits) do
        Game.player:removeUnitFromArmy(lostUnit)
    end
    if victory then
        Game.player:addGold(50)
        print("Battle won! Gained 50 gold.")
        if #lostUnits > 0 then
            print("Lost " .. #lostUnits .. " units in battle.")
        end
    else
        Game.player:addGold(-20)
        print("Battle lost! Lost 20 gold.")
        if #lostUnits > 0 then
            print("Lost " .. #lostUnits .. " units in battle.")
        end
    end
end

function Battle.draw()
    love.graphics.setColor(Battle.background.color)
    love.graphics.rectangle('fill', 0, 0, Battle.width, Battle.height)
    for _, feature in ipairs(Battle.background.features) do
        love.graphics.setColor(feature.color)
        love.graphics.rectangle('fill', feature.x, feature.y, feature.width, feature.height)
    end
    love.graphics.setColor(0.3, 0.3, 0.3, 1.0)
    love.graphics.setLineWidth(3)
    love.graphics.line(0, 500, Battle.width, 500)
    for _, unit in ipairs(Battle.units) do
        unit:draw()
    end
    Battle.drawUI()
end

function Battle.drawUI()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Battle: " .. Battle.battle_type:gsub("_", " "):upper(), 10, 10)
    local allies_alive = 0
    local enemies_alive = 0
    for _, unit in ipairs(Battle.units) do
        if unit:isAlive() then
            if unit:getTeam() == 1 then
                allies_alive = allies_alive + 1
            else
                enemies_alive = enemies_alive + 1
            end
        end
    end
    love.graphics.print("Allies: " .. allies_alive, 10, 30)
    love.graphics.print("Enemies: " .. enemies_alive, 10, 50)
    if Battle.state == "victory" then
        Battle.drawResultScreen(Battle.ui.victory_text, {0.2, 0.8, 0.2, 1.0})
    elseif Battle.state == "defeat" then
        Battle.drawResultScreen(Battle.ui.defeat_text, {0.8, 0.2, 0.2, 1.0})
    end
end

function Battle.drawResultScreen(text, color)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, 0, Battle.width, Battle.height)
    love.graphics.setColor(color)
    local font = love.graphics.getFont()
    local text_width = font:getWidth(text)
    love.graphics.print(text, Battle.width/2 - text_width/2, Battle.height/2 - 50)
    love.graphics.setColor(1, 1, 1, 1)
    local continue_width = font:getWidth(Battle.ui.continue_text)
    love.graphics.print(Battle.ui.continue_text, Battle.width/2 - continue_width/2, Battle.height/2 + 20)
end

function Battle.keypressed(key)
    if key == "space" and (Battle.state == "victory" or Battle.state == "defeat") then
        Battle.state = "finished"
        Game.state = "overworld"
    end
end

function Battle.isFinished()
    return Battle.state == "finished"
end

function Battle.getResult()
    if Battle.state == "victory" then
        return true
    elseif Battle.state == "defeat" then
        return false
    end
    return nil
end

function Battle.setBattleEndCallback(callback)
    Battle.on_battle_end = callback
end

function Battle.setBattleFinishedCallback(callback)
    Battle.on_battle_finished = callback
end

function Battle.getLostUnits()
    return Battle.lost_units
end

function Battle.start(battleType, enemyArmy)
    Battle.state = "active"
    Battle.battle_type = battleType or "encounter"
    Battle.units = {}
    Battle.player_army_units = {}
    Battle.lost_units = {}
    Battle.background_type = Battle.getBackgroundTypeForBattle(battleType)
    Battle.background = Battle.createBackground(Battle.background_type)
    Battle.spawnUnits(Battle, Game.player.army, enemyArmy)
    Battle.ui.text_timer = 0
    Battle.on_battle_end = nil
    Battle.on_battle_finished = nil
    Game.state = "battle"
    Game.battle = Battle
    return Battle
end

return Battle 