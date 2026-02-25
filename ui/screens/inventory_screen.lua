-- ui/screens/inventory_screen.lua
-- Inventory management screen

local InventoryScreen = {}
InventoryScreen.__index = InventoryScreen

local InventoryGrid = require("ui.widgets.inventory_grid")
local Button = require("ui.widgets.button")
local Tooltip = require("ui.widgets.tooltip")
local EquipmentSystem = require("systems.equipment_system")
local GameContext = require("game.game_context")

function InventoryScreen.new(party, onClose)
    local self = setmetatable({}, InventoryScreen)
    self.party = party
    self.onClose = onClose
    
    self.width = love.graphics.getWidth()
    self.height = love.graphics.getHeight()
    
    -- Identify Commanders (Player + Companions)
    self.commanders = {}
    for _, actor in ipairs(party.actors) do
        if actor:hasTag("player") or actor:hasTag("companion") then
            table.insert(self.commanders, actor)
        end
    end
    
    -- Default to first commander (usually player)
    self.selectedCommanderIndex = 1
    self.actor = self.commanders[1]
    
    -- Layout Constants
    self.gridY = self.height / 2
    self.gridH = self.height / 2 - 100
    
    -- Commander Tabs
    self.commanderButtons = {}
    local btnW = 150
    for i, cmdr in ipairs(self.commanders) do
        local btn = Button.new(cmdr.name, 50 + (i-1)*(btnW+10), 50, btnW, 30, function()
            self:selectCommander(i)
        end)
        table.insert(self.commanderButtons, btn)
    end
    
    -- Drag State
    self.dragging = nil -- { item, source="inventory"|"equipment", index=number, slot=id }
    
    -- Inventory Grid (Bottom Half)
    -- We pass nil for onClick because we handle input globally in this screen for drag/drop
    self.grid = InventoryGrid.new("Party Inventory", self.party.inventory, 50, self.gridY, self.width - 100, self.gridH, 64, nil)
    
    self.closeBtn = Button.new("Close", self.width/2 - 50, self.height - 80, 100, 40, onClose)
    self.tooltip = Tooltip.new(250)
    
    -- Cache slot regions for hit detection
    self.slotRegions = {} 
    
    return self
end

function InventoryScreen:selectCommander(index)
    self.selectedCommanderIndex = index
    self.actor = self.commanders[index]
end

function InventoryScreen:show() end
function InventoryScreen:hide() end

function InventoryScreen:update(dt)
    for _, btn in ipairs(self.commanderButtons) do
        btn:update(dt)
    end
    self.grid:update(dt)
    self.closeBtn:update(dt)
    self.tooltip:update(dt)
end

function InventoryScreen:draw()
    -- Background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.printf("Character & Inventory", 0, 20, self.width, "center")
    
    -- Draw Commander Tabs
    for i, btn in ipairs(self.commanderButtons) do
        -- Highlight selected
        if i == self.selectedCommanderIndex then
            love.graphics.setColor(1, 1, 0, 0.2)
            love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
        end
        btn:draw()
    end
    
    -- Draw Selected Commander Details
    if self.actor then
        self:drawEquipmentList()
        self:drawStatsPanel()
    end
    
    self.grid:draw()
    self.closeBtn:draw()
    
    -- Draw Dragged Item
    if self.dragging then
        local mx, my = love.mouse.getPosition()
        love.graphics.setColor(1, 1, 1, 0.8)
        -- Draw icon placeholder
        love.graphics.rectangle("fill", mx - 32, my - 32, 64, 64)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.print(string.sub(self.dragging.item.name, 1, 5), mx - 28, my - 10)
    end
    
    -- Tooltip Logic
    local hovered = nil
    
    -- Check slots for hover
    if not self.dragging and self.actor then
        local mx, my = love.mouse.getPosition()
        for _, region in ipairs(self.slotRegions) do
            if mx >= region.x and mx <= region.x + region.w and my >= region.y and my <= region.y + region.h then
                local itemId = EquipmentSystem.getEquipped(self.actor, region.slotId)
                if itemId then
                    local Items = require("data.items")
                    hovered = Items[itemId]
                end
            end
        end
    end
    
    if not hovered then
        hovered = self.grid:getHoveredItem()
    end
    
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

function InventoryScreen:drawEquipmentList()
    local startX = 50
    local startY = 100
    local rowHeight = 40
    local labelWidth = 120
    local slotWidth = 250
    
    self.slotRegions = {} -- Reset regions
    
    love.graphics.setFont(love.graphics.newFont(16))
    
    for i, slotId in ipairs(self.actor.availableSlots or {}) do
        local y = startY + (i-1) * (rowHeight + 5)
        
        -- Draw Label
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print(slotId:upper(), startX, y + 10)
        
        -- Draw Slot Box
        local boxX = startX + labelWidth
        local boxY = y
        
        -- Store region for input
        table.insert(self.slotRegions, {slotId = slotId, x = boxX, y = boxY, w = slotWidth, h = rowHeight})
        
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", boxX, boxY, slotWidth, rowHeight)
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.rectangle("line", boxX, boxY, slotWidth, rowHeight)
        
        -- Draw Equipped Item
        local itemId = EquipmentSystem.getEquipped(self.actor, slotId)
        if itemId then
            -- Dim if dragging this slot
            if self.dragging and self.dragging.source == "equipment" and self.dragging.slot == slotId then
                love.graphics.setColor(1, 1, 1, 0.3)
            else
                love.graphics.setColor(1, 1, 1, 1)
            end
            
            local Items = require("data.items")
            local item = Items[itemId]
            local name = item and item.name or itemId
            
            love.graphics.print(name, boxX + 10, boxY + 10)
        else
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
            love.graphics.print("<Empty>", boxX + 10, boxY + 10)
        end
    end
