local BattleState = {}
local playerInputs = require("src.game.battle.BattlePlayerInput")
local grid = require("src.game.battle.BattleGrid")
local gridActions = require("src.game.battle.BattleGridActions")
local ui = require("src.game.battle.BattleUI")
local animation = require("src.game.battle.BattleAnimations")
local renderer = require("src.game.battle.BattleRenderer")
local Camera = require("src.game.battle.BattleCamera")
local PartyModule = require("src.game.modules.PartyModule")
local PlayerModule = require("src.game.modules.PlayerModule")
local ai = require("src.game.battle.BattleUnitAI")
local InputModule = require('src.game.modules.InputModule')

-- Constants
local TICKS_PER_SECOND = 20

local paused = false
local pauseReason = nil

function BattleState:enter(party1, party2, stage)
    grid:initializeGrid()
    self.units = {}
    self.projectiles = {}
    self.currentTick = 0
    self.tickTimer = 0
    self.playerUnit = PlayerModule:getPlayerUnit();
    self.playerParty = party1
    self.enemyParty = party2
    self.selectedAction = 1 -- focused action index for player unit
    self:deployParties(party1, party2)
    -- Reset transient action state for a clean battle start
    for _, u in ipairs(self.units or {}) do
        u.pending_action = nil
        u.action_cooldown = 0
        local unitActions = u:getActions()
        if unitActions then
            for _, a in ipairs(unitActions) do
                a.last_used_tick = nil
                a.executed_tick = nil
            end
        end
    end
    playerInputs:init(self)
    ai:init(self)
    -- Reset UI victory state
    ui.result = nil
    ui.startCountdown = false
    ui.resultTimer = nil
end

function BattleState:pause(reason)
    self.paused = true
    self.pauseReason = reason
end

function BattleState:unpause()
    self.paused = false
    self.pauseReason = nil
end

function BattleState:deployParties(party1, party2)
    
    -- Calculate center Y position
    local centerY = math.floor(grid.GRID_HEIGHT / 2)
    
    -- Deploy party 1 on the left side
    local leftX = 1
    self:deployUnitAccordingToParty(party1.units, leftX, centerY, 1, true)
    
    -- Deploy party 2 on the right side
    local rightX = grid.GRID_WIDTH - 15
    self:deployUnitAccordingToParty(party2.units, rightX, centerY, 2, false)
end

function BattleState:deployUnitAccordingToParty(units, startX, centerY, partyNum, facingRight)
    for _, unit in ipairs(units) do
        table.insert(self.units, unit)
        unit.battle_party = partyNum
        unit.facing_right = facingRight
        unit.action_cooldown = 0
        
        -- Dirty
        if not gridActions:placeUnitInCellByXY(unit, startX, centerY) then 
        else if not gridActions:placeUnitInCellByXY(unit, startX, centerY+1) then
        else if not gridActions:placeUnitInCellByXY(unit, startX, centerY-1) then
        else if not gridActions:placeUnitInCellByXY(unit, startX, centerY+2) then
        else if not gridActions:placeUnitInCellByXY(unit, startX, centerY-2) then
        else
            print("Failed to place unit: " .. unit.name)
        end end end end end
    end
end

-- Remove units with health <= 0 from grid cells, battle list, and their party lists
function BattleState:cleanupDeadUnits()
    if not self.units then return end
    local alive = {}

    local function removeFrom(list, obj)
        if not list then return end
        for i = #list, 1, -1 do
            if list[i] == obj then
                table.remove(list, i)
                break
            end
        end
    end

    for _, unit in ipairs(self.units) do
        if unit.health and unit.health <= 0 then
            -- Remove from grid cell if present
            if unit.currentCell then
                grid:removeUnitFromCell(unit, unit.currentCell)
            end
            -- Remove from owning party table
            if unit.battle_party == 1 and self.playerParty and self.playerParty.units then
                removeFrom(self.playerParty.units, unit)
            elseif unit.battle_party == 2 and self.enemyParty and self.enemyParty.units then
                removeFrom(self.enemyParty.units, unit)
            end
            -- Clear player reference if it was the player unit
            if self.playerUnit == unit then
                self.playerUnit = nil
            end
        else
            table.insert(alive, unit)
        end
    end

    self.units = alive
