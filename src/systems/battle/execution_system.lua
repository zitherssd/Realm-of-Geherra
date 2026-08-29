-- systems/battle/execution_system.lua
-- Resolves intents, updates positions, and applies damage in world space.

local ExecutionSystem = {}
local Skills = require("src.data.skills")
local CombatSystem = require("src.systems.combat_system")

local WORLD_RANGE_SCALE = 42
local PUSH_FACTOR = 0.35
local PUSH_BACK_FACTOR = 0.25
local MIN_DIST_EPSILON = 0.001

local function isFireballProjectile(skillData)
    return skillData and skillData.projectile and skillData.projectile.style == "fireball"
end

local function clampToBounds(value, maxValue)
    if value < 0 then return 0 end
    if value > maxValue then return maxValue end
    return value
end

local function getBounds(context)
    local bounds = context.data.bounds or {}
    return bounds.width or 1260, bounds.height or 546
end

local function clampUnitToBounds(unit, context)
    local width, height = getBounds(context)
    local r = unit.collisionRadius or 0
    unit.x = clampToBounds(unit.x, width)
    unit.y = clampToBounds(unit.y, height)

    if unit.x < r then unit.x = r end
    if unit.y < r then unit.y = r end
    if unit.x > width - r then unit.x = width - r end
    if unit.y > height - r then unit.y = height - r end
end

local function effectiveSkillRange(attacker, target, skillData)
    local baseRange = ((skillData and skillData.range) or 1.5) * WORLD_RANGE_SCALE
    local attackerRadius = attacker.collisionRadius or 0
    local targetRadius = (target and target.collisionRadius) or 0
    return baseRange + attackerRadius + targetRadius
end

local function applyOnHitStatuses(targetUnit, skillData)
    if not targetUnit or not skillData or not skillData.onHitStatuses then return end

    targetUnit.statusEffects = targetUnit.statusEffects or {}
    for statusId, statusConfig in pairs(skillData.onHitStatuses) do
        local duration = 0

        if type(statusConfig) == "number" then
            duration = statusConfig
        elseif type(statusConfig) == "table" then
            duration = statusConfig.duration or statusConfig.remaining or statusConfig.ticks or 0
        elseif statusConfig == true then
            duration = 60
        end

        if duration > 0 then
            local damagePerTick = 0
            local tickEvery = nil

            if type(statusConfig) == "table" then
                damagePerTick = statusConfig.damagePerTick or statusConfig.damage_per_tick or 0
                tickEvery = statusConfig.tickEvery or statusConfig.tick_every
            end

            if damagePerTick > 0 and (not tickEvery or tickEvery < 1) then
                tickEvery = 20
            end

            targetUnit.statusEffects[statusId] = {
                remaining = duration,
                duration = duration,
                sourceSkillId = skillData.id,
                damagePerTick = damagePerTick,
                tickEvery = tickEvery,
                tickCounter = 0
            }
        end
    end
end

local function resolveSoftPush(movingUnit, context)
    local moved = false
    local units = context.data.unitList

    for _, other in ipairs(units) do
        if other ~= movingUnit and other.hp > 0 then
            local dx = other.x - movingUnit.x
            local dy = other.y - movingUnit.y
            local distSq = dx * dx + dy * dy
            local minDist = (movingUnit.collisionRadius or 0) + (other.collisionRadius or 0)
            local minDistSq = minDist * minDist

            if distSq > MIN_DIST_EPSILON and distSq < minDistSq then
                local dist = math.sqrt(distSq)
                local overlap = minDist - dist
                local nx = dx / dist
                local ny = dy / dist

                other.x = other.x + nx * overlap * PUSH_FACTOR
                other.y = other.y + ny * overlap * PUSH_FACTOR
                movingUnit.x = movingUnit.x - nx * overlap * PUSH_BACK_FACTOR
                movingUnit.y = movingUnit.y - ny * overlap * PUSH_BACK_FACTOR

                clampUnitToBounds(other, context)
                clampUnitToBounds(movingUnit, context)
                moved = true
            elseif distSq <= MIN_DIST_EPSILON then
                local nx = (math.random() - 0.5)
                local ny = (math.random() - 0.5)
                local nLen = math.sqrt(nx * nx + ny * ny)
                if nLen > MIN_DIST_EPSILON then
                    nx = nx / nLen
                    ny = ny / nLen
                    other.x = other.x + nx * 2
                    other.y = other.y + ny * 2
                    clampUnitToBounds(other, context)
                end
                moved = true
            end
        end
    end

    return moved
