-- utils/string.lua
-- String utility functions

local String = {}

function String.split(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

function String.trim(str)
    return str:find("^%s*$") and "" or str:match("^%s*(.*%S)")
end

function String.startsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

function String.endsWith(str, suffix)
    return str:sub(-#suffix) == suffix
end

function String.capitalize(str)
    return str:sub(1, 1):upper() .. str:sub(2):lower()
end

return String
