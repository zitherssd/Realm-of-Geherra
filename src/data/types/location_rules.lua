local S = require("src.core.schema")
---@class LocationRules
---@field caravanStop boolean
---@field recoveryStop boolean
---@field recruitmentPool? string
---@type {new: fun(value: LocationRules): LocationRules, validate: fun(value: LocationRules), is: fun(value: any): boolean}
local Rules = S.define("LocationRules", {
    caravanStop = S.boolean,
    recoveryStop = S.boolean,
    recruitmentPool = S.optional(S.string),
})
return Rules
