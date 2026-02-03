local GameState = require('src.game.GameState')
local interactions = require('src.data.interactions')
local PartyManagementState = require('src.game.ui.states.PartyManagementState')
local gradientShader = love.graphics.newShader('src/game/shaders/gradient_band.glsl')
local TimeModule = require('src.game.modules.TimeModule')

local LocationListUI = {}
LocationListUI.__index = LocationListUI

function LocationListUI:new(location)
    local o = {
        location = location,
        selectedIndex = 1,
        visible = true,
        -- Visual properties
        padding = 25,
        optionHeight = 35,
        backgroundAlpha = 0.4,
        width = 500,
    }
    setmetatable(o, self)
    return o
end

function LocationListUI:draw(screenWidth, screenHeight)
    if not self.visible then return end
    
    -- Calculate dimensions
    local options = self:getAvailableOptions()
    local menuWidth = self.width
    local menuHeight = #options * self.optionHeight + self.padding * 2
    -- Center on the left half of the screen
    local leftCenterX = 0
    local menuX = math.floor(leftCenterX)
    local menuY = math.floor((screenHeight / 1.8) - (menuHeight / 2))
    
    -- Draw gradient background band instead of square box
    love.graphics.setShader(gradientShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setShader()
    
    -- Draw options
    for i, option in ipairs(options) do
        local y = menuY + self.padding + (i-1) * self.optionHeight
        -- Left-align text with "> " prefix
        local text = "> " .. option.label
        local isDisabled = option.disabled
        if i == self.selectedIndex and not isDisabled then
            love.graphics.setColor(1, 1, 0)  -- Yellow for selected
        elseif isDisabled then
            love.graphics.setColor(0.6, 0.6, 0.6) -- Gray for disabled
        else
            love.graphics.setColor(1, 1, 1)  -- White for others
        end
        love.graphics.printf(text, menuX + 16, y, menuWidth - 32, 'left')
    end
    
    love.graphics.setColor(1, 1, 1)  -- Reset color
end

function LocationListUI:onAction(action)
    local options = self:getAvailableOptions()
    if action == 'navigate_up' then
        local attempts = 0
        repeat
            self.selectedIndex = (self.selectedIndex - 2) % #options + 1
            attempts = attempts + 1
        until not options[self.selectedIndex].disabled or attempts > #options
    elseif action == 'navigate_down' then
        local attempts = 0
        repeat
            self.selectedIndex = self.selectedIndex % #options + 1
            attempts = attempts + 1
        until not options[self.selectedIndex].disabled or attempts > #options
    elseif action == 'activate' then
        if not options[self.selectedIndex].disabled then
            self:selectCurrentOption()
        end
    elseif action == 'cancel' then
        GameState:pop()
    end
end

function LocationListUI:getAvailableOptions()
    local options = {}
    
    -- Convert location interactions to menu options
    for _, interactionKey in ipairs(self.location.interactions or {}) do
        local definition = interactions[interactionKey]
        if definition then
            local disabled = false
            if interactionKey == 'recruit_village' then
                local untilDay = self.location._recruitCooldownUntilDay
                if untilDay and TimeModule:getDay() < untilDay then
                    disabled = true
                end
            end
            table.insert(options, {
                label = definition.label,
                action = definition.action,
                key = interactionKey,
                disabled = disabled,
            })
        end
    end
    -- Add Inspect option
    table.insert(options, {
        label = "Inspect",
        action = function()
            GameState:push(PartyManagementState)
        end
    })
    
    -- Add "Leave" option
    table.insert(options, {
        label = "Leave",
        action = function() GameState:pop() end
    })
    
    return options
end

function LocationListUI:selectCurrentOption()
    local options = self:getAvailableOptions()
    local selected = options[self.selectedIndex]
    if selected and selected.action then
        local SimpleMenu = require('src.game.ui.SimpleMenu')
        local context = {
            target = self.location,
            closeMenu = function() 
                SimpleMenu:close()
                self:close() 
            end,
            showMessage = function(text, opts)
                SimpleMenu:showMessage(text, opts)
            end
        }
        selected.action(context)
    end
end

function LocationListUI:close()
    self.visible = false
    GameState:pop()
end

return LocationListUI