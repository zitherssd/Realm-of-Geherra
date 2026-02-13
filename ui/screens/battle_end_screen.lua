-- ui/screens/battle_end_screen.lua
-- Presentation layer for battle results

local BattleEndScreen = {}

-- Simple local Button widget implementation (or require("ui.widgets.button"))
local Button = require("ui.widgets.button")
local Tooltip = require("ui.widgets.tooltip")

function BattleEndScreen.new(results, onContinue)
    local self = setmetatable({}, { __index = BattleEndScreen })
    
    self.results = results
    self.width = love.graphics.getWidth()
    self.height = love.graphics.getHeight()
    
    -- Cache fonts
    self.titleFont = love.graphics.newFont(32)
    self.labelFont = love.graphics.newFont(14)
    self.itemFont = love.graphics.getFont()
    
    -- Create Widgets
    local btnW, btnH = 200, 50
    self.continueButton = Button.new("Continue", (self.width - btnW)/2, self.height - 100, btnW, btnH, onContinue)
    self.tooltip = Tooltip.new(300)
    
    return self
end

function BattleEndScreen:update(dt)
    -- Update widgets if necessary
    self.continueButton:update(dt)
    self.tooltip:update(dt)
end

function BattleEndScreen:draw()
    -- 1. Background Overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    
    -- 2. Header
    love.graphics.setColor(1, 1, 1, 1)
    local title = self.results.victory and "VICTORY" or "DEFEAT"
    love.graphics.setFont(self.titleFont)
    love.graphics.printf(title, 0, 60, self.width, "center")
    love.graphics.setFont(self.labelFont)
    
    -- 3. Columns Layout
    local colWidth = self.width / 3
    local startY = 150
    local lineHeight = 25
    local mx, my = love.mouse.getPosition()
    local hoveredItem = nil
    
    -- Helper to draw a list
    local function drawList(title, items, x, color)
        love.graphics.setColor(color)
        love.graphics.printf(title, x, startY, colWidth, "center")
        love.graphics.line(x + 20, startY + 25, x + colWidth - 20, startY + 25)
        
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        if items then
            for i, item in ipairs(items) do
                local itemY = startY + 30 + (i * lineHeight)           
                local text = type(item) == "table" and item.name or tostring(item)
                if type(item) == "table" and item.count and item.count > 1 then text = text .. " x" .. item.count end
                
                -- Check Hover
                if mx >= x + 20 and mx <= x + colWidth - 20 and my >= itemY and my <= itemY + lineHeight then
                    love.graphics.setColor(1, 1, 1, 0.1)
                    love.graphics.rectangle("fill", x + 20, itemY, colWidth - 40, lineHeight)
                    
                    -- Prepare tooltip data
                    if type(item) == "table" then
                        hoveredItem = item
                    elseif type(item) == "string" then
                        hoveredItem = {name = item}
                    end
                end
                
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
                love.graphics.printf(text, x, itemY, colWidth, "center")
            end
        end
    end
    
    -- Player Casualties
    drawList("Your Losses", self.results.playerCasualties, 0, {0.8, 0.3, 0.3, 1})
    
    -- Enemy Casualties
    drawList("Enemy Losses", self.results.enemyCasualties, colWidth, {0.8, 0.3, 0.3, 1})
    
    -- Loot
    drawList("Loot Gained", self.results.loot, colWidth * 2, {1, 0.8, 0.2, 1})
    
    -- 4. Draw Widgets
    self.continueButton:draw()
    
    -- 5. Draw Tooltip
    if hoveredItem then
        local desc = hoveredItem.name or "Unknown"
        if hoveredItem.type then desc = desc .. "\n(" .. hoveredItem.type .. ")" end
        if hoveredItem.description then desc = desc .. "\n" .. hoveredItem.description end
        if hoveredItem.stats then
            desc = desc .. "\n"
            for k, v in pairs(hoveredItem.stats) do
                desc = desc .. "\n" .. k:upper() .. ": " .. v
            end
        end
        
        self.tooltip:setText(desc)
        self.tooltip:setPosition(mx, my)
        self.tooltip:show()
    else
        self.tooltip:hide()
    end
    self.tooltip:draw()
end

function BattleEndScreen:mousepressed(x, y, button)
    -- Buttons handle their own input in update()
end

return BattleEndScreen