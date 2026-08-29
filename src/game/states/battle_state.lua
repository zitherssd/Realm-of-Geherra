-- game/states/battle_state.lua
-- Battle/combat state
-- Manages the battle loop with a fixed timestep (tick system)

local Input = require("src.core.input")
local BattleContext = require("src.game.battle.battle_context")
local BattleUnit = require("src.game.battle.battle_unit")
local StateManager = require("src.core.state_manager")
local Skills = require("src.data.skills")
local LootGeneratorSystem = require("src.systems.loot_generator_system")
local EventBus = require("src.core.event_bus")
local PartySystem = require("src.systems.party_system")
local BattleState = {}

local DecisionSystem = require("src.systems.battle.decision_system")
local ExecutionSystem = require("src.systems.battle.execution_system")
local RenderSystem = require("src.systems.battle.render_system")

local GameContext = require("src.game.game_context")
local RangeUtils = require("src.systems.battle.range_utils")

local TICK_RATE = 1 / 20
local MAX_FRAME_SKIP = 5
local WORLD_BOUNDS = {
    width = 1260,
    height = 546
}

local function isTargetedAoeSkill(skillData)
    return skillData and skillData.type == "aoe" and skillData.targeted == true
end

local function worldToScreen(context, worldX, worldY)
    local camera = context.data.camera
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local zoom = (camera and camera.zoom) or 1.0
    local camX = (camera and camera.x) or 0
    local camY = (camera and camera.y) or 0

    local sx = ((worldX - camX) - screenW / 2) * zoom + screenW / 2
    local sy = ((worldY - camY) - screenH / 2) * zoom + screenH / 2
    return sx, sy, zoom
end

local function getNearestEnemyUnit(playerUnit)
    if not playerUnit then return nil end
    local nearestEnemy = nil
    local minDist = math.huge

    for _, other in ipairs(BattleContext.data.unitList) do
        if other.team ~= playerUnit.team and other.hp > 0 then
            local dx = playerUnit.x - other.x
            local dy = playerUnit.y - other.y
            local distSq = dx * dx + dy * dy
            if distSq < minDist then
                minDist = distSq
                nearestEnemy = other
            end
        end
    end

    return nearestEnemy
end

-- Crude measure of a party's total combat strength. Used as a difficulty
-- proxy so harder battles (bigger/stronger enemy parties) grant more favor.
local function computePartyPower(party)
    local power = 0
    if party and party.actors then
        for _, actor in ipairs(party.actors) do
            local stats = actor.stats or {}
            local hp = actor.maxHp or stats.health or 50
            local attack = stats.attack or 10
            local defense = stats.defense or 10
            power = power + hp + (attack * 2) + (defense * 2)
        end
    end
    return power
end

function BattleState.enter(params)
    params = params or {}
    local enemyParty = params.enemyParty
    BattleState.enemyParty = enemyParty
    BattleState.onVictory = params.onVictory
    print(string.format("BattleState: Battle started against party ID: '%s'", tostring(enemyParty and enemyParty.id)))

    BattleContext.init(WORLD_BOUNDS)

    local playerParty = GameContext.data.playerParty
    if playerParty and playerParty.actors then
        local startX = 180
        local startY = 120
        local spacingX = 72
        local spacingY = 78

        for i, actor in ipairs(playerParty.actors) do
            local x = startX + math.floor((i - 1) / 5) * spacingX
            local y = startY + ((i - 1) % 5) * spacingY

            local unit = BattleUnit.new(actor, x, y, "player")
            unit:snapToWorld()
            BattleContext.addUnit(unit)

            if i == 1 then
                BattleContext.data.selectedUnitId = unit.id
                BattleContext.data.playerUnit = unit
            end
        end
    end

    if enemyParty and enemyParty.actors then
        local startX = WORLD_BOUNDS.width - 180
        local startY = 120
        local spacingX = 72
        local spacingY = 78

        for i, actor in ipairs(enemyParty.actors) do
            local x = startX - math.floor((i - 1) / 5) * spacingX
            local y = startY + ((i - 1) % 5) * spacingY

            local unit = BattleUnit.new(actor, x, y, "enemy")
            unit:snapToWorld()
            BattleContext.addUnit(unit)
        end
    end