end

function ExecutionSystem._resolveAoeAtPoint(attackerUnit, skillData, targetX, targetY, context)
    local aoeRadius = math.max(24, ((skillData.aoe or 1) * WORLD_RANGE_SCALE * 0.8))
    local aoeRadiusSq = aoeRadius * aoeRadius

    for _, targetUnit in ipairs(context.data.unitList) do
        if targetUnit.team ~= attackerUnit.team and targetUnit.hp > 0 then
            local dx = targetUnit.x - targetX
            local dy = targetUnit.y - targetY
            local distSq = dx * dx + dy * dy
            local reach = aoeRadius + (targetUnit.collisionRadius or 0)
            if distSq <= (reach * reach) then
                local result = CombatSystem.resolveAttack(attackerUnit, targetUnit, skillData)
                ExecutionSystem.applyAttackResult(result, targetUnit, context, skillData)
            end
        end
    end
end

function ExecutionSystem.update(context)
    local units = context.data.unitList

    -- 1. Decrement cooldowns and process casts/statuses.
    for _, unit in ipairs(units) do
        if unit.globalCooldown > 0 then
            unit.globalCooldown = unit.globalCooldown - 1
        end
        if unit.moveCooldown and unit.moveCooldown > 0 then
            unit.moveCooldown = unit.moveCooldown - 1
        end

        for skillId, cd in pairs(unit.cooldowns) do
            if cd > 0 then
                unit.cooldowns[skillId] = cd - 1
            end
        end

        if unit.statusEffects then
            for effectId, effectData in pairs(unit.statusEffects) do
                if type(effectData) == "table" and effectData.remaining then
                    if (effectData.damagePerTick or 0) > 0 and (effectData.tickEvery or 0) > 0 then
                        effectData.tickCounter = (effectData.tickCounter or 0) + 1
                        if effectData.tickCounter >= effectData.tickEvery then
                            effectData.tickCounter = 0
                            local dotDamage = math.max(0, math.floor(effectData.damagePerTick or 0))
                            if dotDamage > 0 and unit.hp > 0 then
                                CombatSystem._applyBattleDamage(unit, dotDamage)
                                if context.addFloatingText then
                                    context.addFloatingText(unit.visualX, unit.visualY, tostring(dotDamage), {1, 0.45, 0.15, 1})
                                end
                            end
                        end
                    end

                    effectData.remaining = effectData.remaining - 1
                    if effectData.remaining <= 0 then
                        unit.statusEffects[effectId] = nil
                    end
                end
            end
        end

        if unit.currentCast then
            if unit.hp <= 0 then
                unit.currentCast = nil
            else
                unit.currentCast.remaining = unit.currentCast.remaining - 1
                if unit.currentCast.remaining <= 0 then
                    ExecutionSystem._completeCast(unit, context)
                end
            end
        end
    end

    -- 2. Resolve intents.
    for _, unit in ipairs(units) do
        if unit.intent then
            if unit.hp > 0 then
                local intent = unit.intent

                if intent.type == "MOVE" then
                    ExecutionSystem._executeMove(unit, intent, context)
                elseif intent.type == "SKILL" then
                    ExecutionSystem._initiateSkill(unit, intent, context)
                end
            end

            unit.intent = nil
        end
    end

    -- 3. Update projectiles.
    ExecutionSystem._updateProjectiles(context)
end

