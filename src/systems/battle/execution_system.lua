local Projectile = require("src.game.battle.projectiles")
-- systems/battle/execution_system.lua
-- Resolves intents, updates positions, and applies damage in world space.

local Concord = require("src.libs.concord")
local Statuses = require("src.data.statuses")
local RangeUtils = require("src.systems.battle.range_utils")
local CombatSystem = require("src.systems.battle.combat_system")
local Morale = require("src.game.battle.morale")
local Injury = require("src.systems.actors.injury_system")

local ExecutionSystem = Concord.system({pool = {"battleUnit"}})

local WORLD_RANGE_SCALE = 42
-- Provisional M1 calibration; displacement is local, never propagated to neighbors.
local MOVEMENT = {substep = 2, displacementSizeGap = 1, yieldPerMove = 18, allySqueeze = 0.8}
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

local function applyOnHitStatuses(targetUnit, skillData)
    if not targetUnit or not skillData or not skillData.onHitStatuses then return end

    targetUnit.statusEffects = targetUnit.statusEffects or {}
    for statusId, statusConfig in pairs(skillData.onHitStatuses) do
        if type(statusId) == "number" then
            statusId = statusConfig
            statusConfig = Statuses[statusId]
        end
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

-- shortcut: allies retain up to 20% compression at rest; add recovery if playtests need wider ranks.
local function contactDistance(a, b)
    local distance = (a.collisionRadius or 0) + (b.collisionRadius or 0)
    return a.team == b.team and distance * MOVEMENT.allySqueeze or distance
end

local function canOccupy(unit, context, ignore)
    for _, other in ipairs(context.data.unitList) do
        if other ~= unit and other ~= ignore and other.hp > 0 and not other.escaped then
            local dx, dy = unit.x - other.x, unit.y - other.y
            local reach = contactDistance(unit, other)
            if dx * dx + dy * dy < reach * reach - MIN_DIST_EPSILON then return false, other end
        end
    end
    return true
end

local function blocksSegment(unit, other, x, y)
    local dx,dy = x-unit.x,y-unit.y
    local lengthSq = dx*dx+dy*dy
    local t = lengthSq > 0 and math.max(0,math.min(1,
        ((other.x-unit.x)*dx+(other.y-unit.y)*dy)/lengthSq)) or 0
    local ox,oy = unit.x+t*dx-other.x,unit.y+t*dy-other.y
    return ox*ox+oy*oy < contactDistance(unit,other)^2-MIN_DIST_EPSILON
end

local function clearPosition(unit, context, x, y)
    local width,height = getBounds(context)
    local r = unit.collisionRadius or 0
    if x < r or y < r or x > width-r or y > height-r then return false end
    for _, other in ipairs(context.data.unitList) do
        if other ~= unit and other.hp > 0 and not other.escaped and
            (x-other.x)^2+(y-other.y)^2 < contactDistance(unit,other)^2-MIN_DIST_EPSILON then return false end
    end
    return true
end

local function clearStep(unit, context, x, y)
    if not clearPosition(unit,context,x,y) then return false end
    for _, other in ipairs(context.data.unitList) do
        if other ~= unit and other.hp > 0 and not other.escaped and blocksSegment(unit,other,x,y) then return false end
    end
    return true
end

local function slideStep(unit, blocker, nx, ny, distance, context)
    local rx,ry = unit.x-blocker.x,unit.y-blocker.y
    local radius = math.sqrt(rx*rx+ry*ry)
    if radius < MIN_DIST_EPSILON then return false end
    rx,ry = rx/radius,ry/radius
    local bestX,bestY,bestSide,bestScore
    for _, side in ipairs({1,-1}) do
        local tx,ty = -ry*side,rx*side
        local x,y = unit.x+tx*distance,unit.y+ty*distance
        if clearStep(unit,context,x,y) then
            local score = tx*nx+ty*ny
            if clearStep(unit,context,x+tx*distance,y+ty*distance) then score=score+0.1 end
            if unit.slideBlocker==blocker and unit.slideSide==side then score=score+0.25 end
            if not bestScore or score>bestScore then bestX,bestY,bestSide,bestScore=x,y,side,score end
        end
    end
    if not bestX then return false end
    unit.x,unit.y = bestX,bestY
    unit.slideBlocker,unit.slideSide = blocker,bestSide
    return true
end

