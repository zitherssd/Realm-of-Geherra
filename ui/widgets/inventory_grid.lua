-- ui/widgets/inventory_grid.lua
-- Reusable grid view for items

local InventoryGrid = {}
InventoryGrid.__index = InventoryGrid

function InventoryGrid.new(title, items, x, y, w, h, cellSize, onItemClick)
    local self = setmetatable({}, InventoryGrid)
    self.title = title
    self.items = items or {}
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.cellSize = cellSize or 64
    self.padding = 5
    self.onItemClick = onItemClick
    
    self.hoveredItem = nil
    self.selectedIndex = nil
    self.wasDown = false
    
    return self
end

function InventoryGrid:update(dt)
    local mx, my = love.mouse.getPosition()
    local isDown = love.mouse.isDown(1)
    
    self.hoveredItem = nil
    
    local cols = math.floor((self.w - self.padding) / (self.cellSize + self.padding))
    if cols < 1 then cols = 1 end
    
    for i, item in ipairs(self.items) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        
        local ix = self.x + self.padding + col * (self.cellSize + self.padding)
        local iy = self.y + self.padding + row * (self.cellSize + self.padding)
        
        -- Clipping
        if iy + self.cellSize > self.y + self.h then break end
        
        if mx >= ix and mx <= ix + self.cellSize and my >= iy and my <= iy + self.cellSize then
            self.hoveredItem = item
            
            if isDown and not self.wasDown then
                if self.onItemClick then
                    self.onItemClick(item, i)
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
    
    -- Title
    if self.title then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(self.title, self.x, self.y - 25)
    end
    
    local cols = math.floor((self.w - self.padding) / (self.cellSize + self.padding))
    if cols < 1 then cols = 1 end
    
    for i, item in ipairs(self.items) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        
        local ix = self.x + self.padding + col * (self.cellSize + self.padding)
        local iy = self.y + self.padding + row * (self.cellSize + self.padding)
        
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
        love.graphics.print(string.sub(name, 1, 8), ix + 5, iy + 5)
        if item.quantity and item.quantity > 1 then
            love.graphics.print(tostring(item.quantity), ix + 5, iy + self.cellSize - 20)
        end
    end
end

function InventoryGrid:getHoveredItem()
    return self.hoveredItem
end

function InventoryGrid:setSelectedIndex(index)
    self.selectedIndex = index
end

return InventoryGrid