function ExecutionSystem._executeMove(unit, intent, context)
    if unit.globalCooldown > 0 then return end

    local targetX = intent.target and intent.target.x
    local targetY = intent.target and intent.target.y
    if not targetX or not targetY then return end

    local dx = targetX - unit.x
    local dy = targetY - unit.y
    local distSq = dx * dx + dy * dy
    local dist = math.sqrt(distSq)

    if dist <= MIN_DIST_EPSILON then
        unit.state = "idle"
        return
    end

    local step = unit.moveStep or 24
    local moveDist = math.min(step, dist)
    local nx = dx / dist
    local ny = dy / dist

    unit.x = unit.x + nx * moveDist
    unit.y = unit.y + ny * moveDist
    unit.velocityX = nx * moveDist
    unit.velocityY = ny * moveDist
    unit.moveTarget = {x = targetX, y = targetY}
    unit.state = "moving"

    if unit.velocityX > 0 then
        unit.facing = -1
    elseif unit.velocityX < 0 then
        unit.facing = 1
    end

    clampUnitToBounds(unit, context)
    resolveSoftPush(unit, context)

    local battleSpeed = unit.stats.battle_speed or 10
    local variance = (math.random() - 0.5) * 0.2
    local cooldownTicks = (120 * (1 + variance)) / battleSpeed
    unit.moveCooldown = cooldownTicks
    unit.globalCooldown = cooldownTicks
end

function ExecutionSystem._initiateSkill(unit, intent, context)
    local skillId = intent.skillId
    local skillData = Skills[skillId]

    if intent.target then
        if intent.target.x > unit.x then
            unit.facing = -1
        elseif intent.target.x < unit.x then
            unit.facing = 1
        end
    elseif intent.targetUnitId then
        local target = context.data.units[intent.targetUnitId]
        if target then
            if target.x > unit.x then
                unit.facing = -1
            elseif target.x < unit.x then
                unit.facing = 1
            end
        end
    end

    if skillData then
        local windup = skillData.windup or 0

        if windup > 0 then
            unit.currentCast = {
                skillId = skillId,
                target = intent.target,
                targetUnitId = intent.targetUnitId,
                remaining = windup
            }
            unit.globalCooldown = windup

            unit.visualEffects.flashTime = 0.2
            unit.visualEffects.flashDuration = 0.2
            unit.visualEffects.flashColor = {1, 1, 0.8}
            unit.visualEffects.flashIntensity = 0.5
        else
            ExecutionSystem._executeSkillEffect(unit, skillId, intent.targetUnitId, intent.target, context)
        end
    end
end

function ExecutionSystem._completeCast(unit, context)
    if not unit.currentCast then return end

    ExecutionSystem._executeSkillEffect(
        unit,
        unit.currentCast.skillId,
        unit.currentCast.targetUnitId,
        unit.currentCast.target,
        context
    )
    unit.currentCast = nil
end

