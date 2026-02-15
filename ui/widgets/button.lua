-- ui/widgets/button.lua
-- Simple button widget

local Button = {}
Button.__index = Button

function Button.new(text, x, y, w, h, callback)
    local self = setmetatable({}, Button)
    self.text = text or "Button"
    self.x = x or 0
    self.y = y or 0
    self.w = w or 100
    self.h = h or 40
    self.callback = callback
    
    self.state = "idle" -- idle, hover, active
    self.wasDown = false
    self.disabled = false
    return self
end

function Button:update(dt)
    if self.disabled then return end
    local mx, my = love.mouse.getPosition()
    local isDown = love.mouse.isDown(1)
    
    -- Check hover
    local hot = mx >= self.x and mx <= self.x + self.w and
                my >= self.y and my <= self.y + self.h
    
    if hot then
        if isDown then
            self.state = "active"
            self.wasDown = true
        else
            if self.wasDown and self.state == "active" then
                -- Clicked (released while hot)
                if self.callback then self.callback() end
            end
            self.state = "hover"
            self.wasDown = false
        end
    else
        self.state = "idle"
        self.wasDown = false
    end
end

function Button:draw()
    local color
    if self.disabled then
        color = {0.1, 0.1, 0.1, 1}
    else
        color = (self.state == "active") and {0.3, 0.3, 0.3, 1} or (self.state == "hover") and {0.4, 0.4, 0.4, 1} or {0.2, 0.2, 0.2, 1}
    end
    
    love.graphics.setColor(unpack(color))
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    
    -- Border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
    
    -- Text
    local font = love.graphics.getFont()
    if self.disabled then
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    local textH = font:getHeight()
    love.graphics.printf(self.text, self.x, self.y + (self.h - textH) / 2, self.w, "center")
end

return Button
