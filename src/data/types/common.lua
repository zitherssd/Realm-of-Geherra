local S = require("src.core.schema")
---@class IntegerRange
---@field min integer
---@field max integer
---@alias Count integer|IntegerRange
local Range = S.define("IntegerRange", {min = S.integer, max = S.integer})
local Common = {}
function Common.count(value, path)
    if type(value) == "number" then S.integer(value, path); return end
    Range.validate(value, path)
    assert(value.min <= value.max, path .. ": inverted range")
end
function Common.party(value, path)
    if type(value) == "table" then
        require("src.data.types.party_definition").validate(value, path)
    elseif value ~= false then S.string(value, path) end
end
function Common.equipment(value, path)
    if type(value) == "string" then S.string(value, path) else S.array(S.string)(value, path) end
end
return Common
