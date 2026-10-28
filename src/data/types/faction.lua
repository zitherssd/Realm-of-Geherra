local S = require("src.core.schema")
local Rule = require("src.data.types.population_rule")
---@class FactionPopulationDefinition
---@field id string
---@field defaultCulture string
---@field name? string
---@field color? table<string, number>
---@field description? string
---@field garrisonRoles? table<string, string>
---@field residentOverrides? table<string, table<string, PopulationRule>>
---@type {new: fun(value: FactionPopulationDefinition): FactionPopulationDefinition, validate: fun(value: FactionPopulationDefinition), is: fun(value: any): boolean}
local Faction = S.define("FactionPopulationDefinition", {
    id = S.string,
    defaultCulture = S.string,
    name = S.optional(S.string),
    color = S.optional(S.map(S.probability)),
    description = S.optional(S.string),
    garrisonRoles = S.optional(S.map(S.string)),
    residentOverrides = S.optional(S.map(S.map(Rule.Override.validate))),
})
return Faction
