-- ui/screens/dialogue_screen.lua
-- Dialogue interaction screen

local DialogueScreen = {}

function DialogueScreen.show()
    -- Initialize dialogue
end

function DialogueScreen.hide()
    -- Cleanup
end

function DialogueScreen.update(dt)
    -- Update dialogue
end

function DialogueScreen.draw(dialogueTree, currentNode, selectedOptionIndex)
    if not currentNode then return end

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Draw a semi-transparent background over the world
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    -- Draw Speaker Name
    if dialogueTree and dialogueTree.speaker then
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.setFont(love.graphics.newFont(24))
        love.graphics.printf(dialogueTree.speaker, 50, screenH - 300, screenW - 100, "left")
    end
    
    -- Draw Text
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.printf(currentNode.text, 50, screenH - 260, screenW - 100, "left")
    
    -- Draw Options
    local startY = screenH - 150
    for i, option in ipairs(currentNode.options) do
        if i == selectedOptionIndex then
            love.graphics.setColor(1, 1, 0.2) -- Highlight
            love.graphics.printf("> " .. option.text, 70, startY + (i-1)*30, screenW - 140, "left")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf(option.text, 70, startY + (i-1)*30, screenW - 140, "left")
        end
    end
end

return DialogueScreen
