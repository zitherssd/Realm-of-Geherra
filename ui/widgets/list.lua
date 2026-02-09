-- ui/widgets/list.lua
-- UI List widget

local List = {}

function List.new(x, y, width, height)
    local self = {
        x = x,
        y = y,
        width = width,
        height = height,
        items = {},
        selectedIndex = 1,
        scrollOffset = 0
    }
    return self
end

function List:addItem(item)
    table.insert(self.items, item)
end

function List:removeItem(index)
    table.remove(self.items, index)
    self.selectedIndex = math.min(self.selectedIndex, #self.items)
end

function List:getSelectedItem()
    return self.items[self.selectedIndex]
end

function List:draw()
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    local itemHeight = 20
    for i, item in ipairs(self.items) do
        if i == self.selectedIndex then
            love.graphics.setColor(0.3, 0.3, 0.5)
            love.graphics.rectangle("fill", self.x, self.y + (i - 1) * itemHeight, self.width, itemHeight)
        end
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(tostring(item), self.x + 5, self.y + (i - 1) * itemHeight + 2)
    end
end

return List
