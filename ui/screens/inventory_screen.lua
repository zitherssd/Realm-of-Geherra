-- ui/screens/inventory_screen.lua
-- Inventory management screen

local InventoryScreen = {}
InventoryScreen.__index = InventoryScreen

local InventoryGrid = require("ui.widgets.inventory_grid")
local Button = require("ui.widgets.button")
local Tooltip = require("ui.widgets.tooltip")
local EquipmentSystem = require("systems.equipment_system")
local GameContext = require("game.game_context")
local EquipmentData = require("data.equipment")
local Items = require("data.items")

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
    self.dragStart = nil -- { x, y, source, index, slot, item }
    self.dragThreshold = 8

    -- Keyboard Navigation State
    self.navMode = "inventory" -- "inventory" | "equipment"
    self.selectedInventoryIndex = 1
    self.selectedSlotIndex = 1
    
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
    self.selectedSlotIndex = 1
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

    if #self.party.inventory == 0 then
        self.selectedInventoryIndex = 1
    else
        self.selectedInventoryIndex = math.max(1, math.min(self.selectedInventoryIndex, #self.party.inventory))
    end

    if self.actor and self.actor.availableSlots then
        local count = #self.actor.availableSlots
        if count > 0 then
            self.selectedSlotIndex = math.max(1, math.min(self.selectedSlotIndex, count))
        else
            self.selectedSlotIndex = 1
        end
    end

    self.grid:setSelectedIndex(self.navMode == "inventory" and self.selectedInventoryIndex or nil)

    -- Begin drag only after moving past threshold
    if self.dragStart and not self.dragging and love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        local dx = mx - self.dragStart.x
        local dy = my - self.dragStart.y
        if (dx * dx + dy * dy) >= (self.dragThreshold * self.dragThreshold) then
            self.dragging = {
                item = self.dragStart.item,
                source = self.dragStart.source,
                index = self.dragStart.index,
                slot = self.dragStart.slot
            }
        end
    end
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
        if self.navMode == "equipment" and i == self.selectedSlotIndex then
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", boxX, boxY, slotWidth, rowHeight)
        love.graphics.setLineWidth(1)
        
        -- Draw Equipped Item
        local itemId = EquipmentSystem.getEquipped(self.actor, slotId)
        if itemId then
            -- Dim if dragging this slot
            if self.dragging and self.dragging.source == "equipment" and self.dragging.slot == slotId then
                love.graphics.setColor(1, 1, 1, 0.3)
            else
                love.graphics.setColor(1, 1, 1, 1)
            end

            local item = Items[itemId]
            local name = item and item.name or itemId
            
            love.graphics.print(name, boxX + 10, boxY + 10)
        else
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
            love.graphics.print("<Empty>", boxX + 10, boxY + 10)
        end
    end
end

function InventoryScreen:_clickEquipFromInventory(index)
    local item = self.party.inventory[index]
    if not item or not self.actor then return false end

    local equipData = EquipmentData[item.id]
    if not equipData or not equipData.slot then return false end

    local hasSlot = false
    for _, slotId in ipairs(self.actor.availableSlots or {}) do
        if slotId == equipData.slot then
            hasSlot = true
            break
        end
    end
    if not hasSlot then return false end

    table.remove(self.party.inventory, index)
    local unequippedId = EquipmentSystem.equip(self.actor, item.id, equipData.slot)
    if unequippedId and Items[unequippedId] then
        table.insert(self.party.inventory, Items[unequippedId])
    end

    self.navMode = "equipment"
    for i, slotId in ipairs(self.actor.availableSlots or {}) do
        if slotId == equipData.slot then
            self.selectedSlotIndex = i
            break
        end
    end
    return true
end

function InventoryScreen:_clickUnequipSlot(slotId)
    if not self.actor then return false end
    local itemId = EquipmentSystem.unequip(self.actor, slotId)
    if itemId and Items[itemId] then
        table.insert(self.party.inventory, Items[itemId])
        self.navMode = "inventory"
        self.selectedInventoryIndex = #self.party.inventory
        return true
    end
    return false
end

function InventoryScreen:_slotAt(x, y)
    for _, region in ipairs(self.slotRegions) do
        if x >= region.x and x <= region.x + region.w and y >= region.y and y <= region.y + region.h then
            return region
        end
    end
    return nil
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
    local region = self:_slotAt(x, y)
    if region then
        local itemId = EquipmentSystem.getEquipped(self.actor, region.slotId)
        if itemId then
            self.dragStart = {
                x = x,
                y = y,
                source = "equipment",
                slot = region.slotId,
                item = Items[itemId]
            }
            self.navMode = "equipment"
            for i, slotId in ipairs(self.actor.availableSlots or {}) do
                if slotId == region.slotId then
                    self.selectedSlotIndex = i
                    break
                end
            end
            return
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
            self.dragStart = {
                x = x,
                y = y,
                source = "inventory",
                item = hoveredItem,
                index = index
            }
            self.navMode = "inventory"
            self.selectedInventoryIndex = index
        end
    end
end

function InventoryScreen:mousereleased(x, y, button)
    if button ~= 1 then return end

    local handled = false

    if self.dragging then
        -- Drag/drop path
        local region = self:_slotAt(x, y)
        if region then
            local item = self.dragging.item
            local equipData = item and EquipmentData[item.id] or nil

            if equipData and equipData.slot == region.slotId then
                if self.dragging.source == "inventory" then
                    table.remove(self.party.inventory, self.dragging.index)
                    local unequippedId = EquipmentSystem.equip(self.actor, item.id, region.slotId)
                    if unequippedId and Items[unequippedId] then
                        table.insert(self.party.inventory, Items[unequippedId])
                    end
                elseif self.dragging.source == "equipment" and self.dragging.slot ~= region.slotId then
                    local fromItemId = EquipmentSystem.getEquipped(self.actor, self.dragging.slot)
                    if fromItemId then
                        local swappedOutId = EquipmentSystem.equip(self.actor, fromItemId, region.slotId)
                        if swappedOutId then
                            EquipmentSystem.equip(self.actor, swappedOutId, self.dragging.slot)
                        else
                            EquipmentSystem.unequip(self.actor, self.dragging.slot)
                        end
                    end
                end
                handled = true
            end
        end

        if not handled and self.dragging.source == "equipment" and y > self.gridY then
            handled = self:_clickUnequipSlot(self.dragging.slot)
        end
    elseif self.dragStart then
        -- Click path
        if self.dragStart.source == "equipment" and self.dragStart.slot then
            handled = self:_clickUnequipSlot(self.dragStart.slot)
        elseif self.dragStart.source == "inventory" and self.dragStart.index then
            handled = self:_clickEquipFromInventory(self.dragStart.index)
        end
    end

    self.dragging = nil
    self.dragStart = nil
end

function InventoryScreen:keypressed(key)
    if key == "escape" then
        if self.onClose then self.onClose() end
        return
    end

    local slotCount = self.actor and #((self.actor.availableSlots or {})) or 0
    local inventoryCount = #self.party.inventory
    local cols = math.floor((self.grid.w - self.grid.padding) / (self.grid.cellSize + self.grid.padding))
    if cols < 1 then cols = 1 end

    if key == "tab" then
        self.navMode = (self.navMode == "inventory") and "equipment" or "inventory"
        return
    end

    if self.navMode == "inventory" then
        if inventoryCount == 0 then
            if key == "left" or key == "right" then
                self.navMode = "equipment"
            end
            return
        end

        if key == "left" then
            self.selectedInventoryIndex = math.max(1, self.selectedInventoryIndex - 1)
        elseif key == "right" then
            self.selectedInventoryIndex = math.min(inventoryCount, self.selectedInventoryIndex + 1)
        elseif key == "up" then
            self.selectedInventoryIndex = math.max(1, self.selectedInventoryIndex - cols)
        elseif key == "down" then
            self.selectedInventoryIndex = math.min(inventoryCount, self.selectedInventoryIndex + cols)
        elseif key == "return" or key == "kpenter" or key == "space" then
            self:_clickEquipFromInventory(self.selectedInventoryIndex)
        end
    else
        if slotCount == 0 then return end

        if key == "up" or key == "left" then
            self.selectedSlotIndex = math.max(1, self.selectedSlotIndex - 1)
        elseif key == "down" or key == "right" then
            self.selectedSlotIndex = math.min(slotCount, self.selectedSlotIndex + 1)
        elseif key == "return" or key == "kpenter" or key == "space" then
            local slotId = self.actor.availableSlots[self.selectedSlotIndex]
            if slotId then
                self:_clickUnequipSlot(slotId)
            end
        end
    end
end

return InventoryScreen
