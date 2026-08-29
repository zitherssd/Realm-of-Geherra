-- utils/table.lua
-- Table utility functions

local Table = {}

function Table.copy(t)
    local result = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            result[k] = Table.copy(v)
        else
            result[k] = v
        end
    end
    return result
end

function Table.merge(t1, t2)
    local result = Table.copy(t1)
    for k, v in pairs(t2) do
        result[k] = v
    end
    return result
end

function Table.find(t, value)
    for i, v in ipairs(t) do
        if v == value then
            return i
        end
    end
    return nil
end

function Table.filter(t, predicate)
    local result = {}
    for i, v in ipairs(t) do
        if predicate(v) then
            table.insert(result, v)
        end
    end
    return result
end

function Table.map(t, transform)
    local result = {}
    for i, v in ipairs(t) do
        table.insert(result, transform(v))
    end
    return result
end

return Table
