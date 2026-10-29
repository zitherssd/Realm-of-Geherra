local Conditions = require("src.systems.actors.conditions")
local Data = require("src.data.injuries")
local Injury = {}
local rank = {minor = 1, major = 2}

function Injury.interpolate(curve, fraction)
    if type(fraction) ~= "number" or fraction ~= fraction or fraction <= 0 then return 0 end
    for index = 2, #curve do
        local left, right = curve[index - 1], curve[index]
        if fraction <= right[1] then
            return math.max(0, math.min(1, left[2] + (right[2] - left[2])
                * (fraction - left[1]) / (right[1] - left[1])))
        end
    end
    return math.max(0, math.min(1, curve[#curve][2]))
end

function Injury.profile(actor)
    local profile = actor and Data.profiles[actor.injuryProfile]
    if type(profile) == "table" and type(profile.bodyParts) == "table" then return profile end
end

function Injury.definition(actor, entry)
    if type(entry) ~= "table" then return nil end
    local definition = Data.definitions[entry.id]
    if not definition then return nil end
    local profile = Injury.profile(actor)
    for _, part in ipairs(profile and profile.bodyParts or {}) do
        if type(part) == "table" and part.id == entry.bodyPart and part.category == definition.category then return definition end
    end
end

-- Persistent entries contain only stable IDs; severity always comes from the catalog.
function Injury.validate(actor, entries)
    assert(type(entries) == "table", "Injuries must be a list")
    local count, seen = 0, {}
    for key, entry in pairs(entries) do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1, "Injuries must be a list")
        assert(Injury.definition(actor, entry), "Unknown or incompatible injury")
        assert(not seen[entry.bodyPart], "Duplicate injured body part")
        seen[entry.bodyPart], count = true, count + 1
    end
    assert(count == #entries, "Injuries must be contiguous")
    return true
end

function Injury.apply(actor, entry)
    local definition = Injury.definition(actor, entry)
    if not definition then return false end
    actor.injuries = actor.injuries or {}
    for index, old in ipairs(actor.injuries) do
        if old.bodyPart == entry.bodyPart then
            local previous = Injury.definition(actor, old)
            if previous and rank[previous.severity] >= rank[definition.severity] then return false end
            Conditions.remove(actor, old.id, old.bodyPart)
            Conditions.insertInjury(actor, entry)
            return true
        end
    end
    Conditions.insertInjury(actor, entry)
    return true
end

local function weighted(entries, rng)
    local total = 0
    for _, entry in ipairs(entries) do total = total + entry.weight end
    local roll = rng() * total
    for _, entry in ipairs(entries) do
        roll = roll - entry.weight
        if roll < 0 then return entry end
    end
    return entries[#entries]
end

function Injury.fromDamage(unit, actualDamage, rng)
    local maximum = unit.maxHp
    if unit.hp <= 0 or type(actualDamage) ~= "number" or actualDamage ~= actualDamage
        or actualDamage <= 0 or actualDamage == math.huge or type(maximum) ~= "number"
        or maximum ~= maximum or maximum <= 0 or maximum == math.huge then return false end
    local profile = Injury.profile(unit)
    if not Data.validProfile(profile) then return false end
    rng = rng or math.random
    local fraction = actualDamage / maximum
    if rng() >= Injury.interpolate(Data.occurrenceCurve, fraction) then return false end
    local severity = rng() < Injury.interpolate(Data.majorCurve, fraction) and "major" or "minor"
    local part = weighted(profile.bodyParts, rng)
    local definition = weighted(Data.candidates(part.category, severity), rng)
    return Injury.apply(unit, {id = definition.id, bodyPart = part.id})
end

function Injury.effects(actor)
    return Conditions.effects(actor, true)
end

function Injury.stat(actor, stat, base)
    return Conditions.modify(actor, stat, base)
end

function Injury.importance(actor)
    local total, seen = 0, {}
    for _, entry in ipairs(actor.injuries or {}) do
        local definition = Injury.definition(actor, entry)
        if definition and not seen[entry.bodyPart] then
            seen[entry.bodyPart] = true
            total = total + Data.recoveryImportance[definition.severity]
        end
    end
    return math.min(100, total)
end

function Injury.lines(actor)
    local lines = {}
    for _, entry in ipairs(actor.injuries or {}) do
        local definition = Injury.definition(actor, entry)
        if definition then
            local penalties = {}
            for _, effect in ipairs({"attack", "defense", "movementSpeedMultiplier", "sightMultiplier"}) do
                local value = definition.effects[effect]
                if value then
                    local label = ({attack = "Attack", defense = "Defense",
                        movementSpeedMultiplier = "Movement", sightMultiplier = "Sight"})[effect]
                    penalties[#penalties + 1] = label .. (effect:find("Multiplier")
                        and string.format(" -%g%%", (1 - value) * 100) or string.format(" %g", value))
                end
            end
            lines[#lines + 1] = definition.name .. " (" .. definition.severity .. ", "
                .. entry.bodyPart:gsub("_", " ") .. "): " .. table.concat(penalties, ", ")
        end
    end
    if #lines == 0 then lines[1] = "Injuries: none" end
    return lines
end
return Injury
