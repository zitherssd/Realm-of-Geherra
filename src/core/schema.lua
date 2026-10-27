-- Checked data records, not a replacement object model for ECS entities.
local Schema = {}
local recordFields = setmetatable({}, {__mode = "k"})

local function expect(ok, path, expected)
    assert(ok, path .. ": expected " .. expected)
end

function Schema.string(value, path) expect(type(value) == "string" and value ~= "", path, "nonempty string") end
function Schema.boolean(value, path) expect(type(value) == "boolean", path, "boolean") end
function Schema.number(value, path)
    expect(type(value) == "number" and value == value and math.abs(value) < math.huge, path, "finite number")
end
function Schema.integer(value, path)
    Schema.number(value, path)
    expect(value >= 0 and value % 1 == 0, path, "nonnegative integer")
end
function Schema.probability(value, path)
    Schema.number(value, path)
    expect(value >= 0 and value <= 1, path, "probability between 0 and 1")
end
function Schema.table(value, path) expect(type(value) == "table", path, "table") end

function Schema.optional(check)
    return function(value, path) if value ~= nil then check(value, path) end end
end

function Schema.enum(values)
    return function(value, path)
        for _, option in ipairs(values) do if value == option then return end end
        error(path .. ": expected one of " .. table.concat(values, ", "))
    end
end

function Schema.array(check)
    return function(value, path)
        Schema.table(value, path)
        local count = 0
        for key in pairs(value) do
            expect(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #value, path, "dense array")
            count = count + 1
        end
        expect(count == #value, path, "dense array")
        for index, child in ipairs(value) do check(child, path .. "[" .. index .. "]") end
    end
end

function Schema.map(check)
    return function(value, path)
        Schema.table(value, path)
        for key, child in pairs(value) do
            Schema.string(key, path .. " key")
            check(child, path .. "." .. key)
        end
    end
end

function Schema.define(name, fields)
    local record = {name = name}
    recordFields[record] = fields
    function record.validate(value, path)
        path = path or (name .. (type(value) == "table" and value.id and ("[" .. tostring(value.id) .. "]") or ""))
        Schema.table(value, path)
        for key in pairs(value) do assert(fields[key], path .. ": unknown field " .. tostring(key)) end
        for key, check in pairs(fields) do check(value[key], path .. "." .. key) end
        return value
    end
    function record.new(value) return record.validate(value) end
    function record.is(value) return (pcall(record.validate, value)) end
    return record
end

function Schema.extend(name, base, fields)
    local combined = {}
    for key, check in pairs(assert(recordFields[base], "Expected a schema base type")) do combined[key] = check end
    for key, check in pairs(fields) do
        assert(not combined[key], "Duplicate inherited field " .. key)
        combined[key] = check
    end
    return Schema.define(name, combined)
end

return Schema
