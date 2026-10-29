-- Balance data. Profiles use ordered locations so seeded selection is stable.
local Data = {
    occurrenceCurve = {
        { 0, 0 },
        { 0.05, 0.005 },
        { 0.1, 0.01 },
        { 0.2, 0.03 },
        { 0.3, 0.07 },
        { 0.5, 0.2 },
        { 0.75, 0.5 },
    },
    majorCurve = { { 0, 0 }, { 0.3, 0 }, { 0.5, 0.2 }, { 1, 1 } },
    recoveryImportance = { minor = 8, major = 25 },
    definitions = {},
    profiles = {
        humanoid = {
            id = "humanoid",
            bodyParts = {
                { id = "torso", category = "chest", weight = 30 },
                { id = "left_arm", category = "arm", weight = 15 },
                { id = "right_arm", category = "arm", weight = 15 },
                { id = "left_leg", category = "leg", weight = 15 },
                { id = "right_leg", category = "leg", weight = 15 },
                { id = "head", category = "head", weight = 10 },
            },
        },
        quadruped = {
            id = "quadruped",
            bodyParts = {
                { id = "torso", category = "animal_torso", weight = 30 },
                { id = "head", category = "animal_head", weight = 10 },
                { id = "front_left_leg", category = "animal_leg", weight = 15 },
                { id = "front_right_leg", category = "animal_leg", weight = 15 },
                { id = "rear_left_leg", category = "animal_leg", weight = 15 },
                { id = "rear_right_leg", category = "animal_leg", weight = 15 },
            },
        },
        dragon = {
            id = "dragon",
            bodyParts = {
                { id = "head", category = "dragon_head", weight = 10 },
                { id = "torso", category = "dragon_torso", weight = 30 },
                { id = "left_wing", category = "wing", weight = 10 },
                { id = "right_wing", category = "wing", weight = 10 },
                { id = "left_leg", category = "claw", weight = 15 },
                { id = "right_leg", category = "claw", weight = 15 },
                { id = "tail", category = "tail", weight = 10 },
            },
        },
        plant = {
            id = "plant",
            bodyParts = {
                { id = "trunk", category = "trunk", weight = 40 },
                { id = "left_branch", category = "branch", weight = 15 },
                { id = "right_branch", category = "branch", weight = 15 },
                { id = "roots", category = "roots", weight = 30 },
            },
        },
    },
}

local function injury(id, name, severity, category, effects, weight)
    Data.definitions[id] = {
        id = id,
        name = name,
        severity = severity,
        category = category,
        effects = effects,
        weight = weight or 1,
    }
