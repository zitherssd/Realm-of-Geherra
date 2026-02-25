-- ui/screens/dialogue_screen.lua
-- Dialogue interaction screen

local DialogueScreen = {}
local Input = require("core.input")
local GameContext = require("game.game_context")

DialogueScreen.__index = DialogueScreen

function DialogueScreen.new(dialogueTree, onChoice, options)
    local self = setmetatable({}, DialogueScreen)
    
    self.dialogueTree = dialogueTree
    self.currentNode = dialogueTree and dialogueTree.lines[1] or nil
    self.onChoice = onChoice
    self.options = options or {}
    
    self.selectedOption = 1
    self.inputCooldown = 0.2
    self.timer = 0

    self.completionPopup = self.options.completionPopup
    self.completionPopupTimer = 0
    self.completionPopupDuration = 3
    
    -- Cache fonts
    self.speakerFont = love.graphics.newFont(24)
    self.textFont = love.graphics.newFont(18)
    
    return self
end

function DialogueScreen:update(dt)
    if not self.currentNode then return end

    if self.completionPopup then
        self.completionPopupTimer = self.completionPopupTimer + dt
        if self.completionPopupTimer >= self.completionPopupDuration then
            self.completionPopup = nil
        end
    end
    
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

    if self.completionPopup then
        local alpha = 1
        local fadeDuration = 0.25
        local remaining = self.completionPopupDuration - self.completionPopupTimer
        if self.completionPopupTimer < fadeDuration then
            alpha = self.completionPopupTimer / fadeDuration
        elseif remaining < fadeDuration then
            alpha = remaining / fadeDuration
        end

        local drift = math.min(self.completionPopupTimer * 24, 36)
        local baseY = screenH - 120 - drift
        local popupLines = self.completionPopup.lines or {}

        if #popupLines > 0 then
            love.graphics.setFont(self.textFont)

            for i, line in ipairs(popupLines) do
                local lineY = baseY + ((i - 1) * 22)
                local shadowOffset = 2

                love.graphics.setColor(0, 0, 0, 0.8 * alpha)
                love.graphics.printf(line, shadowOffset, lineY + shadowOffset, screenW, "center")

                love.graphics.setColor(1, 0.9, 0.4, alpha)
                love.graphics.printf(line, 0, lineY, screenW, "center")
            end
        end
    end
    
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

    -- Draw favor if enabled
    if self.options.showFavor then
        local favor = GameContext.data.favor or 0
        love.graphics.setColor(0.8, 0.8, 1, 1) -- A light blue/purple color
        love.graphics.setFont(self.textFont)
        love.graphics.printf("Favor: " .. favor, 0, screenH - 200, screenW - 50, "right")
    end
    
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
