local S = require("src.core.schema")
---@class CultureDefinition
---@field id string
---@field namePool string
---@field roles table<string, string>
---@type {new: fun(value: CultureDefinition): CultureDefinition, validate: fun(value: CultureDefinition), is: fun(value: any): boolean}
local Culture = S.define("CultureDefinition", {id = S.string, namePool = S.string, roles = S.map(S.string)})
return Culture