end

function InventoryScreen:drawStatsPanel()
    local panelX = self.width / 2 + 20
    local panelY = 100
    local panelW = self.width / 2 - 70
    local panelH = self.gridY - 120
    
    -- Panel Background
    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH)
    
    -- Title
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.print("Stats", panelX + 10, panelY + 10)
    
    -- Stats List
    local stats = self.actor.stats or {}
    local y = panelY + 40
    local lineHeight = 25
    
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    for k, v in pairs(stats) do
        love.graphics.print(k:upper() .. ": " .. tostring(v), panelX + 20, y)
        y = y + lineHeight
    end
    
    love.graphics.print("LEVEL: " .. (self.actor.level or 1), panelX + 20, y + 10)
    y = y + lineHeight + 20

    -- Attributes
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.print("Attributes", panelX + 10, y)
    y = y + 30
    love.graphics.setColor(0.9, 0.9, 0.9, 1)

    local attributes = {
        "command", "oratory", "navigation", "tracking", 
        "shadowcraft", "divination", "engineering"
    }
    
    for _, attrName in ipairs(attributes) do
        love.graphics.print(string.upper(string.sub(attrName, 1, 1)) .. string.sub(attrName, 2), panelX + 20, y)
        
        local level = self.actor.attributes[attrName] or 0
        
        -- Draw the boxes
        for j = 1, 4 do
            local boxX = panelX + 150 + (j - 1) * 25
            if j <= level then
                love.graphics.rectangle("fill", boxX, y + 5, 20, 15)
            else
                love.graphics.rectangle("line", boxX, y + 5, 20, 15)
            end
        end
        y = y + lineHeight
    end
end

function InventoryScreen:mousepressed(x, y, button)
    if button ~= 1 then return end
    
    -- 1. Check Equipment Slots
    for _, region in ipairs(self.slotRegions) do
        if x >= region.x and x <= region.x + region.w and y >= region.y and y <= region.y + region.h then
            local itemId = EquipmentSystem.getEquipped(self.actor, region.slotId)
            if itemId then
                -- Start Dragging from Equipment
                local Items = require("data.items")
                local item = Items[itemId] -- Reconstruct item object from data
                -- Note: In a full system, we'd want the specific instance if items have unique stats
                
                self.dragging = {
                    item = item,
                    source = "equipment",
                    slot = region.slotId
                }
                return
            end
        end
    end
    
    -- 2. Check Inventory Grid
    local hoveredItem = self.grid:getHoveredItem()
    if hoveredItem then
        -- Find index
        local index = -1
        for i, v in ipairs(self.party.inventory) do
            if v == hoveredItem then index = i break end
        end
        
        if index > 0 then
            self.dragging = {
                item = hoveredItem,
                source = "inventory",
                index = index
            }
        end
    end
end

function InventoryScreen:mousereleased(x, y, button)
    if button ~= 1 or not self.dragging then return end
    
    local handled = false
    
    -- 1. Drop on Equipment Slot
    for _, region in ipairs(self.slotRegions) do
        if x >= region.x and x <= region.x + region.w and y >= region.y and y <= region.y + region.h then
            -- Check if item fits slot
            local item = self.dragging.item
            -- Simple check: item.type matches slot? Or item.slot matches slot.id?
            -- data/items.lua doesn't have 'slot', data/equipment.lua does.
            -- We need to check compatibility.
            local EquipmentData = require("data.equipment")
            local equipData = EquipmentData[item.id]
            
            if equipData and equipData.slot == region.slotId then
                -- Valid Drop
                if self.dragging.source == "inventory" then
                    -- Remove from inventory
                    table.remove(self.party.inventory, self.dragging.index)
                    -- Equip (swapping if needed)
                    local unequippedId = EquipmentSystem.equip(self.actor, item.id, region.slotId)
                    if unequippedId then
                        -- Return unequipped item to inventory
                        local Items = require("data.items") -- Reconstruct
                        table.insert(self.party.inventory, Items[unequippedId]) -- Simplified
                    end
                elseif self.dragging.source == "equipment" then
                    -- Move between slots? (Rarely happens unless slots are identical types)
                end
                handled = true
            end
        end
    end
    
    -- 2. Drop on Inventory Grid (Unequip)
    if not handled and self.dragging.source == "equipment" then
        -- Check if over grid area
        if y > self.gridY then
            local itemId = EquipmentSystem.unequip(self.actor, self.dragging.slot)
            if itemId then
                local Items = require("data.items")
                table.insert(self.party.inventory, Items[itemId])
            end
            handled = true
        end
    end
    
    self.dragging = nil
end

return InventoryScreen
