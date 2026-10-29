local Catalog = require("src.data.statuses")
local Conditions = {}

function Conditions.active(entry)
    return type(entry) == "table" and (entry.lifetime == "permanent" or entry.remaining == nil or entry.remaining > 0)
end

function Conditions.definition(id, overrides)
    local result = {}
    for key, value in pairs(Catalog[id] or {}) do result[key] = value end
    if type(overrides) == "number" then result.duration = overrides
    elseif type(overrides) == "table" then
        for key, value in pairs(overrides) do result[key] = value end
        result.duration = overrides.duration or overrides.remaining or overrides.ticks or result.duration
        result.damagePerTick = overrides.damagePerTick or overrides.damage_per_tick or result.damagePerTick
        result.tickEvery = overrides.tickEvery or overrides.tick_every or result.tickEvery
    end
    if overrides == true and result.duration == nil and not result.battleLong then result.duration = 60 end
    result.lifetime = result.lifetime or "battle-only"
    if result.lifetime == "battle-long" then result.lifetime, result.battleLong = "battle-only", true end
    assert(result.lifetime == "battle-only" or result.lifetime == "persistent" or result.lifetime == "permanent", "Invalid condition lifetime")
    result.policy = result.policy or "refresh"
    assert(result.policy == "refresh" or result.policy == "stack" or result.policy == "replace", "Invalid condition policy")
    return result
end

-- Injuries retain their stable list identity and catalog-owned recovery rules.
function Conditions.get(actor, id, bodyPart)
    if bodyPart then
        for _, entry in ipairs(actor.injuries or {}) do
            if entry.id == id and entry.bodyPart == bodyPart then return entry end
        end
    else
        local entry = (actor.statusEffects or {})[id]
        if Conditions.active(entry) then return entry end
    end
end

function Conditions.remove(actor, id, bodyPart)
    if bodyPart then
        for index, entry in ipairs(actor.injuries or {}) do
            if entry.id == id and entry.bodyPart == bodyPart then table.remove(actor.injuries, index); return true end
        end
    elseif (actor.statusEffects or {})[id] then actor.statusEffects[id] = nil; return true end
    return false
end

