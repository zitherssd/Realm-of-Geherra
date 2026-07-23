-- ui/widgets/equipment_panel.lua
-- Reusable actor equipment slots panel

local EquipmentPanel = {}
EquipmentPanel.__index = EquipmentPanel

local function newPixelFont(size)
    local font = love.graphics.newFont(size)
    font:setFilter("nearest", "nearest")
    return font
end

function EquipmentPanel.new(x, y, width, equipmentSystem, items)
    local self = setmetatable({}, EquipmentPanel)
    self.x = x
    self.y = y
    self.width = width
    self.equipmentSystem = equipmentSystem
    self.items = items
    self.slotRegions = {}
    self.titleFont = newPixelFont(16)
    self.slotFont = newPixelFont(13)
    self.cellSize = 64
    self.padding = 5
    return self
end

function EquipmentPanel:draw(actor, navMode, selectedSlotIndex, dragging)
    self.slotRegions = {}
    if not actor then return self.slotRegions end

    local slots = actor.availableSlots or {}
    local columns = math.floor((self.width - self.padding) / (self.cellSize + self.padding))
    if columns < 1 then columns = 1 end
    local rows = math.ceil(#slots / columns)
    local panelHeight = 30 + rows * (self.cellSize + self.padding)
    local startY = self.y + 30

    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, panelHeight)
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, panelHeight)
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.print("Equipment", self.x + 10, self.y + 8)

    for index, slotId in ipairs(slots) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local boxX = self.x + self.padding + column * (self.cellSize + self.padding)
        local boxY = startY + row * (self.cellSize + self.padding)

        table.insert(self.slotRegions, {
            slotId = slotId,
            x = boxX,
            y = boxY,
            w = self.cellSize,
            h = self.cellSize
        })

        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", boxX, boxY, self.cellSize, self.cellSize)
        if navMode == "equipment" and index == selectedSlotIndex then
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", boxX, boxY, self.cellSize, self.cellSize)
        love.graphics.setLineWidth(1)

        local itemId = self.equipmentSystem.getEquipped(actor, slotId)
        local readableSlotId = string.lower(slotId)
        local label = string.upper(string.sub(readableSlotId, 1, 1)) .. string.sub(readableSlotId, 2)
        if itemId then
            if dragging and dragging.source == "equipment" and dragging.slot == slotId then
                love.graphics.setColor(1, 1, 1, 0.3)
            else
                love.graphics.setColor(1, 1, 1, 1)
            end

            local item = self.items[itemId]
            label = item and item.name or itemId
        else
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
        end

        love.graphics.setFont(self.slotFont)
        local textWidth = self.cellSize - 8
        local _, wrappedLines = self.slotFont:getWrap(label, textWidth)
        local textHeight = #wrappedLines * self.slotFont:getHeight()
        local textY = math.floor(boxY + (self.cellSize - textHeight) / 2 + 0.5)
        love.graphics.printf(label, boxX + 4, textY, textWidth, "center")
    end

    return self.slotRegions
end

function EquipmentPanel:getSlotAt(x, y)
    for _, region in ipairs(self.slotRegions) do
        if x >= region.x and x <= region.x + region.w and y >= region.y and y <= region.y + region.h then
            return region
        end
    end
    return nil
end

return EquipmentPanel
