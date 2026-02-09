-- debug/console.lua
-- In-game debug console

local Console = {}

Console.enabled = false
Console.output = {}
Console.history = {}
Console.historyIndex = 0

function Console.toggle()
    Console.enabled = not Console.enabled
end

function Console.log(message)
    table.insert(Console.output, tostring(message))
    if #Console.output > 100 then
        table.remove(Console.output, 1)
    end
end

function Console.clear()
    Console.output = {}
end

function Console.execute(command)
    table.insert(Console.history, command)
    Console.historyIndex = #Console.history
    -- Parse and execute command
end

function Console.draw()
    if not Console.enabled then return end
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 200)
    
    love.graphics.setColor(1, 1, 1)
    for i, line in ipairs(Console.output) do
        love.graphics.print(line, 10, 10 + (i - 1) * 20)
    end
end

return Console
