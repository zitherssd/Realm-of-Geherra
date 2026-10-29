-- game/states/battle_state.lua
-- Battle/combat state
-- Manages the battle loop with a fixed timestep (tick system)

local Input = require("src.core.input")
local BattleSimulation = require("src.game.battle.battle_simulation")
local BattleUnitSystem = require("src.systems.battle.battle_unit_system")
local StateManager = require("src.core.state_manager")
local CombatSystem = require("src.systems.battle.combat_system")
local IdAllocator = require("src.core.id_allocator")
local CampaignBattleResolution = require("src.systems.campaign.campaign_battle_resolution")
local BattleState = {}

local RenderSystem = require("src.systems.battle.render_system")

local GameContext = require("src.game.game_context")
local RangeUtils = require("src.systems.battle.range_utils")
local Aoe = require("src.game.battle.aoe")

local TICK_RATE = 1 / 20
local MAX_FRAME_SKIP = 5
local BattleContext

local function isTargetedAoeSkill(skillData)
    return skillData and skillData.aoe ~= nil
end

local function screenToWorld(context, screenX, screenY)
    local camera = context.data.camera
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local zoom = camera and camera.zoom or 1
    return (screenX-screenW/2)/zoom+screenW/2+(camera and camera.x or 0),
        (screenY-screenH/2)/zoom+screenH/2+(camera and camera.y or 0)
end

local function targetingValid(unit, skill, point)
    if not unit or not skill or not point then return false end
    if Aoe.targetingMode(skill.aoe,skill) ~= "ground" then return true end
    local range = RangeUtils.effectiveSkillRange(unit,nil,skill)
    return (point.x-unit.x)^2+(point.y-unit.y)^2 <= range*range+0.01
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

function BattleState.enter(params)
    params = params or {}
    local enemyParty = params.enemyParty
    BattleState.enemyParty = enemyParty
    BattleState.onVictory = params.onVictory
    BattleState.onComplete = params.onComplete
    print(string.format("BattleState: Battle started against party ID: '%s'", tostring(enemyParty and enemyParty.id)))

    local playerParty = GameContext.data.playerParty
    BattleState.simulation = BattleSimulation.new(playerParty, enemyParty, true)
    BattleContext = BattleState.simulation.context
    BattleState.completed = false
    local world = playerParty:getWorld()
    BattleState.encounter = {
        id = IdAllocator.forWorld(world):allocate("player_battle"),
        partyAId = playerParty.id, partyBId = enemyParty.id,
        x = playerParty.x, y = playerParty.y, state = "active"
    }
    playerParty.activeEncounterId, enemyParty.activeEncounterId = BattleState.encounter.id, BattleState.encounter.id
end

