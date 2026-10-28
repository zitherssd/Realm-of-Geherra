-- Explicit manifests work in packaged LÖVE games as well as on disk.
local Registry = {}

function Registry.checkId(kind, id, definition)
    assert(type(definition) == "table" and definition.id == id, "Invalid " .. kind .. " ID: " .. tostring(id))
end

function Registry.load(kind, prefix, names)
    local entries = {}
    for _, name in ipairs(names) do
        local definition = require(prefix .. name)
        Registry.checkId(kind, name, definition)
        assert(not entries[name], "Duplicate " .. kind .. " ID: " .. name)
        entries[name] = definition
    end
    return entries
end

function Registry.keys(entries)
    local keys = {}
    for key in pairs(entries) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function Registry.fields(value, allowed, label)
    assert(type(value) == "table", label .. " must be a table")
    for key in pairs(value) do
        assert(allowed[key], label .. ": unknown field " .. tostring(key))
    end
end

function Registry.range(value, label)
    local low, high = value, value
    if type(value) == "table" then
        Registry.fields(value, {
            min = true,
            max = true,
        }, label)
        low, high = value.min, value.max
    end
    assert(
        type(low) == "number"
            and type(high) == "number"
            and low == low
            and high == high
            and low >= 0
            and high < math.huge
            and low <= high
            and low % 1 == 0
            and high % 1 == 0,
        label .. " must be a nonnegative integer or {min, max} range"
    )
    return low, high
end

function Registry.roll(value, rng)
    local low, high = Registry.range(value, "Range")
    if low == high then
        return low
    end
    return rng(low, high)
end

return Registry
