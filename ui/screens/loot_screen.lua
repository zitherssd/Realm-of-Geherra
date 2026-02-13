-- ui/screens/loot_screen.lua
-- Screen for looting items after battle

local LootScreen = {}
local Button = require("ui.widgets.button")
local Tooltip = require("ui.widgets.tooltip")
local InventoryGrid = require("ui.widgets.inventory_grid")
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
    
    -- Initialize Grids
    self.lootGrid = InventoryGrid.new("Loot", self.loot, 50, 80, self.width - 100, 200, 128, function(item, index)
        GameContext.data.playerParty:addToInventory(item)
        table.remove(self.loot, index)
    end)
    
    self.invGrid = InventoryGrid.new("Inventory", self.playerInventory, 50, 320, self.width - 100, 200, 128, nil)
    
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
    self.lootGrid:update(dt)
    self.invGrid:update(dt)
end

function LootScreen:draw()
    -- Background
    love.graphics.setColor(0.05, 0.05, 0.05, 1)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf("Battle Loot", 0, 20, self.width, "center")
    
    -- Grids
    self.lootGrid:draw()
    self.invGrid:draw()
    
    local hoveredLoot = self.lootGrid:getHoveredItem()
    local hoveredInv = self.invGrid:getHoveredItem()
    
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

function LootScreen:mousepressed(x, y, button)
    -- Buttons handle their own input in update()
end

return LootScreen