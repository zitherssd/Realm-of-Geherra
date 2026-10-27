local S = require("src.core.schema")
local C = require("src.data.types.common")
---@class NpcArchetype
---@field id string
---@field troopType string
---@field title string
---@field important boolean
---@field treasury? Count
---@field goals? table[]
---@field capabilities? table<string, boolean>
---@field stats? table<string, Count>
---@field attributes? table<string, Count>
---@field equipment? table<string, string|string[]>
---@field namePool? string
---@field dialogueId? string
---@field party? string|PartyDefinition|false
---@type {new: fun(value: NpcArchetype): NpcArchetype, validate: fun(value: NpcArchetype), is: fun(value: any): boolean}
local Archetype = S.define("NpcArchetype", {
    id = S.string, troopType = S.string, title = S.string, important = S.boolean,
    treasury = S.optional(C.count), goals = S.optional(S.array(S.table)),
    capabilities = S.optional(S.map(S.boolean)), stats = S.optional(S.map(C.count)),
    attributes = S.optional(S.map(C.count)), equipment = S.optional(S.map(C.equipment)),
    namePool = S.optional(S.string), dialogueId = S.optional(S.string), party = S.optional(C.party),
})
return Archetype
