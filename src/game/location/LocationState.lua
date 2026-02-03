local GameState = require('src.game.GameState')
local PartyManagementState = require('src.game.ui.states.PartyManagementState')
local interactions = require('src.data.interactions')
local PlayerModule = require('src.game.modules.PlayerModule')
local InteractionModule = require('src.game.modules.InteractionModule')
local SimpleMenu = require('src.game.ui.SimpleMenu')
local gradientShader = love.graphics.newShader('src/game/shaders/gradient_band.glsl')
local LocationListUI = require('src.game.location.LocationListUI')

local LocationState = {
    location = nil,
    bg = nil,
    menu = nil,
}

function LocationState:enter(location)

    if location then
        self.location = location
        self.menu = LocationListUI:new(location)
    end

    -- Try load a per-location background, else fallback
    local bgPath = (self.location and self.location.background) or 'assets/locations/village.png'
    pcall(function()
        self.bg = love.graphics.newImage(bgPath)
    end)
end

function LocationState:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(1, 1, 1, 1)

    -- ░░ Draw background
    if self.bg then
        local bw, bh = self.bg:getWidth(), self.bg:getHeight()
        local sx = w / bw
        local sy = h / bh
        local scale = math.min(sx, sy)
        local x = (w - bw * scale) / 2
        local y = (h - bh * scale) / 2
        love.graphics.draw(self.bg, x, y, 0, scale, scale)
    else
        love.graphics.clear(0.1, 0.1, 0.12, 1)
    end

    -- ░░ Gap from top
    local topGap = 25

    -- ░░ Draw fading black band (top-left)
    love.graphics.setShader(gradientShader)
    love.graphics.rectangle("fill", 0, topGap, w * 0.5, 70)
    love.graphics.setShader()

    -- ░░ Draw location name
    if self.location and self.location.name then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(love.graphics.newFont(26))
        love.graphics.printf(self.location.name, 20, topGap + 20, w * 0.5 - 40, "left")
        love.graphics.setFont(love.graphics.newFont(12))

    end

    -- ░░ Draw menu (if any)
    if self.menu then
        self.menu:draw(w, h)
    end
end



function LocationState:keypressed(key)
    if not self.menu then return end
    if key == 'up' or key == 'w' then
        self.menu:onAction('navigate_up')
    elseif key == 'down' or key == 's' then
        self.menu:onAction('navigate_down')
    elseif key == 'return' or key == 'space' then
        self.menu:onAction('activate')
    elseif key == 'escape' then
        self.menu:onAction('cancel')
    end
end

return LocationState