function BattleState.exit()
    if BattleState.encounter and BattleState.simulation then
        for _, party in ipairs({BattleState.simulation.partyA, BattleState.simulation.partyB}) do
            if party.activeEncounterId == BattleState.encounter.id then party.activeEncounterId = nil end
        end
        require("src.systems.actors.injury_treatment").update(0, BattleState.simulation.partyA.__world)
    end
    BattleState.enemyParty = nil
    BattleState.onVictory = nil
    BattleState.onComplete = nil
    BattleState.encounter = nil
    if BattleState.simulation then
        BattleState.simulation:destroy()
        BattleState.simulation = nil
    end
    BattleContext = nil
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

    if playerUnit and BattleUnitSystem.canAct(playerUnit) then
        if targetingMode then
            local skill = CombatSystem.getEffectiveSkill(playerUnit, BattleContext.data.targetingSkillId)
            local mode = skill and Aoe.targetingMode(skill.aoe, skill)
            if mode ~= "self" then
                local mx,my = love.mouse.getPosition()
                local wx,wy = screenToWorld(BattleContext,mx,my)
                local bounds = BattleContext.data.bounds
                wx,wy = math.max(0,math.min(bounds.width,wx)),math.max(0,math.min(bounds.height,wy))
                BattleContext.data.targetingPoint = {x=wx,y=wy}
                if mode == "direction" then
                    local dx,dy = wx-playerUnit.x,wy-playerUnit.y
                    local length = math.sqrt(dx*dx+dy*dy)
                    if length > 0 then dx,dy=dx/length,dy/length end
                    BattleContext.data.targetingDirection = {x=dx,y=dy}
                end
            end
            local dx, dy = 0, 0
            if Input.isKeyDown("w") or Input.isKeyDown("up") then dy = -1 end
            if Input.isKeyDown("s") or Input.isKeyDown("down") then dy = 1 end
            if Input.isKeyDown("a") or Input.isKeyDown("left") then dx = -1 end
            if Input.isKeyDown("d") or Input.isKeyDown("right") then dx = 1 end

            if (dx ~= 0 or dy ~= 0) and BattleContext.data.inputCooldown <= 0 then
                local target = BattleContext.data.targetingPoint
                if target then
                    local step = 28
                    local bounds = BattleContext.data.bounds
                    local tx = math.max(0, math.min(bounds.width, target.x + dx * step))
                    local ty = math.max(0, math.min(bounds.height, target.y + dy * step))
                    BattleContext.data.targetingPoint = {x = tx, y = ty}
                    BattleContext.data.inputCooldown = 0.12
                end
            end

            if (Input.isKeyDown("space") or Input.isKeyDown("return")) and BattleContext.data.inputCooldown <= 0 then
                local point = BattleContext.data.targetingPoint
                local skillId = BattleContext.data.targetingSkillId
                if point and skillId and targetingValid(playerUnit,skill,point) then
                    BattleContext.data.playerCommand = {
                        type = "SKILL",
                        skillId = skillId,
                        target = skill and Aoe.targetingMode(skill.aoe,skill) == "direction"
                            and {x=playerUnit.x,y=playerUnit.y} or {x=point.x,y=point.y},
                        targetDirection = BattleContext.data.targetingDirection,
                        unitId = playerUnit.id
                    }
                    BattleContext.data.targetingMode = false
                    BattleContext.data.targetingSkillId = nil
                    BattleContext.data.targetingPoint = nil
                    BattleContext.data.targetingDirection = nil
                end
                BattleContext.data.inputCooldown = 0.2
            elseif Input.isKeyDown("escape") and BattleContext.data.inputCooldown <= 0 then
                BattleContext.data.targetingMode = false
                BattleContext.data.targetingSkillId = nil
                BattleContext.data.targetingPoint = nil
                BattleContext.data.targetingDirection = nil
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
                    local skillData = CombatSystem.getEffectiveSkill(playerUnit, skillId)

                    if skillData then
                        if skillData.type == "command" then
                            BattleContext.data.playerCommand = {type="SKILL", skillId=skillId, unitId=playerUnit.id}
                            BattleContext.data.inputCooldown = 0.2
                        elseif isTargetedAoeSkill(skillData) then
                            local nearestEnemy = getNearestEnemyUnit(playerUnit)
                            local defaultPoint = Aoe.targetingMode(skillData.aoe,skillData) == "self" and {x=playerUnit.x,y=playerUnit.y}
                                or (nearestEnemy and {x = nearestEnemy.x, y = nearestEnemy.y} or {x = playerUnit.x, y = playerUnit.y})
                            BattleContext.data.targetingMode = true
                            BattleContext.data.targetingSkillId = skillId
                            BattleContext.data.targetingPoint = defaultPoint
                            BattleContext.data.targetingDirection = nil
                            BattleContext.data.inputCooldown = 0.2
                        else
                            local bestTarget = nil
                            local minDist = math.huge

                            for _, other in ipairs(BattleContext.data.unitList) do
                                if other.hp > 0 and not other.escaped and
                                    ((skillData.healing and other.team == playerUnit.team and other.hp < other.maxHp) or
                                    (not skillData.healing and other.team ~= playerUnit.team)) then
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
                                    target = skillData.aoe and skillData.aoe.eligibility == "allies"
                                        and {x = playerUnit.x, y = playerUnit.y} or nil,
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
    if playerUnit and BattleUnitSystem.canAct(playerUnit) and not BattleContext.data.playerCommand then
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