end

function BattleState:update(dt)

        playerInputs:update(dt)
        local playerReady = self.playerUnit and 
                          self.playerUnit.health > 0 and 
                          (self.playerUnit.action_cooldown <= 0)
        
        -- Wait on player action
        if playerReady and not self.paused then
            self:pause("player_turn")
        elseif not playerReady and self.paused and self.pauseReason == "player_turn" then
            self:unpause()
        end
        
        -- Update battle logic if not paused
        if not self.paused then
            -- Update projectiles (Visuals + Logic)
            for i = #self.projectiles, 1, -1 do
                local p = self.projectiles[i]
                if p:update(dt, self) then
                    table.remove(self.projectiles, i)
                end
            end

            self.tickTimer = self.tickTimer + dt
            local ticksThisFrame = math.floor(self.tickTimer * TICKS_PER_SECOND)
            
            for i = 1, ticksThisFrame do
                self.currentTick = self.currentTick + 1
                for _, unit in ipairs(self.units) do
                    if unit.health > 0 then
                        ai:unitTick(unit, self)
                    end
                end
            end
            
            self.tickTimer = self.tickTimer - (ticksThisFrame / TICKS_PER_SECOND)
            
            -- Remove dead units from grid, battle list, and party lists
            self:cleanupDeadUnits()
            
            -- Check victory condition
            local result = self:checkVictory(self.units)
            if result then
                ui:setResult(result)
            end
        end

    ui:update(dt)
    animation:updateAnimation(dt, self.units)
    Camera:update(dt, self.playerUnit)
end

function BattleState:keypressed(key)
    -- Route through InputModule for action mapping (e.g., switch_panel_next/prev)
    InputModule:handleKeyEvent(key, self)
    -- Preserve existing direct controls
    playerInputs:keypressed(key)
end

function BattleState:onAction(action)
    if action == 'switch_panel_next' then
        local unitActions = self.playerUnit and self.playerUnit:getActions()
        if unitActions and #unitActions > 0 then
            self.selectedAction = (self.selectedAction % #unitActions) + 1
        end
        return
    elseif action == 'switch_panel_prev' then
        local unitActions = self.playerUnit and self.playerUnit:getActions()
        if unitActions and #unitActions > 0 then
            self.selectedAction = ((self.selectedAction - 2) % #unitActions) + 1
        end
        return
    end
end

function BattleState:draw()
    -- Draw background
    love.graphics.setColor(0.2, 0.3, 0.4, 1)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getDimensions())
    
    Camera:apply()
    -- Draw grid
    grid:draw()
    
    -- Draw units
    renderer:drawUnits(self.units)
    renderer:drawProjectiles(self.projectiles)
    -- Draw world-space UI (e.g., damage popups)
    ui:drawWorld(self)
    Camera:unapply()
    
    -- Draw UI elements
    ui:draw(self)
end

function BattleState:checkVictory(units)
    local alive1, alive2 = false, false
    
    for _, unit in ipairs(units) do
        if unit.battle_party == 1 and unit.health > 0 then
            alive1 = true
        elseif unit.battle_party == 2 and unit.health > 0 then
            alive2 = true
        end
    end
    
    if not alive1 then
        return "Enemy Victory!"
    elseif not alive2 then
        self:playerWinCleanup()
        return "Player Victory!"
    end
    
    return nil
end

function BattleState:playerWinCleanup()
    local idx = nil
    for i, p in ipairs(PartyModule.parties) do
        if p == self.enemyParty then
            idx = i
            break
        end
    end
    if idx then
        table.remove(PartyModule.parties, idx)
    end
end

return BattleState