function ExecutionSystem._executeSkillEffect(unit, skillId, targetUnitId, targetPoint, context)
    local skillData = Skills[skillId]
    if not skillData then return end

    local targetUnit = context.data.units[targetUnitId]
    local isTargetedAoe = skillData.type == "aoe" and skillData.targeted == true
    local castTargetX = nil
    local castTargetY = nil

    if isTargetedAoe then
        if targetPoint and targetPoint.x and targetPoint.y then
            castTargetX = targetPoint.x
            castTargetY = targetPoint.y
        elseif targetUnit and targetUnit.hp > 0 then
            castTargetX = targetUnit.x
            castTargetY = targetUnit.y
        end

        if castTargetX and castTargetY then
            local dx = castTargetX - unit.x
            local dy = castTargetY - unit.y
            local distSq = dx * dx + dy * dy
            local maxRange = (skillData.range or 1.5) * WORLD_RANGE_SCALE
            if distSq > (maxRange * maxRange) + 0.01 then
                local fallback = context.findNearestHostile(unit, maxRange)
                if fallback then
                    castTargetX = fallback.x
                    castTargetY = fallback.y
                    targetUnit = fallback
                else
                    castTargetX = nil
                    castTargetY = nil
                end
            end
        end
    else
        local isValid = false

        if targetUnit and targetUnit.hp > 0 then
            local dx = targetUnit.x - unit.x
            local dy = targetUnit.y - unit.y
            local distSq = dx * dx + dy * dy
            local range = effectiveSkillRange(unit, targetUnit, skillData)
            if distSq <= (range * range) + 0.01 then
                isValid = true
            end
        end

        if not isValid then
            local fallbackRange = (skillData.range or 1.5) * WORLD_RANGE_SCALE
            targetUnit = context.findNearestHostile(unit, fallbackRange)
        end

        if targetUnit then
            castTargetX = targetUnit.x
            castTargetY = targetUnit.y
        end
    end

    if castTargetX and castTargetY then
        local dx = castTargetX - unit.x
        local dy = castTargetY - unit.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist > 0 then
            unit.visualEffects.lungeX = dx / dist
            unit.visualEffects.lungeY = dy / dist
            unit.visualEffects.lungeTime = 0.2
            unit.visualEffects.lungeDuration = 0.2
        end

        if skillData.projectile then
            local proj = {
                x = unit.x,
                y = unit.y,
                visualX = unit.x,
                visualY = unit.y,
                startX = unit.x,
                startY = unit.y,
                targetX = castTargetX,
                targetY = castTargetY,
                targetUnitId = targetUnit and targetUnit.id or targetUnitId,
                attackerUnit = unit,
                skillId = skillId,
                style = skillData.projectile.style,
                speed = skillData.projectile.speed or 10,
                sprite = skillData.projectile.sprite,
                arc = skillData.projectile.arc or 0,
                progress = 0
            }

            if isFireballProjectile(skillData) then
                proj.trailParticles = {}
                proj.trailSpawnTimer = 0
            end

            context.addProjectile(proj)
        else
            if isTargetedAoe then
                ExecutionSystem._resolveAoeAtPoint(unit, skillData, castTargetX, castTargetY, context)
            elseif targetUnit then
                local result = CombatSystem.resolveAttack(unit, targetUnit, skillData)
                ExecutionSystem.applyAttackResult(result, targetUnit, context, skillData)
            end
        end

        local cdTicks = skillData.cooldown or 20
        unit.cooldowns[skillId] = cdTicks

        if skillData.maxCharges then
            unit.charges[skillId] = (unit.charges[skillId] or 0) - 1
        end

        unit.globalCooldown = cdTicks
    end
end

function ExecutionSystem.applyAttackResult(result, target, context, skillData)
    if result.hit then
        applyOnHitStatuses(target, skillData)

        if context.addFloatingText then
            context.addFloatingText(target.visualX, target.visualY, tostring(result.damage), {1, 0.2, 0.2, 1})
        end
    else
        if result.action == "block" then
            CombatSystem.applyBlockDurabilityLoss(target)
        end

        if context.addFloatingText then
            local missText = result.action and string.upper(result.action) or "MISS"
            context.addFloatingText(target.visualX, target.visualY, missText, {0.8, 0.8, 0.8, 1})
        end
    end
end