end
injury("bruised_ribs", "Bruised ribs", "minor", "chest", { defense = -1 })
injury("severe_chest_injury", "Severe chest injury", "major", "chest", { defense = -3 })
injury("wounded_arm", "Wounded arm", "minor", "arm", { attack = -1 })
injury("crushed_hand", "Crushed hand", "major", "arm", { attack = -3 })
injury("sprained_ankle", "Sprained ankle", "minor", "leg", { movementSpeedMultiplier = 0.85 })
injury("broken_leg", "Broken leg", "major", "leg", { movementSpeedMultiplier = 0.6 })
injury("concussion", "Concussion", "minor", "head", { sightMultiplier = 0.85 })
injury("facial_wound", "Facial wound", "minor", "head", { attack = -1 }, 0.5)
injury("damaged_eye", "Damaged eye", "major", "head", { attack = -2, sightMultiplier = 0.65 })
injury("torso_wound", "Torso wound", "minor", "animal_torso", { defense = -1 })
injury("severe_torso_wound", "Severe torso wound", "major", "animal_torso", { defense = -3 })
injury("injured_paw", "Injured paw", "minor", "animal_leg", { movementSpeedMultiplier = 0.85 })
injury("fractured_leg", "Fractured leg", "major", "animal_leg", { movementSpeedMultiplier = 0.6 })
injury("bruised_jaw", "Bruised jaw", "minor", "animal_head", { attack = -1 })
injury("damaged_jaw", "Damaged jaw", "major", "animal_head", { attack = -3, sightMultiplier = 0.8 })
injury("bruised_dragon_head", "Bruised head", "minor", "dragon_head", { sightMultiplier = 0.85 })
injury("damaged_dragon_eye", "Damaged eye", "major", "dragon_head", { attack = -2, sightMultiplier = 0.65 })
injury("cracked_scales", "Cracked scales", "minor", "dragon_torso", { defense = -1 })
injury("deep_chest_wound", "Deep chest wound", "major", "dragon_torso", { defense = -3 })
injury("strained_wing", "Strained wing", "minor", "wing", { movementSpeedMultiplier = 0.9 })
injury("torn_wing", "Torn wing", "major", "wing", { movementSpeedMultiplier = 0.7, defense = -1 })
injury("injured_claw", "Injured claw", "minor", "claw", { attack = -1 })
injury("fractured_claw", "Fractured claw", "major", "claw", { attack = -3, movementSpeedMultiplier = 0.85 })
injury("injured_tail", "Injured tail", "minor", "tail", { defense = -1 })
injury("fractured_tail", "Fractured tail", "major", "tail", { defense = -3 })
injury("split_bark", "Split bark", "minor", "trunk", { defense = -1 })
injury("cracked_trunk", "Cracked trunk", "major", "trunk", { defense = -3 })
injury("splintered_limb", "Splintered limb", "minor", "branch", { attack = -1 })
injury("shattered_limb", "Shattered limb", "major", "branch", { attack = -3 })
injury("strained_roots", "Strained roots", "minor", "roots", { movementSpeedMultiplier = 0.85 })
injury("damaged_roots", "Damaged roots", "major", "roots", { movementSpeedMultiplier = 0.6 })

function Data.candidates(category, severity)
    local result = {}
    for _, definition in pairs(Data.definitions) do
        if definition.category == category and definition.severity == severity then
            result[#result + 1] = definition
        end
    end
    table.sort(result, function(a, b)
        return a.id < b.id
    end)
    return result
end

function Data.validProfile(profile)
    if type(profile) ~= "table" or type(profile.bodyParts) ~= "table" or #profile.bodyParts == 0 then
        return false
    end
    local seen = {}
    for _, part in ipairs(profile.bodyParts) do
        if
            type(part) ~= "table"
            or type(part.id) ~= "string"
            or seen[part.id]
            or type(part.weight) ~= "number"
            or part.weight ~= part.weight
            or part.weight <= 0
            or part.weight == math.huge
        then
            return false
        end
        seen[part.id] = true
        for _, severity in ipairs({ "minor", "major" }) do
            if #Data.candidates(part.category, severity) == 0 then
                return false
            end
        end
    end
    return true
end

function Data.validate()
    local Registry = require("src.data.definition_registry")
    for id, definition in pairs(Data.definitions) do
        Registry.checkId("injury", id, definition)
        assert(type(definition.name) == "string" and type(definition.category) == "string")
        assert(Data.recoveryImportance[definition.severity] and type(definition.effects) == "table")
        assert(type(definition.weight) == "number" and definition.weight > 0 and definition.weight < math.huge)
        for effect, value in pairs(definition.effects) do
            assert(
                effect == "attack"
                    or effect == "defense"
                    or effect == "movementSpeedMultiplier"
                    or effect == "sightMultiplier"
            )
            assert(type(value) == "number" and value == value and math.abs(value) < math.huge)
            assert(
                (effect == "attack" or effect == "defense") and value <= 0
                    or (effect == "movementSpeedMultiplier" or effect == "sightMultiplier")
                        and value > 0
                        and value <= 1
            )
        end
    end
    for id, profile in pairs(Data.profiles) do
        Registry.checkId("injury profile", id, profile)
        assert(Data.validProfile(profile), "Invalid injury profile: " .. id)
    end
    return true
end
Data.validate()
return Data
