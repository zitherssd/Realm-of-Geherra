-- ui/screens/inventory_screen.lua
-- Inventory management screen

local InventoryScreen = {}
InventoryScreen.__index = InventoryScreen

local InventoryGrid = require("src.ui.widgets.inventory_grid")
local StatsPanel = require("src.ui.widgets.stats_panel")
local EquipmentPanel = require("src.ui.widgets.equipment_panel")
local AttributesPanel = require("src.ui.widgets.attributes_panel")
local Button = require("src.ui.widgets.button")
local Tooltip = require("src.ui.widgets.tooltip")
local EquipmentSystem = require("src.systems.items.equipment_system")
local Inventory = require("src.systems.items.inventory_system")
local PartySystem = require("src.systems.parties.party_system")
local GameContext = require("src.game.game_context")
local Items = require("src.data.items")

function InventoryScreen.new(party, onClose)
    local self = setmetatable({}, InventoryScreen)
    self.party = party
    self.onClose = onClose
    
    self.width = love.graphics.getWidth()
    self.height = love.graphics.getHeight()
    love.graphics.getFont():setFilter("nearest", "nearest")
    self.titleFont = love.graphics.newFont(24)
    self.titleFont:setFilter("nearest", "nearest")
    self.commanderNameFont = love.graphics.newFont(28)
    self.commanderNameFont:setFilter("nearest", "nearest")
    
    -- Identify Commanders (Player + Companions)
    self.commanders = {}
    for _, actor in ipairs(party.actors) do
        if actor:has("player") then
            table.insert(self.commanders, actor)
        end
    end
    
    -- Default to first commander (usually player)
    self.selectedCommanderIndex = 1
    self.actor = self.commanders[1]
    
    -- Layout Constants
    self.commanderSize = 72
    self.commanderOverlap = 48
    self.commanderX = 28
    self.commanderY = 48
    self.separatorY = self.commanderY + self.commanderSize + 16
    self.contentY = self.separatorY + 14
    self.leftPanelX = 28
    self.rightPanelX = math.floor(self.width * 0.48)
    self.panelGap = 14
    self.leftPanelW = self.rightPanelX - self.leftPanelX - self.panelGap
    self.rightPanelW = self.width - self.rightPanelX - 28
    self.gridY = self.contentY
    self.gridH = self.height - self.gridY - 70
    self.equipmentY = self.contentY + 190 + 14

    self.statsPanel = StatsPanel.new(self.leftPanelX, self.contentY, self.leftPanelW, 190)
    self.equipmentPanel = EquipmentPanel.new(self.leftPanelX, self.equipmentY, self.leftPanelW, EquipmentSystem, Items)
    self.attributesPanel = AttributesPanel.new(self.leftPanelX, self.equipmentY + self.equipmentPanel:getHeight(self.actor) + 14, self.leftPanelW)

    -- Commander sprite buttons
    self.commanderButtons = {}
    for i, cmdr in ipairs(self.commanders) do
        local btn = Button.new("", self.commanderX + (i - 1) * self.commanderOverlap, self.commanderY, self.commanderSize, self.commanderSize, function()
            self:selectCommander(i)
        end)
        btn.commander = cmdr
        if cmdr.sprite and love.filesystem.getInfo(cmdr.sprite) then
            btn.commanderImage = love.graphics.newImage(cmdr.sprite)
            btn.commanderImage:setFilter("nearest", "nearest")
        end
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
    self.grid = InventoryGrid.new("Inventory", self.party.inventory, self.rightPanelX, self.gridY, self.rightPanelW, self.gridH, 64, nil, {
        title = "Inventory",
        capacity = "Capacity",
        gold = function()
            return PartySystem.getTreasury(self.party)
        end
    })
    
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

function InventoryScreen:_commanderAt(x, y)
    local drawOrder = {}
    for i = 1, #self.commanderButtons do
        if i ~= self.selectedCommanderIndex then
            table.insert(drawOrder, i)
        end
    end
    if self.selectedCommanderIndex then
        table.insert(drawOrder, self.selectedCommanderIndex)
    end

    for order = #drawOrder, 1, -1 do
        local btn = self.commanderButtons[drawOrder[order]]
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            return drawOrder[order]
        end
    end
    return nil