function ExecutionSystem._updateProjectiles(context)
    local projectiles = context.data.projectiles
    if not projectiles then return end

    for i = #projectiles, 1, -1 do
        local proj = projectiles[i]
        local tx, ty = proj.targetX, proj.targetY

        local dx = tx - proj.x
        local dy = ty - proj.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist <= proj.speed then
            local skillData = Skills[proj.skillId]

            if skillData and skillData.projectile and skillData.projectile.style == "fireball" and context.addVfx then
                context.addVfx({
                    type = "fire_explosion",
                    x = tx,
                    y = ty,
                    time = 0,
                    duration = 0.45,
                    maxRadius = 44,
                    ringRadius = 12,
                    sparks = {
                        {vx = 120, vy = -80, life = 0.35, size = 4},
                        {vx = -110, vy = -60, life = 0.32, size = 4},
                        {vx = 90, vy = 40, life = 0.28, size = 3},
                        {vx = -95, vy = 50, life = 0.30, size = 3},
                        {vx = 0, vy = -130, life = 0.36, size = 5},
                        {vx = 35, vy = -105, life = 0.34, size = 4},
                        {vx = -45, vy = -95, life = 0.34, size = 4}
                    },
                    smoke = {
                        {vx = -22, vy = -28, life = 0.55, size = 12},
                        {vx = 18, vy = -34, life = 0.62, size = 14},
                        {vx = 0, vy = -38, life = 0.68, size = 16},
                        {vx = 30, vy = -24, life = 0.50, size = 11}
                    }
                })
            end

            if skillData and skillData.type == "aoe" and skillData.targeted == true then
                ExecutionSystem._resolveAoeAtPoint(proj.attackerUnit, skillData, tx, ty, context)
            else
                local selectedTarget = nil
                if proj.targetUnitId and context.data.units then
                    local intendedTarget = context.data.units[proj.targetUnitId]
                    if intendedTarget and intendedTarget.hp > 0 and intendedTarget.team ~= proj.attackerUnit.team then
                        selectedTarget = intendedTarget
                    end
                end

                if not selectedTarget then
                    local bestDistSq = nil
                    local impactRadius = 26

                    for _, targetUnit in ipairs(context.data.unitList) do
                        if targetUnit.team ~= proj.attackerUnit.team and targetUnit.hp > 0 then
                            local udx = targetUnit.x - tx
                            local udy = targetUnit.y - ty
                            local d2 = udx * udx + udy * udy
                            local reach = impactRadius + (targetUnit.collisionRadius or 0)
                            if d2 <= (reach * reach) and (not bestDistSq or d2 < bestDistSq) then
                                bestDistSq = d2
                                selectedTarget = targetUnit
                            end
                        end
                    end
                end

                if selectedTarget then
                    local impactSkill = Skills[proj.skillId]
                    local result = CombatSystem.resolveProjectileAttack(proj.attackerUnit, selectedTarget, impactSkill)
                    ExecutionSystem.applyAttackResult(result, selectedTarget, context, impactSkill)
                end
            end

            table.remove(projectiles, i)
        else
            local moveX = (dx / dist) * proj.speed
            local moveY = (dy / dist) * proj.speed
            proj.x = proj.x + moveX
            proj.y = proj.y + moveY

            local skillData = Skills[proj.skillId]
            if skillData and skillData.projectile and skillData.projectile.style == "fireball" and proj.trailParticles then
                proj.trailSpawnTimer = (proj.trailSpawnTimer or 0) + 1
                if proj.trailSpawnTimer >= 1 then
                    proj.trailSpawnTimer = 0
                    table.insert(proj.trailParticles, {
                        kind = "ember",
                        x = proj.x + (math.random() - 0.5) * 6,
                        y = proj.y + (math.random() - 0.5) * 6,
                        vx = (math.random() - 0.5) * 10,
                        vy = -20 - math.random() * 35,
                        life = 0.24 + math.random() * 0.16,
                        duration = 0.24 + math.random() * 0.16,
                        size = 3 + math.random() * 3
                    })
                    table.insert(proj.trailParticles, {
                        kind = "smoke",
                        x = proj.x + (math.random() - 0.5) * 8,
                        y = proj.y + (math.random() - 0.5) * 8,
                        vx = (math.random() - 0.5) * 7,
                        vy = -10 - math.random() * 12,
                        life = 0.35 + math.random() * 0.3,
                        duration = 0.35 + math.random() * 0.3,
                        size = 5 + math.random() * 5
                    })
                end
            end

            local totalDist = math.sqrt((tx - proj.startX) ^ 2 + (ty - proj.startY) ^ 2)
            if totalDist > 0 then
                proj.progress = 1.0 - (dist / totalDist)
            end
        end
    end
end

return ExecutionSystem