end

function BattleState.exit()
    BattleState.enemyParty = nil
    BattleState.onVictory = nil
end

function BattleState.update(dt)
    if BattleContext.data.paused then return end

    if BattleContext.data.inputCooldown > 0 then
        BattleContext.data.inputCooldown = BattleContext.data.inputCooldown - dt
    end

    local playerUnit = BattleContext.data.units[BattleContext.data.selectedUnitId]
    local targetingMode = BattleContext.data.targetingMode

    if not targetingMode and Input.isKeyDown("tab") and BattleContext.data.inputCooldown <= 0 then
        BattleContext.data.selectedSkillIndex = BattleContext.data.selectedSkillIndex + 1
        if playerUnit and playerUnit.skillList then
            if BattleContext.data.selectedSkillIndex > #playerUnit.skillList then
                BattleContext.data.selectedSkillIndex = 1
            end
        else
            BattleContext.data.selectedSkillIndex = 1
        end
        BattleContext.data.inputCooldown = 0.2
    end

    if playerUnit and playerUnit:canAct() then
        if targetingMode then
            local dx, dy = 0, 0
            if Input.isKeyDown("w") or Input.isKeyDown("up") then dy = -1 end
            if Input.isKeyDown("s") or Input.isKeyDown("down") then dy = 1 end
            if Input.isKeyDown("a") or Input.isKeyDown("left") then dx = -1 end
            if Input.isKeyDown("d") or Input.isKeyDown("right") then dx = 1 end

            if (dx ~= 0 or dy ~= 0) and BattleContext.data.inputCooldown <= 0 then
                local target = BattleContext.data.targetingPoint
                if target then
                    local step = 28
                    local tx = math.max(0, math.min(WORLD_BOUNDS.width, target.x + dx * step))
                    local ty = math.max(0, math.min(WORLD_BOUNDS.height, target.y + dy * step))
                    BattleContext.data.targetingPoint = {x = tx, y = ty}
                    BattleContext.data.inputCooldown = 0.12
                end
            end

            if (Input.isKeyDown("space") or Input.isKeyDown("return")) and BattleContext.data.inputCooldown <= 0 then
                local point = BattleContext.data.targetingPoint
                local skillId = BattleContext.data.targetingSkillId
                if point and skillId then
                    BattleContext.data.playerCommand = {
                        type = "SKILL",
                        skillId = skillId,
                        target = {x = point.x, y = point.y},
                        unitId = playerUnit.id
                    }
                end
                BattleContext.data.targetingMode = false
                BattleContext.data.targetingSkillId = nil
                BattleContext.data.targetingPoint = nil
                BattleContext.data.inputCooldown = 0.2
            elseif Input.isKeyDown("escape") and BattleContext.data.inputCooldown <= 0 then
                BattleContext.data.targetingMode = false
                BattleContext.data.targetingSkillId = nil
                BattleContext.data.targetingPoint = nil
                BattleContext.data.inputCooldown = 0.2
            end
        else
            local dx, dy = 0, 0
            if Input.isKeyDown("w") or Input.isKeyDown("up") then dy = -1 end
            if Input.isKeyDown("s") or Input.isKeyDown("down") then dy = 1 end
            if Input.isKeyDown("a") or Input.isKeyDown("left") then dx = -1 end
            if Input.isKeyDown("d") or Input.isKeyDown("right") then dx = 1 end

            if dx ~= 0 or dy ~= 0 then
                local targetX = playerUnit.x + dx * (playerUnit.moveStep or 24)
                local targetY = playerUnit.y + dy * (playerUnit.moveStep or 24)

                BattleContext.data.playerCommand = {
                    type = "MOVE",
                    target = {x = targetX, y = targetY},
                    unitId = playerUnit.id
                }
            end

            if Input.isKeyDown("space") and BattleContext.data.inputCooldown <= 0 then
                if playerUnit.skillList and #playerUnit.skillList > 0 then
                    local skillId = playerUnit.skillList[BattleContext.data.selectedSkillIndex]
                    local skillData = Skills[skillId]

                    if skillData then
                        if isTargetedAoeSkill(skillData) then
                            local nearestEnemy = getNearestEnemyUnit(playerUnit)
                            local defaultPoint = nearestEnemy and {x = nearestEnemy.x, y = nearestEnemy.y} or {x = playerUnit.x, y = playerUnit.y}
                            BattleContext.data.targetingMode = true
                            BattleContext.data.targetingSkillId = skillId
                            BattleContext.data.targetingPoint = defaultPoint
                            BattleContext.data.inputCooldown = 0.2
                        else
                            local bestTarget = nil
                            local minDist = math.huge

                            for _, other in ipairs(BattleContext.data.unitList) do
                                if other.team ~= playerUnit.team and other.hp > 0 then
                                    local effectiveRange = RangeUtils.effectiveSkillRange(playerUnit, other, skillData)
                                    local rangeSq = effectiveRange * effectiveRange

                                    local tdx = playerUnit.x - other.x
                                    local tdy = playerUnit.y - other.y
                                    local dist = tdx * tdx + tdy * tdy

                                    if dist <= rangeSq and dist < minDist then
                                        minDist = dist
                                        bestTarget = other
                                    end
                                end
                            end

                            if bestTarget then
                                BattleContext.data.playerCommand = {
                                    type = "SKILL",
                                    skillId = skillId,
                                    targetUnitId = bestTarget.id,
                                    unitId = playerUnit.id
                                }
                                BattleContext.data.inputCooldown = 0.2
                            end
                        end
                    end
                end
            end
        end
    end

    local waitingForInput = false
    if playerUnit and playerUnit:canAct() and not BattleContext.data.playerCommand then
        waitingForInput = true
    end

    if not waitingForInput then
        BattleContext.data.accumulator = BattleContext.data.accumulator + dt
        local loops = 0
        while BattleContext.data.accumulator >= TICK_RATE and loops < MAX_FRAME_SKIP do
            BattleState._tick()
            BattleContext.data.accumulator = BattleContext.data.accumulator - TICK_RATE
            loops = loops + 1
        end
    end

    RenderSystem.update(dt, BattleContext)
    BattleState.checkBattleEnd()
