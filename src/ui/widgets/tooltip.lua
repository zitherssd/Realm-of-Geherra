-- ui/widgets/tooltip.lua
-- UI Tooltip widget

local Tooltip = {}
Tooltip.__index = Tooltip

function Tooltip.new(maxWidth)
    local self = setmetatable({}, Tooltip)
    self.text = ""
    self.x = 0
    self.y = 0
    self.visible = false
    self.maxWidth = maxWidth or 250
    self.font = love.graphics.getFont()
    return self
end

function Tooltip:update(dt)
    -- No update logic needed yet, but required by interface
end

function Tooltip:setText(text)
    self.text = text
end

function Tooltip:setPosition(x, y)
    self.x = x
    self.y = y
end

function Tooltip:show() self.visible = true end
function Tooltip:hide() self.visible = false end

function Tooltip:draw()
    if not self.visible or self.text == "" then return end
    
    local padding = 10
    local width, wrapped = self.font:getWrap(self.text, self.maxWidth - padding * 2)
    local height = #wrapped * self.font:getHeight() + padding * 2
    
    -- Clamp to screen bounds
    local sx, sy = self.x + 15, self.y + 15 -- Offset from cursor
    local sw, sh = love.graphics.getDimensions()
    
    if sx + self.maxWidth > sw then sx = sw - self.maxWidth - 5 end
    if sy + height > sh then sy = sh - height - 5 end
    
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", sx, sy, self.maxWidth, height)
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.rectangle("line", sx, sy, self.maxWidth, height)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.text, sx + padding, sy + padding, self.maxWidth - padding * 2, "left")
end

return Tooltip
