-- ui/widgets/button.lua
-- Themed button — Antediluvian Earth palette (Terracotta, Amber, Ochre)
-- Per art-bible: default = darkened Terracotta, hover = Amber glow, pressed = darker inset

local Button = {}
Button.__index = Button

-- Palette constants
local TERRA_DARK  = {0.50, 0.25, 0.15, 1}  -- darkened Terracotta
local TERRA       = {0.71, 0.35, 0.22, 1}  -- Terracotta fill
local AMBER       = {0.92, 0.65, 0.14, 1}  -- Amber glow
local OCHRE_DIS   = {0.40, 0.32, 0.20, 1}  -- desaturated Ochre at ~40%
local CHARCOAL    = {0.14, 0.14, 0.18, 1}  -- Charcoal
local PARCHMENT   = {0.90, 0.84, 0.73, 1}  -- Parchment (text)

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
    local fill, borderColor, textColor

    if self.disabled then
        fill = OCHRE_DIS
        borderColor = {0.3, 0.25, 0.15, 1}
        textColor = {0.6, 0.5, 0.35, 1}
    elseif self.state == "active" then
        fill = {0.35, 0.18, 0.10, 1}  -- darker inset
        borderColor = AMBER
        textColor = PARCHMENT
    elseif self.state == "hover" then
        fill = TERRA
        borderColor = AMBER
        textColor = AMBER
    else
        fill = TERRA_DARK
        borderColor = {0.6, 0.4, 0.15, 1}  -- bronze
        textColor = PARCHMENT
    end

    -- Button body
    love.graphics.setColor(unpack(fill))
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)

    -- Outer border (carved stone — Charcoal, thick)
    love.graphics.setColor(CHARCOAL)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
    love.graphics.setLineWidth(1)

    -- Inner border (bronze inlay)
    love.graphics.setColor(unpack(borderColor))
    love.graphics.rectangle("line", self.x + 2, self.y + 2, self.w - 4, self.h - 4)

    -- Corner rivets (bronze dots)
    local r = 2
    love.graphics.circle("fill", self.x + 3, self.y + 3, r)
    love.graphics.circle("fill", self.x + self.w - 3, self.y + 3, r)
    love.graphics.circle("fill", self.x + 3, self.y + self.h - 3, r)
    love.graphics.circle("fill", self.x + self.w - 3, self.y + self.h - 3, r)

    -- Text
    local font = love.graphics.getFont()
    love.graphics.setColor(unpack(textColor))
    local textH = font:getHeight()
    love.graphics.printf(self.text, self.x, self.y + (self.h - textH) / 2, self.w, "center")
end

return Button
