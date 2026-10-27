local S = require("src.core.schema")
local C = require("src.data.types.common")
---@class PopulationConditions
---@field minProsperity? integer
---@field maxProsperity? integer
---@field minPopulation? integer
---@field maxPopulation? integer
---@field culture? string
---@field faction? string
---@field biomes? string[]
---@field tags? string[]
---@class PopulationRule
---@field id string
---@field role? string
---@field archetype? string
---@field count? Count
---@field chance? number
---@field when? PopulationConditions
---@field enabled? boolean
---@field party? string|PartyDefinition|false
local Condition = S.define("PopulationConditions", {
    minProsperity = S.optional(S.integer), maxProsperity = S.optional(S.integer),
    minPopulation = S.optional(S.integer), maxPopulation = S.optional(S.integer),
    culture = S.optional(S.string), faction = S.optional(S.string),
    biomes = S.optional(S.array(S.string)), tags = S.optional(S.array(S.string)),
})
local fields = {id = S.string, role = S.optional(S.string), archetype = S.optional(S.string),
    count = S.optional(C.count), chance = S.optional(S.probability), when = S.optional(Condition.validate),
    enabled = S.optional(S.boolean), party = S.optional(C.party)}
---@type {new: fun(value: PopulationRule): PopulationRule, validate: fun(value: PopulationRule), is: fun(value: any): boolean}
local Rule = S.define("PopulationRule", fields)
Rule.Conditions = Condition
local optionalFields = {}
for key, check in pairs(fields) do optionalFields[key] = S.optional(check) end
Rule.Override = S.define("PopulationOverride", optionalFields)
return Rule
