local S = require("src.core.schema")
---@class NamePoolDefinition
---@field id string
---@field pools table<string, string[]>
---@type {new: fun(value: NamePoolDefinition): NamePoolDefinition, validate: fun(value: NamePoolDefinition), is: fun(value: any): boolean}
local Pool = S.define("NamePoolDefinition", {id = S.string, pools = S.map(S.array(S.string))})
return Pool