function BattleState.mousepressed(x, y, button)
    local data = BattleContext and BattleContext.data
    if not data or not data.targetingMode then return end
    if button == 2 then
        data.targetingMode, data.targetingSkillId, data.targetingPoint, data.targetingDirection = false,nil,nil,nil
    elseif button == 1 then
        local unit = data.units[data.selectedUnitId]
        local skill = unit and CombatSystem.getEffectiveSkill(unit,data.targetingSkillId)
        local point = data.targetingPoint
        local direction
        if unit and skill and Aoe.targetingMode(skill.aoe,skill) ~= "self" then
            local wx,wy = screenToWorld(BattleContext,x,y)
            local bounds=data.bounds
            point={x=math.max(0,math.min(bounds.width,wx)),y=math.max(0,math.min(bounds.height,wy))}
            if Aoe.targetingMode(skill.aoe,skill) == "direction" then
                local dx,dy=point.x-unit.x,point.y-unit.y
                local length=math.sqrt(dx*dx+dy*dy)
                if length>0 then direction={x=dx/length,y=dy/length} end
            end
        else
            direction=data.targetingDirection
        end
        if unit and skill and point and targetingValid(unit,skill,point) then
            local mode = Aoe.targetingMode(skill.aoe,skill)
            local target = mode == "direction" and {x=unit.x,y=unit.y} or
                (mode == "self" and {x=unit.x,y=unit.y} or {x=point.x,y=point.y})
            data.playerCommand = {type="SKILL",skillId=skill.id,target=target,
                targetDirection=direction,unitId=unit.id}
        end
        if unit and skill and point and targetingValid(unit,skill,point) then
            data.targetingMode, data.targetingSkillId, data.targetingPoint, data.targetingDirection = false,nil,nil,nil
        end
    end
end

function BattleState.checkBattleEnd()
    if not BattleContext or BattleState.completed then return end
    local outcome, winnerPartyId = BattleState.simulation:getOutcome()
    if not outcome then return end
    -- Guard before notifications/callbacks, which may check completion again.
    BattleState.completed = true
    local simulation = BattleState.simulation
    local result = simulation:buildResult(outcome, winnerPartyId)
    local encounter = BattleState.encounter
    encounter.state = "completed"
    local resolved = CampaignBattleResolution.resolve(result, {
        map = GameContext.data.currentMap, encounter = encounter,
        parties = {simulation.partyA, simulation.partyB}, rewardPolicy = "player"
    })
    local victory = winnerPartyId == simulation.partyA.id
    local rewards = resolved.rewards
    if victory and BattleState.onVictory then BattleState.onVictory() end
    if BattleState.onComplete then
        local callback = BattleState.onComplete
        BattleState.onComplete = nil
        callback({outcome = outcome, winnerPartyId = winnerPartyId})
    end
    local player = simulation.context.data.playerUnit
    if victory or (player and player.hp > 0) then
        rewards.victory = victory
        if not victory then rewards.loot, rewards.gold, rewards.favor = {}, 0, 0 end
        StateManager.swap("battle_end", rewards)
    else
        StateManager.swap("menu")
    end
end

function BattleState._tick()
    if BattleState.simulation then
        BattleState.simulation:tick()
    end
end

function BattleState.draw()
    love.graphics.clear(0.1, 0.1, 0.1)

    RenderSystem.draw(BattleContext)
    RenderSystem.drawMoraleDebug(BattleContext)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Battle Tick: " .. tostring(BattleContext.data.tick), 10, 10)

    local playerUnit = BattleContext.data.units[BattleContext.data.selectedUnitId]
    if playerUnit and BattleUnitSystem.canAct(playerUnit) and not BattleContext.data.playerCommand then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Waiting for Input...", 10, 30)
    end

    if BattleContext.data.targetingMode and BattleContext.data.targetingPoint then
        local skill = CombatSystem.getEffectiveSkill(playerUnit,BattleContext.data.targetingSkillId)
        local point = BattleContext.data.targetingPoint
        local mode = skill and Aoe.targetingMode(skill.aoe,skill)
        if mode == "self" then point = playerUnit end
        local valid = targetingValid(playerUnit,skill,point)
        RenderSystem.drawTargetingPreview(BattleContext,skill,point,BattleContext.data.targetingDirection,valid)
        love.graphics.setColor(valid and 0.6 or 1,valid and 1 or 0.2,valid and 0.6 or 0.2,1)
        love.graphics.print(valid and "TARGETING MODE" or "OUT OF RANGE",10,50)
    end

    if playerUnit and playerUnit.skillList then
        local screenW = love.graphics.getWidth()
        local uiX = screenW - 220
        local uiY = 20

        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", uiX, uiY, 200, #playerUnit.skillList * 40 + 10)

        for i, skillId in ipairs(playerUnit.skillList) do
            local skill = CombatSystem.getEffectiveSkill(playerUnit, skillId)
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
