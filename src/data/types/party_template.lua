local S = require("src.core.schema")
local Definition = require("src.data.types.party_definition")
---@class PartyTemplate: PartyDefinition
---@field id string
---@type {new: fun(value: PartyTemplate): PartyTemplate, validate: fun(value: PartyTemplate), is: fun(value: any): boolean}
local Template = S.extend("PartyTemplate", Definition, {
    id = S.string,
})
return Template
