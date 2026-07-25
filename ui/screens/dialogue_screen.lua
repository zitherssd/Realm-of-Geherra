-- ui/screens/dialogue_screen.lua
-- Dialogue interaction screen
-- Supports multi-line nodes: advance through lines with Continue,
-- then show options on the final line.

local DialogueScreen = {}
local Input = require("core.input")
local GameContext = require("game.game_context")

DialogueScreen.__index = DialogueScreen

function DialogueScreen.new(dialogueTree, onChoice, onContinue, options)
    local self = setmetatable({}, DialogueScreen)
    
    self.dialogueTree = dialogueTree
    self.lines = (dialogueTree and dialogueTree.lines) or {}
    self.currentLineIndex = 1
    self.onChoice = onChoice
    self.onContinue = onContinue
    self.options = options or {}
    
    self.selectedOption = 1
    self.inputCooldown = 0.15
    self.timer = 0

    self.completionPopup = self.options.completionPopup
    self.completionPopupTimer = 0
    self.completionPopupDuration = 3

    -- Cache fonts once (not per frame)
    self.speakerFont = love.graphics.newFont(24)
    self.textFont = love.graphics.newFont(18)
    self.smallFont = love.graphics.newFont(14)
    
    return self
end

--- The current line being displayed.
function DialogueScreen:currentLine()
    return self.lines[self.currentLineIndex]
end

--- Whether the current line has options to show.
function DialogueScreen:hasOptions()
    local line = self:currentLine()
    return line and line.options and #line.options > 0
end

--- Whether there are more lines to advance through.
function DialogueScreen:hasMoreLines()
    return self.currentLineIndex < #self.lines
end

--- Advance to the next line (no options on current line).
function DialogueScreen:advanceLine()
    if self:hasMoreLines() then
        self.currentLineIndex = self.currentLineIndex + 1
        self.selectedOption = 1
        return true
    end
    return false
end

function DialogueScreen:update(dt)
    local line = self:currentLine()
    if not line then return end

    if self.completionPopup then
        self.completionPopupTimer = self.completionPopupTimer + dt
        if self.completionPopupTimer >= self.completionPopupDuration then
            self.completionPopup = nil
        end
    end
    
    self.timer = self.timer + dt
    if self.timer < self.inputCooldown then return end

    local handled = false

    if self:hasOptions() then
        -- Option navigation
        if Input.isKeyDown("up") or Input.isKeyDown("w") then
            self.selectedOption = self.selectedOption - 1
            if self.selectedOption < 1 then self.selectedOption = #line.options end
            handled = true
        elseif Input.isKeyDown("down") or Input.isKeyDown("s") then
            self.selectedOption = self.selectedOption + 1
            if self.selectedOption > #line.options then self.selectedOption = 1 end
            handled = true
        end
        
        -- Selection
        if not handled and (Input.isKeyDown("return") or Input.isKeyDown("space")) then
            local choice = line.options[self.selectedOption]
            if self.onChoice then
                self.onChoice(choice)
            end
            handled = true
        end
    else
        -- No options: advance to next line on confirm
        if Input.isKeyDown("return") or Input.isKeyDown("space") then
            if not self:advanceLine() then
                -- No more lines and no options — auto-end
                if self.onContinue then
                    self.onContinue()
                end
            end
            handled = true
        end
    end
    
    if handled then
        self.timer = 0
    end
end

function DialogueScreen:draw()
    local line = self:currentLine()
    if not line then return end

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Draw a semi-transparent background over the world
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Completion popup
    if self.completionPopup then
        self:_drawCompletionPopup(screenW, screenH)
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
    local text = line.text or ""
    love.graphics.printf(text, 50, screenH - 260, screenW - 100, "left")

    -- "Continue" hint when no options and more lines ahead
    if not self:hasOptions() and self:hasMoreLines() then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(self.smallFont)
        love.graphics.printf("(Press Space/Enter to continue)", 0, screenH - 50, screenW, "center")
    end

    -- Draw favor if enabled
    if self.options.showFavor then
        local favor = GameContext.data.favor or 0
        love.graphics.setColor(0.8, 0.8, 1, 1)
        love.graphics.setFont(self.smallFont)
        love.graphics.printf("Favor: " .. favor, 0, screenH - 200, screenW - 50, "right")
    end

    -- Draw gold if enabled
    if self.options.showGold then
        local playerParty = GameContext.data.playerParty
        local gold = playerParty and playerParty:getTreasury() or 0
        love.graphics.setColor(1, 0.85, 0.2, 1)
        love.graphics.setFont(self.smallFont)
        local goldY = self.options.showFavor and (screenH - 225) or (screenH - 200)
        love.graphics.printf("Gold: " .. gold, 0, goldY, screenW - 50, "right")
    end
    
    -- Draw Options (only on the last line of the node)
    if self:hasOptions() then
        local startY = screenH - 150
        for i, option in ipairs(line.options) do
            if i == self.selectedOption then
                love.graphics.setColor(1, 1, 0.2) -- Highlight
                love.graphics.setFont(self.textFont)
                love.graphics.printf("> " .. option.text, 70, startY + (i-1)*30, screenW - 140, "left")
            else
                love.graphics.setColor(0.7, 0.7, 0.7)
                love.graphics.setFont(self.textFont)
                love.graphics.printf(option.text, 70, startY + (i-1)*30, screenW - 140, "left")
            end
        end
    end
end

function DialogueScreen:_drawCompletionPopup(screenW, screenH)
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
        love.graphics.setFont(self.smallFont)

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

return DialogueScreen
