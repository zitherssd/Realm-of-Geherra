-- ui/widgets/panel.lua
-- Themed panel — clay-tablet aesthetic per art bible
-- Parchment background, double-line border, bronze corner rivets

local Panel = {}

function Panel.new(x, y, width, height)
    local self = {
        x = x or 0,
        y = y or 0,
        width = width or 200,
        height = height or 200,
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
    local x, y, w, h = self.x, self.y, self.width, self.height

    -- Panel body — darkened parchment
    love.graphics.setColor(0.18, 0.16, 0.14, 0.95)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Outer border — Charcoal (carved stone, thick)
    love.graphics.setColor(0.14, 0.14, 0.18, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)

    -- Inner border — bronze inlay
    love.graphics.setColor(0.6, 0.4, 0.15, 1)
    love.graphics.rectangle("line", x + 3, y + 3, w - 6, h - 6)

    -- Corner rivets
    local r = 3
    love.graphics.setColor(0.7, 0.5, 0.2, 1)
    love.graphics.circle("fill", x + 4, y + 4, r)
    love.graphics.circle("fill", x + w - 4, y + 4, r)
    love.graphics.circle("fill", x + 4, y + h - 4, r)
    love.graphics.circle("fill", x + w - 4, y + h - 4, r)

    -- Children
    for _, element in ipairs(self.elements) do
        if element.draw then
            element.draw()
        end
    end
end

return Panel