local function moveWithCollisions(unit, nx, ny, distance, context)
    local yielded, traveled = {}, 0
    local steps = math.ceil(distance / MOVEMENT.substep)
    for _ = 1, steps do
        local oldX, oldY = unit.x, unit.y
        unit.x, unit.y = oldX + nx * distance / steps, oldY + ny * distance / steps
        clampUnitToBounds(unit, context)
        local changes = {}
        for _, other in ipairs(context.data.unitList) do
            if other ~= unit and other.hp > 0 and not other.escaped then
                local dx, dy = other.x - unit.x, other.y - unit.y
                local reach = contactDistance(unit, other)
                if dx * dx + dy * dy < reach * reach - MIN_DIST_EPSILON then
                    local size = (unit.actor and unit.actor.size) or 3
                    local otherSize = (other.actor and other.actor.size) or 3
                    local larger = size >= otherSize + MOVEMENT.displacementSizeGap
                    local canYield = larger or (unit.team == other.team and
                        size <= otherSize + MOVEMENT.displacementSizeGap)
                    if canYield then
                        local x, y = other.x, other.y
                        -- Yield sideways to let a walker pass, with a deterministic tie break.
                        local side = dx * -ny + dy * nx >= 0 and 1 or -1
                        local lateral = dx * -ny + dy * nx
                        local forward = dx * nx + dy * ny
                        local shift = math.sqrt(math.max(0, reach * reach - forward * forward)) - math.abs(lateral)
                        shift = math.min(shift + 0.001, MOVEMENT.yieldPerMove - (yielded[other] or 0))
                        other.x, other.y = x - ny * side * shift, y + nx * side * shift
                        clampUnitToBounds(other, context)
                        if canOccupy(other, context, unit) then
                            changes[#changes + 1] = {unit = other, x = x, y = y, shift = shift}
                        else
                            other.x, other.y = x, y
                        end
                    end
                end
            end
        end
        local clear, blocker = canOccupy(unit, context)
        if not clear then
            unit.x, unit.y = oldX, oldY
            for _, change in ipairs(changes) do change.unit.x, change.unit.y = change.x, change.y end
            changes = {}
            if blocker.team ~= unit.team or not slideStep(unit,blocker,nx,ny,distance/steps,context) then
                return blocker,traveled
            end
        end
        traveled = traveled+math.sqrt((unit.x-oldX)^2+(unit.y-oldY)^2)
        for _, change in ipairs(changes) do
            yielded[change.unit] = (yielded[change.unit] or 0) + change.shift
        end
    end
    return nil,traveled
end

local function bypassDirection(unit, context, bypass, distance, targetX, targetY)
    local blocker = bypass.blocker
    local rx,ry = unit.x-blocker.x,unit.y-blocker.y
    local radius = math.sqrt(rx*rx+ry*ry)
    if radius < MIN_DIST_EPSILON then return end
    rx,ry = rx/radius,ry/radius
    local bestX,bestY,bestSide,bestScore
    local sides = bypass.side and {bypass.side} or {1,-1}
    for _, side in ipairs(sides) do
        local reach = contactDistance(unit,blocker)+distance+2
        local flankClear = bypass.side or clearPosition(unit,context,
            blocker.x-ry*side*reach,blocker.y+rx*side*reach)
        -- Tangential travel with an outward component can temporarily increase target distance.
        for _, outward in ipairs({0.25,1}) do
            local nx,ny = -ry*side+rx*outward,rx*side+ry*outward
            local length = math.sqrt(nx*nx+ny*ny)
            nx,ny = nx/length,ny/length
            local x,y = unit.x+nx*distance,unit.y+ny*distance
            local score = (x-targetX)^2+(y-targetY)^2
            if flankClear and clearStep(unit,context,x,y) and (not bestScore or score < bestScore) then
                bestX,bestY,bestSide,bestScore = nx,ny,side,score
            end
        end
    end
    bypass.side = bestSide or bypass.side
    return bestX,bestY
end

function ExecutionSystem._resolveAoeAtPoint(attackerUnit, skillData, targetX, targetY, context, excluded, projectileImpact)
    local aoeRadius = math.max(24, ((skillData.aoe or 1) * WORLD_RANGE_SCALE * 0.8))

    for _, targetUnit in ipairs(context.data.unitList) do
        if (projectileImpact or targetUnit.team ~= attackerUnit.team) and targetUnit ~= excluded and targetUnit.hp > 0 and not targetUnit.escaped then
            local dx = targetUnit.x - targetX
            local dy = targetUnit.y - targetY
            local distSq = dx * dx + dy * dy
            local reach = aoeRadius + (targetUnit.collisionRadius or 0)
            if distSq <= (reach * reach) then
                local resolve = projectileImpact and CombatSystem.resolveProjectileAttack or CombatSystem.resolveAttack
                local result = resolve(attackerUnit, targetUnit, skillData)
                ExecutionSystem.applyAttackResult(result, targetUnit, context, skillData)
            end
        end
    end
end

function ExecutionSystem:update(context)
    local units = self.pool

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
                                CombatSystem._applyBattleDamage(unit, dotDamage, true)
                                Morale.process(context)
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
            if unit.hp <= 0 or unit.fleeing or unit.escaped then
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
            if unit.hp > 0 and not unit.escaped then
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

    local previousGoal = unit.moveTarget
    if not intent.avoidObstacles then unit.bypass,unit.stuckAttempts = nil,0 end
    if not previousGoal or previousGoal.x ~= targetX or previousGoal.y ~= targetY then
        -- Retargeting resets the stuck delay, but the same obstacle may still need the active bypass.
        unit.stuckAttempts = 0
    end

    local dx = targetX - unit.x
    local dy = targetY - unit.y
    local distSq = dx * dx + dy * dy
    local dist = math.sqrt(distSq)

    if dist <= MIN_DIST_EPSILON then
        unit.stuckAttempts,unit.bypass = 0,nil
        unit.state = "idle"
        return
    end

    local step = unit.moveStep or 24
    local moveDist = math.min(step, dist)
    local nx = dx / dist
    local ny = dy / dist

    local startX, startY = unit.x, unit.y
    local bypass = unit.bypass
    if bypass and (bypass.blocker.hp <= 0 or bypass.blocker.escaped or not blocksSegment(unit,bypass.blocker,targetX,targetY)) then
        unit.bypass,bypass,unit.stuckAttempts = nil,nil,0
    end
    local blocker,traveled = nil,0
    if not intent.avoidObstacles or not bypass or bypass.remaining <= 0 then
        blocker,traveled = moveWithCollisions(unit,nx,ny,moveDist,context)
    end
    if intent.avoidObstacles and (not bypass or bypass.remaining <= 0) then
        local remainingDistance = math.sqrt((targetX-unit.x)^2+(targetY-unit.y)^2)
        -- Count movement actions with less than one collision substep of progress, never cooldown ticks.
        if dist-remainingDistance >= math.min(MOVEMENT.substep,moveDist)-MIN_DIST_EPSILON then
            unit.stuckAttempts = 0
        elseif not bypass then
            unit.stuckAttempts = (unit.stuckAttempts or 0)+1
        end
    end
    local bypassX,bypassY
    if intent.avoidObstacles and blocker and not bypass and unit.stuckAttempts >= 2 then
        local reach = contactDistance(unit,blocker)
        local candidate = {blocker=blocker,
            remaining=math.min(16,math.ceil(math.pi*reach/step)+4)}
        bypassX,bypassY = bypassDirection(unit,context,candidate,moveDist-traveled,targetX,targetY)
        -- An open flank can move on the second failure; crowded units keep the three-attempt wait.
        if bypassX or unit.stuckAttempts >= 3 then
            bypass,unit.bypass = candidate,candidate
        end
    end
    if intent.avoidObstacles and bypass and bypass.remaining > 0 then
        local remaining = moveDist-traveled
        if not bypassX then bypassX,bypassY = bypassDirection(unit,context,bypass,remaining,targetX,targetY) end
        bypass.remaining = bypass.remaining-1
        if bypassX then moveWithCollisions(unit,bypassX,bypassY,remaining,context) end
    end
    unit.velocityX = unit.x - startX
    unit.velocityY = unit.y - startY
    unit.moveTarget = {x = targetX, y = targetY}
    unit.state = "moving"

    if unit.velocityX > 0 then
        unit.facing = -1
    elseif unit.velocityX < 0 then
        unit.facing = 1
    end

    if not unit.fleeing and unit.squad and unit.squad.order == "hold" then unit.facing = -unit.squad.direction end
    clampUnitToBounds(unit, context)

    local battleSpeed = Injury.stat(unit, "battle_speed", unit.stats.battle_speed or 10)
    local variance = (math.random() - 0.5) * 0.2
    local cooldownTicks = (120 * (1 + variance)) / battleSpeed
    unit.moveCooldown = cooldownTicks
    unit.globalCooldown = cooldownTicks
end

function ExecutionSystem._initiateSkill(unit, intent, context)
    local skillId = intent.skillId
    local skillData = CombatSystem.getEffectiveSkill(unit, skillId)

    if unit.fleeing or unit.escaped or not skillData or not unit.skills[skillId] or (unit.cooldowns[skillId] or 0) > 0 or
        unit.globalCooldown > 0 or unit.currentCast or
        (skillData.maxCharges and (unit.charges[skillId] or 0) <= 0) then return end

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

    if not unit.fleeing and unit.squad and unit.squad.order == "hold" then unit.facing = -unit.squad.direction end

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
    local skillData = CombatSystem.getEffectiveSkill(unit, skillId)
    if not skillData or unit.fleeing or unit.escaped or unit.hp <= 0 then return end

    if skillData.type == "command" then
        if (unit.cooldowns[skillId] or 0) > 0 then return end
        require("src.game.battle.squads").command(context, unit.team, skillData.order)
        unit.cooldowns[skillId], unit.globalCooldown = skillData.cooldown, skillData.recovery
        return
    end
    local targetUnit = context.data.units[targetUnitId]
    local isTargetedAoe = skillData.type == "aoe" and skillData.targeted == true
    local castTargetX = nil
    local castTargetY = nil

    if isTargetedAoe then
        if targetPoint and targetPoint.x and targetPoint.y then
            castTargetX = targetPoint.x
            castTargetY = targetPoint.y
        elseif targetUnit and targetUnit.hp > 0 and not targetUnit.escaped then
            castTargetX = targetUnit.x
            castTargetY = targetUnit.y
        end

        if castTargetX and castTargetY then
            local dx = castTargetX - unit.x
            local dy = castTargetY - unit.y
            local distSq = dx * dx + dy * dy
            local maxRange = RangeUtils.effectiveSkillRange(unit, nil, skillData)
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

        if targetUnit and targetUnit.hp > 0 and not targetUnit.escaped then
            local dx = targetUnit.x - unit.x
            local dy = targetUnit.y - unit.y
            local distSq = dx * dx + dy * dy
            local range = RangeUtils.effectiveSkillRange(unit, targetUnit, skillData)
            if distSq <= (range * range) + 0.01 then
                isValid = true
            end
        end

        if not isValid then
            local fallbackRange = RangeUtils.effectiveSkillRange(unit, nil, skillData)
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
            local proj = Projectile.launch(unit, skillData, castTargetX, castTargetY,
                targetUnit, context.data.projectileRng)
            proj.presentationTarget = targetUnit

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
    Morale.process(context)
    if result.hit then
        applyOnHitStatuses(target, skillData)

        if context.addFloatingText then
            context.addFloatingText(target.visualX, target.visualY, tostring(result.damage), {1, 0.2, 0.2, 1})
        end
    else
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
        local reason, collidedUnit = Projectile.advance(proj, context)
        local tx, ty = proj.x, proj.y

        if reason then
            local skillData = proj.skillData

            if skillData and skillData.projectile and skillData.projectile.style == "fireball" and context.addVfx then
                context.addVfx({
                    type = "fire_explosion",
                    x = tx,
                    y = ty,
                    z = proj.z, projectile = proj, contactUnit = collidedUnit,
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

            if collidedUnit and context.addVfx then
                context.addVfx({type="projectile_contact", x=tx, y=ty, z=proj.z,
                    projectile=proj, contactUnit=collidedUnit, time=0, duration=0.12})
            end
            local result
            if collidedUnit then
                result = CombatSystem.resolveProjectileAttack(proj.attackerUnit, collidedUnit, skillData)
                ExecutionSystem.applyAttackResult(result, collidedUnit, context, skillData)
            end
            if skillData and skillData.type == "aoe" and skillData.targeted and
                (reason == "ground" or (result and result.hit)) then
                ExecutionSystem._resolveAoeAtPoint(proj.attackerUnit, skillData, tx, ty, context, collidedUnit, true)
            end

            table.remove(projectiles, i)
        else
            local skillData = proj.skillData
            if skillData and skillData.projectile and skillData.projectile.style == "fireball" and proj.trailParticles then
                proj.trailSpawnTimer = (proj.trailSpawnTimer or 0) + 1
                if proj.trailSpawnTimer >= 1 then
                    proj.trailSpawnTimer = 0
                    table.insert(proj.trailParticles, {
                        kind = "ember",
                        x = proj.x + (math.random() - 0.5) * 6,
                        y = proj.y - proj.z + (math.random() - 0.5) * 6,
                        vx = (math.random() - 0.5) * 10,
                        vy = -20 - math.random() * 35,
                        life = 0.24 + math.random() * 0.16,
                        duration = 0.24 + math.random() * 0.16,
                        size = 3 + math.random() * 3
                    })
                    table.insert(proj.trailParticles, {
                        kind = "smoke",
                        x = proj.x + (math.random() - 0.5) * 8,
                        y = proj.y - proj.z + (math.random() - 0.5) * 8,
                        vx = (math.random() - 0.5) * 7,
                        vy = -10 - math.random() * 12,
                        life = 0.35 + math.random() * 0.3,
                        duration = 0.35 + math.random() * 0.3,
                        size = 5 + math.random() * 5
                    })
                end
            end

        end
    end
end

return ExecutionSystem
