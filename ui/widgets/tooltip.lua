-- ui/widgets/tooltip.lua
-- UI Tooltip widget

local Tooltip = {}

function Tooltip.new(text, x, y)
    local self = {
        text = text or "",
        x = x or 0,
        y = y or 0,
        visible = false,
        maxWidth = 200
    }
    return self
end

function Tooltip:show()
    self.visible = true
end

function Tooltip:hide()
    self.visible = false
end

function Tooltip:setPosition(x, y)
    self.x = x
    self.y = y
end

function Tooltip:draw()
    if not self.visible then return end
    
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", self.x, self.y, self.maxWidth, 40)
    
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.rectangle("line", self.x, self.y, self.maxWidth, 40)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(self.text, self.x + 5, self.y + 5, self.maxWidth - 10, "left")
end

return Tooltip
