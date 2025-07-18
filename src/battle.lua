-- Battle module
-- Handles battle scene logic, drawing, and state management

local BattleUnit = require('src.unit')

local Battle = {}

function Battle:new(battleType, playerArmy, enemyArmy, backgroundType)
    local instance = {
        -- Battle state
        state = "active", -- active, victory, defeat, finished
        battle_type = battleType or "encounter", -- encounter, village_attack, hideout_attack
        
        -- Units
        units = {},
        
        -- Track unit losses for player army
        player_army_units = {}, -- Store references to player army units
        lost_units = {}, -- Track which units were lost
        
        -- Background
        background_type = backgroundType or "forest", -- forest, desert, village, mountain
        
        -- Battle area
        width = 800,
        height = 600,
        
        -- Spawn positions
        ally_spawn_x = 100,
        enemy_spawn_x = 700,
        spawn_y_base = 300,
        spawn_spacing = 40,
        
        -- UI
        ui = {
            victory_text = "Victory!",
            defeat_text = "Defeat!",
            continue_text = "Press SPACE to continue",
            text_timer = 0,
            text_duration = 3.0
        },
        
        -- Callback for when battle ends
        on_battle_end = nil
    }
    
    -- Create background based on type
    instance.background = Battle.createBackground(backgroundType)
    
    -- Spawn units
    Battle.spawnUnits(instance, playerArmy, enemyArmy)
    
    setmetatable(instance, {__index = self})
    return instance
end

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

function Battle.spawnUnits(battleInstance, playerArmy, enemyArmy)
    -- Spawn allied units (player's army) with better spacing
    local ally_y = battleInstance.spawn_y_base
    local ally_spacing = 50 -- Increased spacing to avoid overlap
    
    for i, armyUnit in ipairs(playerArmy) do
        -- Get the unit type for battle, with fallbacks
        local unitType = "soldier" -- default fallback
        if armyUnit.battle_type then
            unitType = armyUnit.battle_type
        elseif armyUnit.type then
            unitType = armyUnit.type:lower()
        end
        local unit = BattleUnit:new(1, unitType, battleInstance.ally_spawn_x, ally_y, armyUnit)
        table.insert(battleInstance.units, unit)
        unit.original_army_unit = armyUnit
        table.insert(battleInstance.player_army_units, unit)
        ally_y = ally_y + ally_spacing
    end
    
    -- Spawn enemy units with better spacing
    local enemy_y = battleInstance.spawn_y_base
    local enemy_spacing = 50 -- Increased spacing to avoid overlap
    
    for i, enemyUnit in ipairs(enemyArmy) do
        local unitType = enemyUnit.type or "soldier"
        -- Create a minimal ArmyUnit-like table for enemy units
        local tempArmyUnit = enemyUnit.army_unit or enemyUnit
        local unit = BattleUnit:new(2, unitType, battleInstance.enemy_spawn_x, enemy_y, tempArmyUnit)
        table.insert(battleInstance.units, unit)
        enemy_y = enemy_y + enemy_spacing
    end
end

function Battle:update(dt)
    if self.state ~= "active" then
        -- Update result screen timer
        self.ui.text_timer = self.ui.text_timer - dt
        if self.ui.text_timer <= 0 then
            self.state = "finished"
        end
        return
    end
    
    -- Update all units and track losses
    for _, unit in ipairs(self.units) do
        local wasAlive = unit:isAlive()
        unit:update(dt, self.units)
        
        -- Check if unit just died
        if wasAlive and not unit:isAlive() and unit.team == 1 then
            -- Player unit died, track it
            table.insert(self.lost_units, unit.original_army_unit)
        end
    end
    
    -- Check battle end conditions
    self:checkBattleEnd()
end

function Battle:checkBattleEnd()
    local allies_alive = 0
    local enemies_alive = 0
    
    for _, unit in ipairs(self.units) do
        if unit:isAlive() then
            if unit:getTeam() == 1 then
                allies_alive = allies_alive + 1
            else
                enemies_alive = enemies_alive + 1
            end
        end
    end
    
    if enemies_alive == 0 then
        -- Victory
        self.state = "victory"
        self.ui.text_timer = self.ui.text_duration
        if self.on_battle_end then
            self.on_battle_end(true) -- true for victory
        end
    elseif allies_alive == 0 then
        -- Defeat
        self.state = "defeat"
        self.ui.text_timer = self.ui.text_duration
        if self.on_battle_end then
            self.on_battle_end(false) -- false for defeat
        end
    end
end

function Battle:draw()
    -- Draw background
    love.graphics.setColor(self.background.color)
    love.graphics.rectangle('fill', 0, 0, self.width, self.height)
    
    -- Draw background features
    for _, feature in ipairs(self.background.features) do
        love.graphics.setColor(feature.color)
        love.graphics.rectangle('fill', feature.x, feature.y, feature.width, feature.height)
    end
    
    -- Draw ground line
    love.graphics.setColor(0.3, 0.3, 0.3, 1.0)
    love.graphics.setLineWidth(3)
    love.graphics.line(0, 500, self.width, 500)
    
    -- Draw all units
    for _, unit in ipairs(self.units) do
        unit:draw()
    end
    
    -- Draw battle UI
    self:drawUI()
end

function Battle:drawUI()
    -- Draw battle type indicator
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Battle: " .. self.battle_type:gsub("_", " "):upper(), 10, 10)
    
    -- Draw unit counts
    local allies_alive = 0
    local enemies_alive = 0
    
    for _, unit in ipairs(self.units) do
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
    
    -- Draw result screen
    if self.state == "victory" then
        self:drawResultScreen(self.ui.victory_text, {0.2, 0.8, 0.2, 1.0})
    elseif self.state == "defeat" then
        self:drawResultScreen(self.ui.defeat_text, {0.8, 0.2, 0.2, 1.0})
    end
end

function Battle:drawResultScreen(text, color)
    -- Draw semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, 0, self.width, self.height)
    
    -- Draw result text
    love.graphics.setColor(color)
    local font = love.graphics.getFont()
    local text_width = font:getWidth(text)
    love.graphics.print(text, self.width/2 - text_width/2, self.height/2 - 50)
    
    -- Draw continue text
    love.graphics.setColor(1, 1, 1, 1)
    local continue_width = font:getWidth(self.ui.continue_text)
    love.graphics.print(self.ui.continue_text, self.width/2 - continue_width/2, self.height/2 + 20)
end

function Battle:keypressed(key)
    if key == "space" and (self.state == "victory" or self.state == "defeat") then
        self.state = "finished"
    end
end

function Battle:isFinished()
    return self.state == "finished"
end

function Battle:getResult()
    if self.state == "victory" then
        return true
    elseif self.state == "defeat" then
        return false
    end
    return nil
end

function Battle:setBattleEndCallback(callback)
    self.on_battle_end = callback
end

function Battle:getLostUnits()
    return self.lost_units
end

return Battle 