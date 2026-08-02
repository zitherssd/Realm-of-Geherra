-- ui/widgets/inventory_grid.lua
-- Reusable grid view for items

local InventoryGrid = {}
InventoryGrid.__index = InventoryGrid

local function newPixelFont(size)
    local font = love.graphics.newFont(size)
    font:setFilter("nearest", "nearest")
    return font
end

function InventoryGrid.new(title, items, x, y, w, h, cellSize, onItemClick, header)
    local self = setmetatable({}, InventoryGrid)
    self.title = title
    self.items = items or {}
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.cellSize = cellSize or 64
    self.padding = 5
    self.rowHeight = self.cellSize + self.padding
    self.onItemClick = onItemClick
    self.header = header
    self.headerFont = newPixelFont(18)
    self.itemFont = newPixelFont(13)
    
    self.hoveredItem = nil
    self.selectedIndex = nil
    self.wasDown = false

    -- Optional scrolling (opt-in via :enableScroll())
    self.scrollEnabled = false
    self.scrollOffset = 0
    
    return self
end

function InventoryGrid:_itemStartY()
    if self.header then
        return self.y + 30 + self.padding
    end
    return self.y + self.padding
end

--------------------------------------------------------------------------------
-- Optional scrolling
--------------------------------------------------------------------------------

function InventoryGrid:enableScroll()
    self.scrollEnabled = true
end

function InventoryGrid:setScrollOffset(offset)
    self.scrollOffset = offset or 0
end

-- Number of full rows that fit in the content area
function InventoryGrid:_visibleRows()
    local contentH = (self.y + self.h) - self:_itemStartY() - self.padding
    return math.max(1, math.floor(contentH / self.rowHeight))
end

-- Total number of rows needed to render all items
function InventoryGrid:_totalRows()
    local cols = math.floor((self.w - self.padding) / self.rowHeight)
    if cols < 1 then cols = 1 end
    return math.ceil(#(self.items or {}) / cols)
end

function InventoryGrid:_maxScrollOffset()
    return math.max(0, self:_totalRows() - self:_visibleRows())
end

function InventoryGrid:wheelmoved(dx, dy)
    if not self.scrollEnabled then return end
    local maxOffset = self:_maxScrollOffset()
    self.scrollOffset = math.max(0, math.min(maxOffset, self.scrollOffset - dy))
end

function InventoryGrid:update(dt)
    local mx, my = love.mouse.getPosition()
    local isDown = love.mouse.isDown(1)

    self.hoveredItem = nil

    local cols = math.floor((self.w - self.padding) / self.rowHeight)
    if cols < 1 then cols = 1 end

    for i, item in ipairs(self.items) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)

        local ix = self.x + self.padding + col * self.rowHeight
        local iy = self:_itemStartY() + (row - self.scrollOffset) * self.rowHeight

        -- Clipping: stop once rows fall below the visible area
        if iy + self.cellSize > self.y + self.h then break end

        -- Skip rows scrolled above the visible area
        if iy + self.cellSize > self.y then
            if mx >= ix and mx <= ix + self.cellSize and my >= iy and my <= iy + self.cellSize then
                self.hoveredItem = item

                if isDown and not self.wasDown then
                    if self.onItemClick then
                        self.onItemClick(item, i)
                    end
                end
            end
        end
    end

    self.wasDown = isDown
end

function InventoryGrid:draw()
    -- Draw container
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
    
    -- Header
    if self.header then
        love.graphics.setFont(self.headerFont)
        love.graphics.setColor(1, 0.8, 0.2, 1)
        local thirdWidth = math.floor(self.w / 3)
        love.graphics.printf(self.header.title or self.title or "Inventory", self.x + 8, self.y + 5, thirdWidth - 8, "left")
        love.graphics.printf(self.header.capacity or "Capacity", self.x + thirdWidth, self.y + 5, thirdWidth, "center")

        local gold = self.header.gold
        if type(gold) == "function" then
            gold = gold()
        end
        love.graphics.printf("Gold: " .. tostring(gold or 0), self.x + (thirdWidth * 2), self.y + 5, thirdWidth - 8, "right")
    elseif self.title then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(self.title, self.x, self.y - 25)
    end

    local cols = math.floor((self.w - self.padding) / self.rowHeight)
    if cols < 1 then cols = 1 end

    -- Clip item rendering to the grid's content area
    local contentTop = self:_itemStartY()
    love.graphics.setScissor(self.x, contentTop, self.w, (self.y + self.h) - contentTop)

    for i, item in ipairs(self.items) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        
        local ix = self.x + self.padding + col * self.rowHeight
        local iy = self:_itemStartY() + (row - self.scrollOffset) * self.rowHeight
        
        if iy + self.cellSize > self.y + self.h then break end
        
        -- Draw Item Box
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", ix, iy, self.cellSize, self.cellSize)
        
        -- Highlight if hovered
        if self.hoveredItem == item then
            love.graphics.setColor(1, 1, 1, 0.2)
            love.graphics.rectangle("fill", ix, iy, self.cellSize, self.cellSize)
        end

        -- Highlight if selected (keyboard navigation)
        if self.selectedIndex == i then
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", ix, iy, self.cellSize, self.cellSize)
            love.graphics.setLineWidth(1)
        end
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", ix, iy, self.cellSize, self.cellSize)
        
        -- Draw Item Info
        local name = item.name or "???"
        love.graphics.setFont(self.itemFont)
        local textWidth = self.cellSize - 8
        local _, wrappedLines = self.itemFont:getWrap(name, textWidth)
        local textHeight = #wrappedLines * self.itemFont:getHeight()
        local textY = math.floor(iy + (self.cellSize - textHeight) / 2 + 0.5)
        love.graphics.printf(name, ix + 4, textY, textWidth, "center")
        if item.quantity and item.quantity > 1 then
            love.graphics.print(tostring(item.quantity), ix + 5, iy + self.cellSize - 20)
        end
    end

    love.graphics.setScissor()
end

function InventoryGrid:getHoveredItem()
    return self.hoveredItem
end

function InventoryGrid:setSelectedIndex(index)
    self.selectedIndex = index
end

return InventoryGrid