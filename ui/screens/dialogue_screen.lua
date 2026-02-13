-- ui/screens/dialogue_screen.lua
-- Dialogue interaction screen

local DialogueScreen = {}
local Input = require("core.input")

DialogueScreen.__index = DialogueScreen

function DialogueScreen.new(dialogueTree, onChoice)
    local self = setmetatable({}, DialogueScreen)
    
    self.dialogueTree = dialogueTree
    self.currentNode = dialogueTree and dialogueTree.lines[1] or nil
    self.onChoice = onChoice
    
    self.selectedOption = 1
    self.inputCooldown = 0.2
    self.timer = 0
    
    -- Cache fonts
    self.speakerFont = love.graphics.newFont(24)
    self.textFont = love.graphics.newFont(18)
    
    return self
end

function DialogueScreen:update(dt)
    if not self.currentNode then return end
    
    self.timer = self.timer + dt
    if self.timer < self.inputCooldown then return end
    
    local options = self.currentNode.options
    local handled = false
    
    -- Navigation
    if Input.isKeyDown("up") or Input.isKeyDown("w") then
        self.selectedOption = self.selectedOption - 1
        if self.selectedOption < 1 then self.selectedOption = #options end
        handled = true
    elseif Input.isKeyDown("down") or Input.isKeyDown("s") then
        self.selectedOption = self.selectedOption + 1
        if self.selectedOption > #options then self.selectedOption = 1 end
        handled = true
    end
    
    -- Selection
    if not handled and (Input.isKeyDown("return") or Input.isKeyDown("space")) then
        local choice = options[self.selectedOption]
        if self.onChoice then
            self.onChoice(choice)
        end
        handled = true
    end
    
    if handled then
        self.timer = 0
    end
end

function DialogueScreen:draw()
    local currentNode = self.currentNode
    if not currentNode then return end

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Draw a semi-transparent background over the world
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    -- Draw Speaker Name
    if self.dialogueTree and self.dialogueTree.speaker then
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.setFont(self.speakerFont)
        love.graphics.printf(self.dialogueTree.speaker, 50, screenH - 300, screenW - 100, "left")
    end
    
    -- Draw Text
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(self.textFont)
    love.graphics.printf(currentNode.text, 50, screenH - 260, screenW - 100, "left")
    
    -- Draw Options
    local startY = screenH - 150
    for i, option in ipairs(currentNode.options) do
        if i == self.selectedOption then
            love.graphics.setColor(1, 1, 0.2) -- Highlight
            love.graphics.printf("> " .. option.text, 70, startY + (i-1)*30, screenW - 140, "left")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf(option.text, 70, startY + (i-1)*30, screenW - 140, "left")
        end
    end
end

return DialogueScreen
