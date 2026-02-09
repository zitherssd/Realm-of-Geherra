-- ui/widgets/button.lua
-- UI Button widget

local Button = {}

function Button.new(x, y, width, height, text)
    local self = {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text or "Button",
        hovered = false,
        pressed = false,
        callback = nil
    }
    return self
end

function Button:setCallback(callback)
    self.callback = callback
end

function Button:update(mx, my)
    self.hovered = mx >= self.x and mx < self.x + self.width and
                    my >= self.y and my < self.y + self.height
end

function Button:click()
    if self.hovered and self.callback then
        self.callback()
    end
end

function Button:draw()
    if self.hovered then
        love.graphics.setColor(0.3, 0.3, 0.3)
    else
        love.graphics.setColor(0.2, 0.2, 0.2)
    end
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(self.text, self.x, self.y + self.height / 2 - 8, self.width, "center")
end

return Button
