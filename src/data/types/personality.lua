local S = require("src.core.schema")
local Personality = {
    traits = {
        "homesickness",
        "responsibility",
        "greed",
    },
}

local function trait(value, path)
    if type(value) == "number" then
        S.probability(value, path)
        return
    end
    S.array(S.probability)(value, path)
    assert(#value == 2 and value[1] <= value[2], path .. ": expected ordered min/max pair")
end
local fields = {}
for _, name in ipairs(Personality.traits) do
    fields[name] = S.optional(trait)
end
Personality.validate = S.define("Personality", fields).validate

function Personality.get(actor, name)
    local value = actor.personality and actor.personality[name]
    if value == nil and name == "responsibility" then
        value = actor.responsibility
    end
    if type(value) ~= "number" or value ~= value then
        return 0.5
    end
    return math.max(0, math.min(1, value))
end

-- Normalize old actors once; existing rolled traits always win over legacy fields.
function Personality.normalize(actor)
    local values = {}
    for _, name in ipairs(Personality.traits) do
        values[name] = Personality.get(actor, name)
    end
    actor.personality, actor.responsibility = values, nil
    return values
end

function Personality.roll(definition, rng)
    local result = {}
    for _, name in ipairs(Personality.traits) do
        local value = (definition or {})[name]
        if type(value) == "table" then
            value = value[1] + rng() * (value[2] - value[1])
        end
        result[name] = value == nil and 0.5 or value
    end
    return result
end
return Personality