function Conditions.insertInjury(actor, entry)
    actor.injuries = actor.injuries or {}
    actor.injuries[#actor.injuries + 1] = {id = entry.id, bodyPart = entry.bodyPart}
end

function Conditions.metadata(actor, id, bodyPart)
    local entry = Conditions.get(actor, id, bodyPart)
    if not entry then return nil end
    if bodyPart then
        local definition = require("src.systems.actors.injury_system").definition(actor,entry)
        return {lifetime="persistent", durationUnit="injury-recovery", category="injury", dispellable=definition and definition.dispellable == true}
    end
    return Conditions.definition(id, entry)
end

function Conditions.apply(actor, id, overrides, sourceSkillId)
    if overrides == false then return nil end
    if type(overrides) == "table" and overrides.bodyPart then
        return require("src.systems.actors.injury_system").apply(actor, {id = id, bodyPart = overrides.bodyPart})
    end
    local entry = Conditions.definition(id, overrides)
    if entry.lifetime ~= "permanent" and (entry.duration or 0) <= 0 and not entry.decayEvery and not entry.battleLong then return nil end
    local old = Conditions.get(actor, id)
    entry.remaining = entry.lifetime ~= "permanent" and entry.duration or nil
    entry.durationUnit = entry.durationUnit or "battle-ticks"
    entry.sourceSkillId, entry.tickCounter, entry.stacks = sourceSkillId, 0, 1
    if old and entry.policy ~= "replace" then
        entry.tickCounter = old.tickCounter or 0
        entry.decayCounter = old.decayCounter or 0
        entry.triggerCounts = old.triggerCounts
        entry.stacks = entry.policy == "stack" and math.min((old.stacks or 1) + 1, entry.maxStacks or math.huge) or (old.stacks or 1)
    end
    if (entry.damagePerTick or 0) > 0 and (entry.tickEvery or 0) < 1 then entry.tickEvery = 20 end
    actor.statusEffects = actor.statusEffects or {}
    actor.statusEffects[id] = entry
    if not Conditions.permits(actor, "cast") then actor.currentCast = nil end
    return entry
end

function Conditions.permits(actor, action)
    for id, entry in pairs(actor.statusEffects or {}) do
        if Conditions.active(entry) then
            local definition = Conditions.definition(id, entry)
            if definition.canAct == false or (definition.blocks or {})[action] then return false end
        end
    end
    return true
end

function Conditions.finitePeriodic(entry, id)
    local definition = Conditions.definition(id, entry)
    return Conditions.active(entry) and definition.lifetime ~= "permanent" and
        type(entry.remaining) == "number" and entry.remaining < math.huge and
        ((definition.damagePerTick or 0) > 0 or (definition.healingPerTick or 0) > 0)
end

function Conditions.persistentStatuses(actor)
    local result = {}
    for id, entry in pairs(actor.statusEffects or {}) do
        local lifetime = entry.lifetime or (Catalog[id] or {}).lifetime or "battle-only"
        if Conditions.active(entry) and lifetime ~= "battle-only" then
            result[id] = require("src.systems.items.inventory_system").deepClone(entry)
        end
    end
    return result
end

function Conditions.entries(actor)
    local entries = {}
    for id, entry in pairs(actor.statusEffects or {}) do
        if Conditions.active(entry) then
            entries[#entries+1] = {id=id, entry=entry, definition=Conditions.definition(id, entry)}
        end
    end
    table.sort(entries, function(a,b) return a.id < b.id end)
    return entries
end

-- Ordinary removal remains available to treatment; magical removal checks eligibility.
function Conditions.cleanse(actor, filter)
    local removed = 0
    local function matches(id, definition, injury)
        local categories = definition.categories or {}
        local category = filter.category
        return definition.dispellable ~= false and (not injury or definition.dispellable == true) and
            (not filter.id or filter.id == id) and
            (not category or definition.category == category or categories[category] or (injury and category == "injury"))
    end
    for _, item in ipairs(Conditions.entries(actor)) do
        if matches(item.id, item.definition, false) then Conditions.remove(actor,item.id); removed=removed+1 end
    end
    local Injury = require("src.systems.actors.injury_system")
    for index = #(actor.injuries or {}), 1, -1 do
        local entry = actor.injuries[index]
        local definition = Injury.definition(actor,entry)
        if definition and matches(entry.id,definition,true) then
            Conditions.remove(actor,entry.id,entry.bodyPart); removed=removed+1
        end
    end
    return removed
end

-- Snapshot one eligible reaction per condition/event; expiration follows that reaction.
function Conditions.trigger(actor, event, delivery, rng, react)
    for _, item in ipairs(Conditions.entries(actor)) do
        local definition, entry = item.definition, item.entry
        local reaction = (definition.reactions or {})[event]
        if reaction and (not reaction.meleeOnly or delivery == "melee") and
            (reaction.chance == nil or rng() < reaction.chance) then react(reaction) end
        local expires = definition.expiresOn
        if expires and expires.event == event and (not expires.meleeOnly or delivery == "melee") then
            entry.triggerCounts = entry.triggerCounts or {}
            entry.triggerCounts[event] = (entry.triggerCounts[event] or 0)+1
            if (expires.triggers and entry.triggerCounts[event] >= expires.triggers) or
                (expires.chance and rng() < expires.chance) then Conditions.remove(actor,item.id) end
        end
    end
end

function Conditions.damageLimits(actor, direction)
    local minimum, maximum = 0, math.huge
    for _, item in ipairs(Conditions.entries(actor)) do
        local effects = item.definition.effects or {}
        minimum = math.max(minimum, effects[direction.."DamageMin"] or 0)
        maximum = math.min(maximum, effects[direction.."DamageMax"] or math.huge)
    end
    return minimum, maximum
end

function Conditions.effects(actor, injuriesOnly)
    local result = {attack = 0, defense = 0, movementSpeedMultiplier = 1, sightMultiplier = 1}
    local function add(effects, stacks)
        for key, value in pairs(effects or {}) do
            if type(value) == "number" then
                if key:find("Multiplier$") then result[key] = (result[key] or 1) * value ^ stacks
                else result[key] = (result[key] or 0) + value * stacks end
            end
        end
    end
    local Injury = require("src.systems.actors.injury_system")
    local seen = {}
    for _, entry in ipairs(actor.injuries or {}) do
        local definition = Injury.definition(actor, entry)
        if definition and not seen[entry.bodyPart] then seen[entry.bodyPart] = true; add(definition.effects, 1) end
    end
    result.movementSpeedMultiplier = math.max(0.2, result.movementSpeedMultiplier)
    result.sightMultiplier = math.max(0.2, result.sightMultiplier)
    if not injuriesOnly then
        for _, item in ipairs(Conditions.entries(actor)) do
            add(item.definition.effects, item.entry.stacks or 1)
        end
    end
    return result
end

function Conditions.modify(actor, stat, base)
    local effects = Conditions.effects(actor)
    local multiplier = (stat == "speed" or stat == "battle_speed") and effects.movementSpeedMultiplier
        or stat == "sight" and effects.sightMultiplier or effects[stat .. "Multiplier"] or 1
    local value = (base + (effects[stat] or 0)) * multiplier
    if stat:match("^protection_") then return value end
    return math.max(stat == "defense" and 1 or 0, value)
end
return Conditions
