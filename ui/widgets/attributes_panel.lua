-- ui/widgets/attributes_panel.lua
-- Reusable actor attributes panel (pip display)

local AttributesPanel = {}
AttributesPanel.__index = AttributesPanel

local ATTRIBUTES = {
    "command", "oratory", "navigation", "tracking",
    "shadowcraft", "divination", "engineering"
}
local LINE_HEIGHT = 18
local PIP_COUNT = 4

local function newPixelFont(size)
    local font = love.graphics.newFont(size)
    font:setFilter("nearest", "nearest")
    return font
end

function AttributesPanel.new(x, y, width)
    local self = setmetatable({}, AttributesPanel)
    self.x = x
    self.y = y
    self.width = width
    self.height = 30 + #ATTRIBUTES * LINE_HEIGHT + 4
    self.titleFont = newPixelFont(16)
    self.bodyFont = newPixelFont(13)
    return self
end

function AttributesPanel:draw(actor)
    if not actor then return end

    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.print("Attributes", self.x + 10, self.y + 8)

    local contentTop = self.y + 30
    love.graphics.setFont(self.bodyFont)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    for index, attributeName in ipairs(ATTRIBUTES) do
        local rowY = contentTop + (index - 1) * LINE_HEIGHT
        local label = string.upper(string.sub(attributeName, 1, 1)) .. string.sub(attributeName, 2)
        love.graphics.print(label, self.x + 10, rowY)

        local level = actor.attributes and actor.attributes[attributeName] or 0
        for boxIndex = 1, PIP_COUNT do
            local boxX = self.x + 105 + (boxIndex - 1) * 18
            if boxIndex <= level then
                love.graphics.rectangle("fill", boxX, rowY + 2, 14, 13)
            else
                love.graphics.rectangle("line", boxX, rowY + 2, 14, 13)
            end
        end
    end
end

return AttributesPanel
