local S = require("src.core.schema")
local C = require("src.data.types.common")
local Rule = require("src.data.types.population_rule")
---@class GarrisonDefinition
---@field role string
---@field leaderSlot string
---@field count Count
---@field treasury? Count
---@class PopulationProfile
---@field id string
---@field residents PopulationRule[]
---@field garrison? GarrisonDefinition
local Garrison = S.define("GarrisonDefinition", {
    role = S.string,
    leaderSlot = S.string,
    count = C.count,
    treasury = S.optional(C.count),
})
---@type {new: fun(value: PopulationProfile): PopulationProfile, validate: fun(value: PopulationProfile), is: fun(value: any): boolean}
local Profile = S.define("PopulationProfile", {
    id = S.string,
    residents = S.array(Rule.validate),
    garrison = S.optional(Garrison.validate),
})
return Profile