end

function BattleState.checkBattleEnd()
    local playerAlive = false
    local enemyAlive = false

    for _, unit in pairs(BattleContext.data.units) do
        if unit.hp > 0 then
            if unit.team == "player" then playerAlive = true end
            if unit.team == "enemy" then enemyAlive = true end
        end
    end

    local playerCasualties = {}
    local enemyCasualties = {}
    local generatedLoot = {}
    local generatedGold = 0

    for _, unit in ipairs(BattleContext.data.casualties) do
        local name = unit.name or (unit.actor and unit.actor.name) or "Unknown Unit"
        if unit.team == "player" then
            table.insert(playerCasualties, name)
        elseif unit.team == "enemy" then
            table.insert(enemyCasualties, name)

            if unit.actor and unit.actor.troopType then
                local _, goldFromUnit = LootGeneratorSystem.generateFromTroop(unit.actor.troopType, generatedLoot)
                generatedGold = generatedGold + (goldFromUnit or 0)
            end
        end
    end

    if not playerAlive or not enemyAlive then
        local playerParty = GameContext.data.playerParty

        if playerAlive and playerParty and generatedGold > 0 then
            playerParty:addTreasury(generatedGold)
        end

        for _, unit in pairs(BattleContext.data.units) do
            if unit.actor and unit.team == "player" then
                unit.actor.hp = unit.hp
                unit.actor.maxHp = unit.maxHp
            end
        end

        for _, unit in ipairs(BattleContext.data.casualties) do
            if unit.actor and unit.team == "player" then
                unit.actor.hp = 0
                unit.actor.maxHp = unit.maxHp
                PartySystem.removeFromParty(playerParty, unit.actor.id)
            end
        end

        if playerAlive and BattleState.enemyParty and GameContext.data.currentMap then
            GameContext.data.currentMap:removeParty(BattleState.enemyParty.id)
            print("BattleState: Emitting party_killed for " .. tostring(BattleState.enemyParty.id))
            EventBus.emit("party_killed", BattleState.enemyParty.id)
        end

        local favorGained = 0
        if playerAlive then
            -- Reward favor based on how hard the battle was: the stronger the
            -- enemy party is relative to the player's party, the more favor.
            local enemyPower = computePartyPower(BattleState.enemyParty)
            local playerPower = math.max(1, computePartyPower(GameContext.data.playerParty))
            local difficulty = enemyPower / playerPower
            favorGained = math.floor(4 + difficulty * 8)
            GameContext.data.favor = (GameContext.data.favor or 0) + favorGained
        end

        if playerAlive then
            if BattleState.onVictory then
                BattleState.onVictory()
            end

            StateManager.swap("battle_end", {
                victory = true,
                playerCasualties = playerCasualties,
                enemyCasualties = enemyCasualties,
                loot = generatedLoot,
                gold = generatedGold,
                favor = favorGained
            })
        else
            StateManager.swap("menu")
        end
    end
