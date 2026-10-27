local S = require("src.core.schema")
local C = require("src.data.types.common")
local Rules = require("src.data.types.location_rules")
local Action = require("src.data.types.location_action")
---@class LocationPlacement
---@field weight integer
---@field siteSizes ("major"|"minor")[]
---@field biomeWeights? table<string, integer>
---@class LocationDefinition
---@field id string The real location type; no alias to another type.
---@field displayName string
---@field mapMarker string Existing background asset name.
---@field placement LocationPlacement
---@field population Count
---@field prosperity Count
---@field visibility Count
---@field populationProfile string
---@field rules LocationRules
---@field actions LocationAction[]
---@field roadWorthy boolean
---@field hidden boolean
---@field names string[]
local Placement = S.define("LocationPlacement", {weight = S.integer,
    siteSizes = S.array(S.enum({"major", "minor"})), biomeWeights = S.optional(S.map(S.integer))})
---@type {new: fun(value: LocationDefinition): LocationDefinition, validate: fun(value: LocationDefinition), is: fun(value: any): boolean}
local Definition = S.define("LocationDefinition", {
    id = S.string, displayName = S.string, mapMarker = S.string, placement = Placement.validate,
    population = C.count, prosperity = C.count, visibility = C.count, populationProfile = S.string,
    rules = Rules.validate, actions = S.array(Action.validate), roadWorthy = S.boolean,
    hidden = S.boolean, names = S.array(S.string),
})
return Definition
