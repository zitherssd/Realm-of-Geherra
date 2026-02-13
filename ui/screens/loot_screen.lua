-- ui/screens/loot_screen.lua
-- Screen for looting items after battle

local LootScreen = {}
local Button = require("ui.widgets.button")
local Tooltip = require("ui.widgets.tooltip")
local GameContext = require("game.game_context")

function LootScreen.new(loot, onContinue)
    local self = setmetatable({}, { __index = LootScreen })
    self.loot = loot or {}
    self.playerInventory = GameContext.data.playerParty.inventory
    self.onContinue = onContinue
    
    self.width = love.graphics.getWidth()
    self.height = love.graphics.getHeight()
    
    -- Buttons
    self.takeAllBtn = Button.new("Take All", self.width/2 - 110, self.height - 80, 100, 40, function() self:takeAll() end)
    self.continueBtn = Button.new("Continue", self.width/2 + 10, self.height - 80, 100, 40, function() self:finish() end)
    
    self.tooltip = Tooltip.new(250)
    self.clickHandled = false
    
    return self
end

function LootScreen:takeAll()
    for i = #self.loot, 1, -1 do
        local item = self.loot[i]
        GameContext.data.playerParty:addToInventory(item)
        table.remove(self.loot, i)
    end
end

function LootScreen:finish()
    if self.onContinue then self.onContinue() end
end

function LootScreen:update(dt)
    self.takeAllBtn:update(dt)
    self.continueBtn:update(dt)
    self.tooltip:update(dt)
    
    if not love.mouse.isDown(1) then
        self.clickHandled = false
    end
end

function LootScreen:draw()
    -- Background
    love.graphics.setColor(0.05, 0.05, 0.05, 1)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf("Battle Loot", 0, 20, self.width, "center")
    
    -- Grids
    local hoveredLoot = self:drawGrid("Loot", self.loot, 50, 80, self.width - 100, 200)
    local hoveredInv = self:drawGrid("Inventory", self.playerInventory, 50, 320, self.width - 100, 200)
    
    local hovered = hoveredLoot or hoveredInv
    
    self.takeAllBtn:draw()
    self.continueBtn:draw()
    
    if hovered then
        self.tooltip:setText(hovered.name .. "\n" .. (hovered.description or ""))
        local mx, my = love.mouse.getPosition()
        self.tooltip:setPosition(mx, my)
        self.tooltip:show()
    else
        self.tooltip:hide()
    end
    self.tooltip:draw()
end

function LootScreen:drawGrid(title, items, x, y, w, h)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("line", x, y, w, h)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(title, x, y - 25)
    
    local cellSize = 128
    local padding = 5
    local cols = math.floor((w - padding) / (cellSize + padding))
    
    local mx, my = love.mouse.getPosition()
    local hoveredItem = nil
    
    for i, item in ipairs(items) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        
        local ix = x + padding + col * (cellSize + padding)
        local iy = y + padding + row * (cellSize + padding)
        
        if iy + cellSize > y + h then break end -- Clip
        
        -- Draw Item Box
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", ix, iy, cellSize, cellSize)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", ix, iy, cellSize, cellSize)
        
        -- Draw Item Icon/Text (Placeholder)
        love.graphics.print(string.sub(item.name, 1, 2), ix + 5, iy + 5)
        if item.quantity > 1 then
            love.graphics.print(tostring(item.quantity), ix + 20, iy + 20)
        end
        
        -- Hover & Click
        if mx >= ix and mx <= ix + cellSize and my >= iy and my <= iy + cellSize then
            love.graphics.setColor(1, 1, 1, 0.2)
            love.graphics.rectangle("fill", ix, iy, cellSize, cellSize)
            hoveredItem = item
            
            -- Handle Click (Take Item)
            if love.mouse.isDown(1) and not self.clickHandled then
                if title == "Loot" then
                    GameContext.data.playerParty:addToInventory(item)
                    table.remove(items, i)
                    self.clickHandled = true
                end
            end
        end
    end
    
    return hoveredItem
end

function LootScreen:mousepressed(x, y, button)
    -- Buttons handle their own input in update()
end

return LootScreen