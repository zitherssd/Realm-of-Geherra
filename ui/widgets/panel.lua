-- ui/widgets/panel.lua
-- UI Panel widget

local Panel = {}

function Panel.new(x, y, width, height)
    local self = {
        x = x,
        y = y,
        width = width,
        height = height,
        elements = {}
    }
    return self
end

function Panel:addElement(element)
    table.insert(self.elements, element)
end

function Panel:update(dt)
    for _, element in ipairs(self.elements) do
        if element.update then
            element.update(dt)
        end
    end
end

function Panel:draw()
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    for _, element in ipairs(self.elements) do
        if element.draw then
            element.draw()
        end
    end
end

return Panel
