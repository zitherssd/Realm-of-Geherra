-- ui/screens/location_screen.lua
-- Screen displayed when entering a location

local LocationScreen = {}
LocationScreen.__index = LocationScreen

local Button = require("ui.widgets.button")
local StateManager = require("core.state_manager")
local LocationActions = require("systems.location_actions")

function LocationScreen.new(location, onLeave)
    local self = setmetatable({}, LocationScreen)
    self.location = location
    self.onLeave = onLeave
    
    self.width = love.graphics.getWidth()
    self.height = love.graphics.getHeight()
    self.smallFont = love.graphics.newFont(12)
    
    -- Load background image based on location type
    local bgPath = "assets/locations/" .. location.type .. ".png"
    if love.filesystem.getInfo(bgPath) then
        self.backgroundImage = love.graphics.newImage(bgPath)
    end
    
    local startX = 50
    -- 3. Leave Button
    self.leaveBtn = Button.new("Leave " .. location.name, startX, self.height - 80, 200, 50, onLeave)
    
    self:refreshButtons()
    
    return self
end

function LocationScreen:refreshButtons()
    self.buttons = {}
    local location = self.location
    
    -- 1. Create NPC Buttons
    local startY = 150
    local btnSize = 120
    local padding = 20
    local startX = 50
    
    for i, npc in ipairs(location.npcs) do
        -- Empty text because we will draw the name manually at the bottom
        local btnText = ""
        -- Arrange horizontally
        local btnX = startX + (i-1) * (btnSize + padding)
        local btnY = startY
        
        local btn = Button.new(btnText, btnX, btnY, btnSize, btnSize, function()
            -- Enter dialogue with this NPC
            -- We assume the NPC has a dialogueId, or default to a generic one
            local dialogueId = npc.dialogueId or "elder_greeting"
            StateManager.push("dialogue", { target = npc, dialogueId = dialogueId })
        end)
        
        -- Store reference to NPC and load sprite
        btn.npc = npc
        if npc.sprite and love.filesystem.getInfo(npc.sprite) then
            btn.npcImage = love.graphics.newImage(npc.sprite)
            btn.npcImage:setFilter("nearest", "nearest")
        end
        
        table.insert(self.buttons, btn)
    end
    
    -- 2. Create Location Type Options
    -- Position these below the NPC row
    local optionsY = startY + btnSize + 40
    local btnWidth = 300
    local btnHeight = 50
    
    if location.type == "town" then
        table.insert(self.buttons, Button.new("Visit Tavern", startX, optionsY, btnWidth, 50, function() end))
        table.insert(self.buttons, Button.new("Trade Goods", startX, optionsY + 60, btnWidth, 50, function() end))
        table.insert(self.buttons, Button.new("Rest", startX, optionsY + 120, btnWidth, 50, function() 
            LocationActions.rest(location)
        end))
    elseif location.type == "castle" then
        table.insert(self.buttons, Button.new("Request Audience", startX, optionsY, btnWidth, 50, function() end))
        table.insert(self.buttons, Button.new("Train Troops", startX, optionsY + 60, btnWidth, 50, function() end))
    elseif location.type == "village" then
        table.insert(self.buttons, Button.new("Buy Supplies", startX, optionsY, btnWidth, 50, function() end))
        
        local cooldown = LocationActions.getRecruitCooldown(location)
        if cooldown > 0 then
            local btn = Button.new("Recruit (" .. math.ceil(cooldown) .. "d)", startX, optionsY + 60, btnWidth, 50, function() end)
            btn.disabled = true
            table.insert(self.buttons, btn)
        else
            table.insert(self.buttons, Button.new("Recruit Volunteers", startX, optionsY + 60, btnWidth, 50, function()
                local resultText = LocationActions.recruitVolunteers(location)
                self:showPopup(resultText)
            end))
        end
    elseif location.type == "ruins" then
        table.insert(self.buttons, Button.new("Explore Ruin", startX, optionsY, btnWidth, 50, function()
            LocationActions.exploreRuin(location)
        end))
    end
end

function LocationScreen:showPopup(text)
    self.popup = {
        text = text,
        okBtn = Button.new("OK", self.width/2 - 50, self.height/2 + 40, 100, 40, function()
            self.popup = nil
            self:refreshButtons()
        end)
    }
end

function LocationScreen:show()
    -- Called when screen becomes active
end

function LocationScreen:hide()
    -- Called when screen is hidden
end

function LocationScreen:update(dt)
    if self.popup then
        self.popup.okBtn:update(dt)
        return
    end

    for _, btn in ipairs(self.buttons) do
        btn:update(dt)
    end
    self.leaveBtn:update(dt)
end

function LocationScreen:draw()
    -- Background (Overlay)
    if self.backgroundImage then
        love.graphics.setColor(1, 1, 1, 1)
        local sx = self.width / self.backgroundImage:getWidth()
        local sy = self.height / self.backgroundImage:getHeight()
        love.graphics.draw(self.backgroundImage, 0, 0, 0, sx, sy)
        
        -- Darken slightly for readability
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    else
        love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    end
    
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
            -- Draw Sprite
            if btn.npcImage then
                love.graphics.setColor(1, 1, 1, 1)
                
                -- Scale sprite to fit in button (leave space for text)
                local availH = btn.h - 30 -- Reserve 30px for text
                local scale = math.min(btn.w / btn.npcImage:getWidth(), availH / btn.npcImage:getHeight()) * 0.8
                
                local imgW = btn.npcImage:getWidth() * scale
                local imgH = btn.npcImage:getHeight() * scale
                
                -- Center horizontally
                local ix = btn.x + (btn.w - imgW) / 2
                -- Center vertically in the available space (above text)
                local iy = btn.y + (availH - imgH) / 2
                
                love.graphics.draw(btn.npcImage, ix, iy, 0, scale, scale)
            else
                -- Draw placeholder circle
                love.graphics.setColor(0.5, 0.8, 0.9, 1)
                love.graphics.circle("fill", btn.x + btn.w/2, btn.y + btn.h/2 - 10, 30)
            end
            
            -- Draw Name at the bottom
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(self.smallFont)
            local name = btn.npc.name or "Unknown"
            love.graphics.printf(name, btn.x + 2, btn.y + btn.h - 25, btn.w - 4, "center")
        end
    end
    
    self.leaveBtn:draw()

    -- Draw Popup Overlay
    if self.popup then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
        
        local boxW, boxH = 400, 200
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", (self.width - boxW)/2, (self.height - boxH)/2, boxW, boxH)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", (self.width - boxW)/2, (self.height - boxH)/2, boxW, boxH)
        
        love.graphics.printf(self.popup.text, (self.width - boxW)/2 + 20, (self.height - boxH)/2 + 40, boxW - 40, "center")
        
        self.popup.okBtn:draw()
    end
end

function LocationScreen:mousepressed(x, y, button)
    -- Buttons handle their own input in update via love.mouse.isDown
    -- But if we needed click events specifically here, we'd pass them down
end

return LocationScreen