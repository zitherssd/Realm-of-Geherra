local S = require("src.core.schema")
local C = require("src.data.types.common")
local Rule = require("src.data.types.population_rule")
---@class PartyMember
---@field id string Stable ID for this composition entry, not an actor ID.
---@field troopType? string Direct ordinary troop template.
---@field archetype? string Important or ordinary actor archetype.
---@field role? string Culturally resolved role.
---@field count? Count Inclusive number of attempted members.
---@field chance? number Probability per attempted member, from 0 to 1.
---@field when? PopulationConditions
---@field enabled? boolean
---@type {new: fun(value: PartyMember): PartyMember, validate: fun(value: PartyMember), is: fun(value: any): boolean}
local Member = S.define("PartyMember", {
    id = S.string,
    troopType = S.optional(S.string),
    archetype = S.optional(S.string),
    role = S.optional(S.string),
    count = S.optional(C.count),
    chance = S.optional(S.probability),
    when = S.optional(Rule.Conditions.validate),
    enabled = S.optional(S.boolean),
})
local validateShape = Member.validate
function Member.validate(value, path)
    validateShape(value, path)
    local selectors = (value.troopType and 1 or 0) + (value.archetype and 1 or 0) + (value.role and 1 or 0)
    assert(selectors == 1, (path or "PartyMember") .. ": specify exactly one troopType, archetype or role")
    return value
end
return Member
