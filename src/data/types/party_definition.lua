local S = require("src.core.schema")
local C = require("src.data.types.common")
local Member = require("src.data.types.party_member")
---@class PartyDefinition
---@field nameSuffix string
---@field placement "stationed"|"world"
---@field treasury? Count
---@field supplies? Count
---@field hostile boolean
---@field members PartyMember[]
---@type {new: fun(value: PartyDefinition): PartyDefinition, validate: fun(value: PartyDefinition), is: fun(value: any): boolean}
local Definition = S.define("PartyDefinition", {nameSuffix = S.string,
    placement = S.enum({"stationed", "world"}), treasury = S.optional(C.count), supplies = S.optional(C.count),
    hostile = S.boolean, members = S.array(Member.validate)})
return Definition
