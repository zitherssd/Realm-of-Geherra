local S = require("src.core.schema")
---@class LocationActionCooldown
---@field key string
---@field days integer
---@class LocationAction
---@field label string
---@field action string
---@field cooldown? LocationActionCooldown
local Cooldown = S.define("LocationActionCooldown", {
    key = S.string,
    days = S.integer,
})
---@type {new: fun(value: LocationAction): LocationAction, validate: fun(value: LocationAction), is: fun(value: any): boolean}
local Action = S.define("LocationAction", {
    label = S.string,
    action = S.string,
    cooldown = S.optional(Cooldown.validate),
})
return Action