end

function InventoryScreen:show() end
function InventoryScreen:hide() end

function InventoryScreen:update(dt)
    local mx, my = love.mouse.getPosition()
    local hoveredCommander = self:_commanderAt(mx, my)
    for i, btn in ipairs(self.commanderButtons) do
        if i == hoveredCommander then
            btn:update(dt)
        else
            btn.state = "idle"
            btn.wasDown = false
        end
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
    love.graphics.setFont(self.titleFont)
    love.graphics.printf("Character & Inventory", 0, 20, self.width, "center")
    
    -- Draw the unit stack, with the selected unit always in front.
    local drawOrder = {}
    for i = 1, #self.commanderButtons do
        if i ~= self.selectedCommanderIndex then
            table.insert(drawOrder, i)
        end
    end
    if self.selectedCommanderIndex then
        table.insert(drawOrder, self.selectedCommanderIndex)
    end

    for _, i in ipairs(drawOrder) do
        local btn = self.commanderButtons[i]
        btn:draw()
        if i == self.selectedCommanderIndex then
            love.graphics.setColor(1, 0.85, 0.2, 0.25)
            love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
        end
        if btn.commanderImage then
            love.graphics.setColor(1, 1, 1, 1)
            local scale = math.min((btn.w - 8) / btn.commanderImage:getWidth(), (btn.h - 8) / btn.commanderImage:getHeight())
            local imageW = btn.commanderImage:getWidth() * scale
            local imageH = btn.commanderImage:getHeight() * scale
            love.graphics.draw(btn.commanderImage, btn.x + (btn.w - imageW) / 2, btn.y + (btn.h - imageH) / 2, 0, scale, scale)
        else
            love.graphics.setColor(0.5, 0.8, 0.9, 1)
            love.graphics.circle("fill", btn.x + btn.w / 2, btn.y + btn.h / 2, 22)
        end
    end

    love.graphics.setColor(0.55, 0.55, 0.55, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(28, self.separatorY, self.width - 28, self.separatorY)

    love.graphics.setFont(self.commanderNameFont)
    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.printf(self.actor and self.actor.name or "", self.width - 300, self.commanderY + 12, 272, "right")
    
    -- Draw Selected Commander Details
    if self.actor then
        self.slotRegions = self.equipmentPanel:draw(self.actor, self.navMode, self.selectedSlotIndex, self.dragging)
        self.attributesPanel.y = self.equipmentPanel:getHeight(self.actor) + self.equipmentY + 14
        self.attributesPanel:draw(self.actor)
        self.statsPanel:draw(self.actor)
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
        self.tooltip:setText(self:_buildItemTooltip(hovered))
        local mx, my = love.mouse.getPosition()
        self.tooltip:setPosition(mx, my)
        self.tooltip:show()
    else
        self.tooltip:hide()
    end
    self.tooltip:draw()
end

function InventoryScreen:_getEquipSlots(itemId)
    local equipData = Items[itemId]
    if not equipData then return {} end
    if equipData.slots then return equipData.slots end
    if equipData.slot then return {equipData.slot} end
    return {}
end

function InventoryScreen:_buildItemTooltip(item)
    local lines = {
        item.name or "Unknown",
        item.description or ""
    }

    local equipData = item and item.id and Items[item.id] or nil
    if equipData then
        local slots = self:_getEquipSlots(item.id)
        if #slots > 0 then
            table.insert(lines, "Slots: " .. table.concat(slots, " / "))
        end

        if equipData.requires and equipData.requires.attributes then
            for attrName, minValue in pairs(equipData.requires.attributes) do
                local label = string.upper(string.sub(attrName, 1, 1)) .. string.sub(attrName, 2)
                local current = self.actor and self.actor.attributes and (self.actor.attributes[attrName] or 0) or 0
                table.insert(lines, string.format("Requires %s %d (Current: %d)", label, minValue, current))
            end
        end
    end

    return table.concat(lines, "\n")
end

function InventoryScreen:_chooseEquipSlot(itemId)
    if not self.actor then return nil end
    local candidates = self:_getEquipSlots(itemId)
    if #candidates == 0 then return nil end

    local actorSlots = {}
    for _, s in ipairs(self.actor.availableSlots or {}) do
        actorSlots[s] = true
    end

    -- Prefer an empty compatible slot first
    for _, slotId in ipairs(candidates) do
        if actorSlots[slotId] then
            local ok = EquipmentSystem.canEquip(self.actor, itemId, slotId)
            local equipped = EquipmentSystem.getEquipped(self.actor, slotId)
            if ok and not equipped then
                return slotId
            end
        end
    end

    -- Fallback to first compatible/equippable slot
    for _, slotId in ipairs(candidates) do
        if actorSlots[slotId] then
            local ok = EquipmentSystem.canEquip(self.actor, itemId, slotId)
            if ok then
                return slotId
            end
        end
    end

    return nil
end

function InventoryScreen:drawEquipmentList()
    self.slotRegions = self.equipmentPanel:draw(self.actor, self.navMode, self.selectedSlotIndex, self.dragging)
end

function InventoryScreen:_clickEquipFromInventory(index)
    local item = self.party.inventory[index]
    if not item or not self.actor then return false end

    local equipData = Items[item.id]
    if not equipData then return false end

    local targetSlot = self:_chooseEquipSlot(item.id)
    if not targetSlot then return false end

    local unequippedId, unequippedItem = EquipmentSystem.equip(self.actor, item, targetSlot)
    if unequippedId == false then
        return false
    end

    Inventory.removeItem(self.party, index, 1)
    if unequippedId and Items[unequippedId] then
        Inventory.addItem(self.party, unequippedItem)
    end

    self.navMode = "equipment"
    for i, slotId in ipairs(self.actor.availableSlots or {}) do
        if slotId == targetSlot then
            self.selectedSlotIndex = i
            break
        end
    end
    return true
end

function InventoryScreen:_clickUnequipSlot(slotId)
    if not self.actor then return false end
    local itemId, item = EquipmentSystem.unequip(self.actor, slotId)
    if itemId and Items[itemId] then
        Inventory.addItem(self.party, item)
        self.navMode = "inventory"
        self.selectedInventoryIndex = #self.party.inventory
        return true
    end
    return false
end

function InventoryScreen:_slotAt(x, y)
    return self.equipmentPanel:getSlotAt(x, y)
end

function InventoryScreen:drawStatsPanel()
    self.statsPanel:draw(self.actor)
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
            local equipData = item and Items[item.id] or nil

            if equipData then
                if self.dragging.source == "inventory" then
                    local unequippedId, unequippedItem = EquipmentSystem.equip(self.actor, item, region.slotId)
                    if unequippedId ~= false then
                        Inventory.removeItem(self.party, self.dragging.index, 1)
                        if unequippedId and Items[unequippedId] then
                            Inventory.addItem(self.party, unequippedItem)
                        end
                        handled = true
                    end
                elseif self.dragging.source == "equipment" and self.dragging.slot ~= region.slotId then
                    local fromItemId = EquipmentSystem.getEquipped(self.actor, self.dragging.slot)
                    if fromItemId then
                        local destinationItemId = EquipmentSystem.getEquipped(self.actor, region.slotId)
                        local fitsDestination = EquipmentSystem.canEquip(self.actor, fromItemId, region.slotId)
                        local fitsSource = not destinationItemId or
                            EquipmentSystem.canEquip(self.actor, destinationItemId, self.dragging.slot)
                        if fitsDestination and fitsSource then
                            local fromItem = EquipmentSystem.getEquippedItem(self.actor, self.dragging.slot)
                            local destinationItem = EquipmentSystem.getEquippedItem(self.actor, region.slotId)
                            EquipmentSystem.unequip(self.actor, self.dragging.slot)
                            EquipmentSystem.unequip(self.actor, region.slotId)
                            EquipmentSystem.equip(self.actor, fromItem, region.slotId)
                            if destinationItem then
                                EquipmentSystem.equip(self.actor, destinationItem, self.dragging.slot)
                            end
                            handled = true
                        else
                            -- A rejected swap must not fall through to unequipping the source.
                            self.dragging, self.dragStart = nil, nil
                            return
                        end
                    end
                end
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

function InventoryScreen:wheelmoved(x, y)
    self.statsPanel:wheelmoved(x, y)
end

return InventoryScreen