end

function BattleState._tick()
    BattleContext.data.tick = BattleContext.data.tick + 1

    DecisionSystem.update(BattleContext)
    ExecutionSystem.update(BattleContext)
    BattleContext.removeDeadUnits()
end

function BattleState.draw()
    love.graphics.clear(0.1, 0.1, 0.1)

    RenderSystem.draw(BattleContext)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Battle Tick: " .. tostring(BattleContext.data.tick), 10, 10)

    local playerUnit = BattleContext.data.units[BattleContext.data.selectedUnitId]
    if playerUnit and playerUnit:canAct() and not BattleContext.data.playerCommand then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Waiting for Input...", 10, 30)
    end

    if BattleContext.data.targetingMode and BattleContext.data.targetingPoint then
        local tx = BattleContext.data.targetingPoint.x
        local ty = BattleContext.data.targetingPoint.y
        local sx, sy, zoom = worldToScreen(BattleContext, tx, ty)
        love.graphics.setColor(1, 0.1, 0.1, 1)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", sx, sy, 18 * zoom)
        love.graphics.setLineWidth(1)
        love.graphics.print("TARGETING MODE", 10, 50)
    end

    if playerUnit and playerUnit.skillList then
        local screenW = love.graphics.getWidth()
        local uiX = screenW - 220
        local uiY = 20

        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", uiX, uiY, 200, #playerUnit.skillList * 40 + 10)

        for i, skillId in ipairs(playerUnit.skillList) do
            local skill = Skills[skillId]
            if skill then
                local y = uiY + 10 + (i - 1) * 40

                if i == BattleContext.data.selectedSkillIndex then
                    love.graphics.setColor(1, 1, 0, 0.3)
                    love.graphics.rectangle("fill", uiX + 5, y, 190, 35)
                end

                if playerUnit.currentCast and playerUnit.currentCast.skillId == skillId then
                    local total = skill.windup or 1
                    local current = playerUnit.currentCast.remaining
                    local progress = math.max(0, math.min(1, 1.0 - (current / total)))

                    love.graphics.setColor(0.2, 0.8, 1, 0.5)
                    love.graphics.rectangle("fill", uiX + 5, y, 190 * progress, 35)
                elseif (playerUnit.cooldowns[skillId] or 0) > 0 then
                    local total = skill.cooldown or 20
                    local current = playerUnit.cooldowns[skillId]
                    local progress = math.max(0, math.min(1, current / total))

                    love.graphics.setColor(1, 0.5, 0, 0.3)
                    love.graphics.rectangle("fill", uiX + 5, y, 190 * progress, 35)
                end

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(skill.name, uiX + 10, y + 5)

                local cd = playerUnit.cooldowns[skillId] or 0
                if cd > 0 then
                    love.graphics.setColor(1, 0, 0, 1)
                    love.graphics.print(string.format("%.1fs", cd / 20), uiX + 150, y + 5)
                elseif playerUnit.charges[skillId] then
                    love.graphics.setColor(0, 1, 1, 1)
                    local max = skill.maxCharges or "?"
                    love.graphics.print(string.format("%s/%s", tostring(playerUnit.charges[skillId]), tostring(max)), uiX + 150, y + 5)
                end
            end
        end
    end
end

return BattleState
