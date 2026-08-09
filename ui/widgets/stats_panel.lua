-- ui/widgets/stats_panel.lua
-- Reusable actor stats panel

local StatsPanel = {}
StatsPanel.__index = StatsPanel

local Items = require("data.items")

-- Damage types with flat protection (innate + equipment). Mirrors
-- systems/combat_system.lua getTotalProtection.
local DAMAGE_TYPES = {
    "slashing", "piercing", "blunt", "fire", "ice", "shock", "poison"
}

local function newPixelFont(size)
    local font = love.graphics.newFont(size)
    font:setFilter("nearest", "nearest")
    return font
end

function StatsPanel.new(x, y, width, height)
    local self = setmetatable({}, StatsPanel)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.titleFont = newPixelFont(16)
    self.bodyFont = newPixelFont(13)
    self.scrollOffset = 0
    self.contentHeight = 0
    return self
end

local function buildEffectiveStats(actor)
    local effectiveStats = {}
    local baseStats = actor.stats or {}

    for statName, value in pairs(baseStats) do
        effectiveStats[statName] = value
    end

    if actor.equipment then
        for _, itemId in pairs(actor.equipment) do
            if itemId then
                local item = Items[itemId]
                if item and item.stats then
                    for statName, value in pairs(item.stats) do
                        effectiveStats[statName] = (effectiveStats[statName] or 0) + value
                    end
                end
            end
        end
    end

    return effectiveStats
end

-- Total flat protection per damage type (innate + equipped items). Mirrors
-- systems/combat_system.lua getTotalProtection.
local function buildEffectiveProtections(actor)
    local protections = {}
    for _, damageType in ipairs(DAMAGE_TYPES) do
        protections[damageType] = 0
    end

    local innate = actor.innateProtections or {}
    for damageType, value in pairs(innate) do
        protections[damageType] = (protections[damageType] or 0) + value
    end

    if actor.equipment then
        for _, itemId in pairs(actor.equipment) do
            if itemId then
                local item = Items[itemId]
                if item and item.protections then
                    for damageType, value in pairs(item.protections) do
                        protections[damageType] = (protections[damageType] or 0) + value
                    end
                end
            end
        end
    end

    return protections
end

function StatsPanel:draw(actor)
    if not actor then return end

    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.print("Stats", self.x + 10, self.y + 10)

    local stats = buildEffectiveStats(actor)
    local maxHealth = actor.maxHp or stats.maxHealth or actor.maxHealth or stats.health or 0
    local currentHealth = actor.hp or maxHealth
    local roundedCurrentHealth = math.floor(currentHealth + 0.5)
    local roundedMaxHealth = math.floor(maxHealth + 0.5)
    local statLines = {
        "HP: " .. tostring(roundedCurrentHealth) .. "/" .. tostring(roundedMaxHealth),
        "ATK: " .. tostring(stats.attack or 0),
        "DEF: " .. tostring(stats.defense or 0),
        "SPEED: " .. tostring(stats.speed or 0),
        "B. SPEED: " .. tostring(stats.battle_speed or 0)
    }

    local lineHeight = 18
    local contentTop = self.y + 36 - self.scrollOffset
    local twoColumns = self.width >= 340
    local protectX = twoColumns and (self.x + self.width / 2) or (self.x + 10)
    local protectTop = twoColumns and (self.y + 10) or contentTop + (#statLines + 2) * lineHeight
    self.contentHeight = twoColumns and (#statLines * lineHeight) or ((#statLines + 2 + #DAMAGE_TYPES) * lineHeight)

    love.graphics.setScissor(self.x, self.y, self.width, self.height)
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    for index, line in ipairs(statLines) do
        love.graphics.print(line, self.x + 20, contentTop + (index - 1) * lineHeight)
    end

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.print("Protections", protectX, protectTop)
    love.graphics.setFont(self.bodyFont)

    local protections = buildEffectiveProtections(actor)
    for index, damageType in ipairs(DAMAGE_TYPES) do
        local rowY = (twoColumns and contentTop or protectTop + 24) + (index - 1) * lineHeight
        local label = string.upper(string.sub(damageType, 1, 1)) .. string.sub(damageType, 2)
        local value = protections[damageType] or 0
        if value > 0 then
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
        else
            love.graphics.setColor(0.45, 0.45, 0.45, 1)
        end
        love.graphics.print(label .. ": +" .. tostring(value), protectX + 10, rowY)
    end
    love.graphics.setScissor()
end

function StatsPanel:wheelmoved(_, y)
    if self.width >= 520 or self.contentHeight <= self.height - 36 then return end
    local maxOffset = math.max(0, self.contentHeight - (self.height - 36))
    self.scrollOffset = math.max(0, math.min(maxOffset, self.scrollOffset - y * 20))
end

return StatsPanel
