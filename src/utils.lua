<<<<<<< HEAD

=======
>>>>>>> origin/cursor/enable-bandit-parties-to-wander-towns-2efd
-- Utilities module
-- Common helper functions used throughout the game

local Utils = {}

-- Math utilities
function Utils.distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function Utils.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.normalize(x, y)
    local length = math.sqrt(x^2 + y^2)
    if length == 0 then
        return 0, 0
    end
    return x / length, y / length
end

function Utils.randomFloat(min, max)
    return min + math.random() * (max - min)
end

function Utils.randomInt(min, max)
    return math.random(min, max)
end

-- Table utilities
function Utils.deepCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == 'table' then
            copy[key] = Utils.deepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function Utils.contains(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

function Utils.removeValue(table, value)
    for i, v in ipairs(table) do
        if v == value then
            table.remove(table, i)
            return true
        end
    end
    return false
end

function Utils.shuffle(table)
    local n = #table
    for i = n, 2, -1 do
        local j = math.random(i)
        table[i], table[j] = table[j], table[i]
    end
    return table
end

-- String utilities
function Utils.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function Utils.capitalize(str)
    return str:sub(1, 1):upper() .. str:sub(2):lower()
end

function Utils.formatNumber(num)
    -- Add commas to numbers for readability
    local formatted = tostring(num)
    while true do
        local k = string.find(formatted, "^(-?%d+)(%d%d%d)")
        if k then
            formatted = string.sub(formatted, 1, k - 1) .. string.sub(formatted, k, k + 1) .. "," .. string.sub(formatted, k + 2)
        else
            break
        end
    end
    return formatted
end

-- Color utilities
function Utils.hexToRgb(hex)
    hex = hex:gsub("#", "")
    return tonumber("0x" .. hex:sub(1, 2)) / 255,
           tonumber("0x" .. hex:sub(3, 4)) / 255,
           tonumber("0x" .. hex:sub(5, 6)) / 255
end

function Utils.rgbToHex(r, g, b)
    r = math.floor(r * 255)
    g = math.floor(g * 255)
    b = math.floor(b * 255)
    return string.format("#%02x%02x%02x", r, g, b)
end

function Utils.lerpColor(color1, color2, t)
    return {
        Utils.lerp(color1[1], color2[1], t),
        Utils.lerp(color1[2], color2[2], t),
        Utils.lerp(color1[3], color2[3], t)
    }
end

-- Time utilities
function Utils.formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%02d:%02d", minutes, secs)
    end
end

-- Game-specific utilities
function Utils.rollDice(sides, count)
    count = count or 1
    local total = 0
    for i = 1, count do
        total = total + math.random(1, sides)
    end
    return total
end

function Utils.calculateCombatRoll(attacker, defender)
    -- Simple combat calculation
    local attackRoll = attacker + Utils.rollDice(20)
    local defenseRoll = defender + Utils.rollDice(20)
    return attackRoll - defenseRoll
end

function Utils.getStatModifier(stat)
    -- D&D-style stat modifier
    return math.floor((stat - 10) / 2)
end

-- File/Data utilities
function Utils.saveData(data, filename)
    local success, result = pcall(function()
        local file = io.open(filename, "w")
        if file then
            file:write(Utils.serialize(data))
            file:close()
            return true
        end
        return false
    end)
    return success and result
end

function Utils.loadData(filename)
    local success, result = pcall(function()
        local file = io.open(filename, "r")
        if file then
            local content = file:read("*all")
            file:close()
            return Utils.deserialize(content)
        end
        return nil
    end)
    return success and result or nil
end

function Utils.serialize(data)
    -- Simple serialization for basic data types
    local function serializeValue(value)
        if type(value) == "string" then
            return string.format("%q", value)
        elseif type(value) == "number" then
            return tostring(value)
        elseif type(value) == "boolean" then
            return tostring(value)
        elseif type(value) == "table" then
            local parts = {}
            table.insert(parts, "{")
            for k, v in pairs(value) do
                table.insert(parts, "[" .. serializeValue(k) .. "] = " .. serializeValue(v) .. ",")
            end
            table.insert(parts, "}")
            return table.concat(parts)
        else
            return "nil"
        end
    end
    return "return " .. serializeValue(data)
end

function Utils.deserialize(str)
    local func = load(str)
    if func then
        return func()
    end
    return nil
end

-- Debug utilities
function Utils.printTable(t, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)
    
    for key, value in pairs(t) do
        if type(value) == "table" then
            print(spacing .. key .. ":")
            Utils.printTable(value, indent + 1)
        else
            print(spacing .. key .. ": " .. tostring(value))
        end
    end
end

return Utils