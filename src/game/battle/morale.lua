-- Battle-local morale and FIFO cascades; no campaign actor is mutated here.
local CombatPower = require("src.game.combat_power")
local Morale = {
    initial = 100, proximity = 180, escapeTicks = 600,
    resistanceBaseline = 10, minimumResistance = 5, flightThreshold = 50,
    damageScale = 100, sizeScale = 0.25, minimumSizeImpact = 0.5, maximumSizeImpact = 2,
    ownDefeat = -12, alliedDefeat = -4, ownFlee = -2, alliedFlee = 0,
    enemyDefeat = 8, enemyFlee = 5, partyFactor = 0.5,
    widespreadMinimum = 2, widespreadFraction = 0.5
}

function Morale.probability(value)
    return value < Morale.flightThreshold and (1 - math.max(0, value) / Morale.flightThreshold)^3 or 0
end

function Morale.sizeImpact(eventActor, observer)
    local a = (eventActor.actor or eventActor).size or 3
    local b = (observer.actor or observer).size or 3
    return math.max(Morale.minimumSizeImpact, math.min(Morale.maximumSizeImpact, 1 + Morale.sizeScale * (a - b)))
end

function Morale.eligible(unit)
    return unit.hp > 0 and not unit.fleeing and not unit.escaped and not unit.moraleExempt
end

function Morale.average(members)
    local total, count = 0, 0
    for _, unit in ipairs(members) do
        if Morale.eligible(unit) then total, count = total + unit.battleMorale, count + 1 end
    end
    return count > 0 and total / count or 100, count
end

local function roll(context, probability)
    if probability <= 0 then return false end
    local value = (context.data.moraleRng or math.random)()
    return probability >= 1 or value < probability
end

