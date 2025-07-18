-- Biome module
-- Handles loading the biome map and querying biome types

local Biome = {}

local biomeImage = nil
local biomeData = nil

-- Define biome types by RGB color
Biome.types = {
    forest = {r=34, g=139, b=34},      -- Forest (green)
    plains = {r=154, g=205, b=50},     -- Plains (yellow-green)
    snow = {r=255, g=250, b=250},      -- Snow (white)
    water = {r=30, g=144, b=255},      -- Water (blue)
    desert = {r=237, g=201, b=175},    -- Desert (tan)
    mountain = {r=128, g=128, b=128},  -- Mountain (gray)
}

Biome.effects = {
    forest = {speed = 0.8, healing = 1.2, impassable = false},
    plains = {speed = 1.0, healing = 1.0, impassable = false},
    snow = {speed = 0.6, healing = 0.8, impassable = false},
    water = {speed = 0.0, healing = 0.0, impassable = true},
    desert = {speed = 0.7, healing = 0.7, impassable = false},
    mountain = {speed = 0.5, healing = 0.5, impassable = false},
}

function Biome:load(path)
    biomeImage = love.image.newImageData(path)
    biomeData = biomeImage
end

-- Helper to match a color to a biome type
local function colorToBiome(r, g, b)
    for biome, color in pairs(Biome.types) do
        if math.abs(r - color.r) <= 5 and math.abs(g - color.g) <= 5 and math.abs(b - color.b) <= 5 then
            return biome
        end
    end
    return 'plains' -- Default
end

function Biome:getBiomeAt(x, y)
    if not biomeData then return 'plains', Biome.effects['plains'] end
    x = math.floor(x)
    y = math.floor(y)
    if x < 0 or y < 0 or x >= biomeData:getWidth() or y >= biomeData:getHeight() then
        return 'plains', Biome.effects['plains']
    end
    local r, g, b = biomeData:getPixel(x, y)
    r, g, b = r * 255, g * 255, b * 255
    local biome = colorToBiome(r, g, b)
    return biome, Biome.effects[biome]
end

return Biome