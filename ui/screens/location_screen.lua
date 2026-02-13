-- ui/screens/location_screen.lua
-- Screen displayed when entering a location

local LocationScreen = {}
local Button = require("ui.widgets.button")
local StateManager = require("core.state_manager")

function LocationScreen.new(location, onLeave)
    local self = setmetatable({}, { __index = LocationScreen })
    self.location = location
    self.onLeave = onLeave
    
    self.width = love.graphics.getWidth()
    self.height = love.graphics.getHeight()
    
    self.buttons = {}
    
    -- 1. Create NPC Buttons
    local startY = 150
    local btnHeight = 60
    local btnWidth = 300
    local startX = 50
    
    for i, npc in ipairs(location.npcs) do
        local btnText = npc.name or "Unknown NPC"
        local btnY = startY + (i-1) * (btnHeight + 10)
        
        local btn = Button.new(btnText, startX, btnY, btnWidth, btnHeight, function()
            -- Enter dialogue with this NPC
            -- We assume the NPC has a dialogueId, or default to a generic one
            local dialogueId = npc.dialogueId or "elder_greeting"
            StateManager.push("dialogue", { target = npc, dialogueId = dialogueId })
        end)
        
        -- Store reference to NPC on the button for drawing sprites later
        btn.npc = npc
        table.insert(self.buttons, btn)
    end
    
    -- 2. Create Location Type Options
    -- Position these below NPCs or in a separate column
    local optionsY = startY + (#location.npcs * (btnHeight + 10)) + 40
    
    if location.type == "town" then
        table.insert(self.buttons, Button.new("Visit Tavern", startX, optionsY, btnWidth, 50, function() end))
        table.insert(self.buttons, Button.new("Trade Goods", startX, optionsY + 60, btnWidth, 50, function() end))
    elseif location.type == "castle" then
        table.insert(self.buttons, Button.new("Request Audience", startX, optionsY, btnWidth, 50, function() end))
    elseif location.type == "village" then
        table.insert(self.buttons, Button.new("Buy Supplies", startX, optionsY, btnWidth, 50, function() end))
    end
    
    -- 3. Leave Button
    self.leaveBtn = Button.new("Leave " .. location.name, self.width - 250, self.height - 80, 200, 50, onLeave)
    
    return self
end

function LocationScreen:update(dt)
    for _, btn in ipairs(self.buttons) do
        btn:update(dt)
    end
    self.leaveBtn:update(dt)
end

function LocationScreen:draw()
    -- Background (Overlay)
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    
    -- Header
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.printf(self.location.name, 0, 40, self.width, "center")
    
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.printf(string.upper(self.location.type), 0, 80, self.width, "center")
    
    -- Draw Buttons
    for _, btn in ipairs(self.buttons) do
        btn:draw()
        
        -- Draw NPC Sprite on top of button if applicable
        if btn.npc then
            love.graphics.setColor(1, 1, 1, 1)
            local iconSize = 40
            local iconX = btn.x + 10
            local iconY = btn.y + (btn.h - iconSize) / 2
            
            if btn.npc.visuals and btn.npc.visuals.icon then
                -- Draw actual sprite
                love.graphics.draw(btn.npc.visuals.icon, iconX, iconY)
            else
                -- Draw placeholder circle
                love.graphics.setColor(0.5, 0.8, 0.9, 1)
                love.graphics.circle("fill", iconX + iconSize/2, iconY + iconSize/2, iconSize/2)
                
                -- Draw first letter of name
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.print(string.sub(btn.npc.name, 1, 1), iconX + 12, iconY + 8)
            end
        end
    end
    
    self.leaveBtn:draw()
end

function LocationScreen:mousepressed(x, y, button)
    -- Buttons handle their own input in update via love.mouse.isDown
    -- But if we needed click events specifically here, we'd pass them down
end

return LocationScreen