local function enqueue(context, event, root)
    local data = context.data
    data.moraleQueue = data.moraleQueue or {}
    event.root = root or {partyChecks = {}, flights = {}}
    data.moraleQueue[#data.moraleQueue + 1] = event
end

function Morale.powers(context)
    local powers = {player = 0, enemy = 0}
    for _, unit in ipairs(context.data.unitList) do
        powers[unit.team] = (powers[unit.team] or 0) + CombatPower.unit(unit)
    end
    return powers
end

function Morale.threat(powers, team)
    local friendly, enemy = powers[team] or 0, 0
    for side, power in pairs(powers) do if side ~= team then enemy = enemy + power end end
    if enemy == 0 then return 1 end
    if friendly == 0 then return math.huge end
    return math.max(1, enemy / friendly)
end

function Morale.flee(context, unit, root)
    if not Morale.eligible(unit) then return false end
    local powers = Morale.powers(context)
    unit.fleeing, unit.fleeTick = true, context.data.tick
    unit.intent, unit.currentCast, unit.regrouping = nil, nil, nil
    enqueue(context, {kind = "flee", unit = unit, powers = powers}, root)
    return true
end

function Morale.change(context, unit, change, root)
    if unit.hp <= 0 or unit.escaped or unit.moraleExempt then return false end
    if change < 0 then change = change * Morale.resistanceBaseline / math.max(Morale.minimumResistance, unit.stats.morale or Morale.resistanceBaseline) end
    unit.battleMorale = math.max(0, math.min(100, unit.battleMorale + change))
    if change < 0 and Morale.eligible(unit) and roll(context, Morale.probability(unit.battleMorale)) then
        return Morale.flee(context, unit, root)
    end
    return false
end

function Morale.damage(context, unit, hpLost, powers)
    if hpLost > 0 then enqueue(context, {kind = "damage", unit = unit, hpLost = hpLost,
        powers = powers or Morale.powers(context)}) end
    Morale.defeat(context, unit, powers)
end

function Morale.defeat(context, unit, powers)
    if unit.hp <= 0 and not unit.moraleDefeatReported then
        unit.moraleDefeatReported = true
        enqueue(context, {kind = "defeat", unit = unit, powers = powers or Morale.powers(context)})
    end
end

local function partyCheck(context, team, root)
    local party = context.data.battleParties[team]
    if not party or party.routed or root.partyChecks[team] then return end
    root.partyChecks[team] = true
    local average, count = Morale.average(party.members)
    if count == 0 or roll(context, Morale.partyFactor * Morale.probability(average)) then
        party.routed = true
        for _, member in ipairs(party.members) do Morale.flee(context, member, root) end
    end
end

function Morale.process(context)
    local data = context.data
    if data.processingMorale then return end
    data.processingMorale = true
    local queue = data.moraleQueue or {}
    -- Each actor can emit only one defeat and one fleeing transition per battle.
    local bound = #queue + 2 * (#data.unitList + #data.casualties) + 1
    local index = 1
    while index <= #queue do
        assert(index <= bound, "Morale cascade exceeded its transition bound")
        local event = queue[index]
        local unit, root = event.unit, event.root
        if event.kind == "damage" then
            Morale.change(context, unit, -Morale.damageScale * (event.hpLost / unit.maxHp)^2 *
                Morale.threat(event.powers, unit.team), root)
        else
            local defeat = event.kind == "defeat"
            for _, observer in ipairs(data.unitList) do
                local distanceSq = (observer.x-unit.x)^2 + (observer.y-unit.y)^2
                if observer ~= unit and observer.hp > 0 and
                    distanceSq <= Morale.proximity^2 then
                    local change
                    if observer.team ~= unit.team then
                        change = defeat and Morale.enemyDefeat or Morale.enemyFlee
                    elseif observer.squad and observer.squad == unit.squad then
                        change = defeat and Morale.ownDefeat or Morale.ownFlee
                    else
                        change = defeat and Morale.alliedDefeat or Morale.alliedFlee
                    end
                    if change < 0 and not defeat then
                        change = change * math.max(0, 1 - math.sqrt(distanceSq) / Morale.proximity)
                    end
                    if change < 0 then change = change * Morale.threat(event.powers, observer.team) end
                    Morale.change(context, observer, change * Morale.sizeImpact(unit, observer), root)
                end
            end
            local squad = unit.squad
            if squad and not squad.routed then
                local average, count = Morale.average(squad.members)
                if count == 0 or roll(context, Morale.probability(average)) then
                    squad.routed = true
                    for _, member in ipairs(squad.members) do Morale.flee(context, member, root) end
                    partyCheck(context, unit.team, root)
                end
            end
            local party = data.battleParties[unit.team]
            if party then
                if defeat and party.leader == unit then partyCheck(context, unit.team, root) end
                local _, eligible = Morale.average(party.members)
                if eligible == 0 then party.routed = true end
                if not defeat then
                    root.flights[unit.team] = (root.flights[unit.team] or 0) + 1
                    local total = 0
                    for _, member in ipairs(party.members) do
                        if member.hp > 0 and not member.moraleExempt then total = total + 1 end
                    end
                    if root.flights[unit.team] >= math.max(Morale.widespreadMinimum,
                        math.ceil(total * Morale.widespreadFraction)) then partyCheck(context, unit.team, root) end
                end
            end
        end
        index = index + 1
    end
    data.moraleQueue, data.processingMorale = {}, nil
end

function Morale.updateEscapes(context)
    local data = context.data
    for i = #data.unitList, 1, -1 do
        local unit = data.unitList[i]
        local party = data.battleParties[unit.team]
        local canEscape = unit.fleeing or (unit.moraleExempt and party and party.routed)
        local edge = unit.escapeEdge or (unit.team == "player" and 0 or data.bounds.width)
        local reached = math.abs(unit.x - edge) <= (unit.collisionRadius or 0) + 0.01
        local trapped = unit.fleeing and data.tick - unit.fleeTick >= Morale.escapeTicks
        if unit.hp > 0 and canEscape and (reached or trapped) then
            unit.escaped, unit.escapeResolution = true, trapped and not reached and "bounded" or "edge"
            unit.intent, unit.currentCast = nil, nil
            data.escaped[#data.escaped + 1] = unit
            data.units[unit.id] = nil
            table.remove(data.unitList, i)
            unit:destroy()
        end
    end
end

return Morale
