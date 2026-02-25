-- ui/screens/quest_log_screen.lua
-- Quest log and objectives screen

local QuestLogScreen = {}
QuestLogScreen.__index = QuestLogScreen

local GameContext = require("game.game_context")
local Button = require("ui.widgets.button")

function QuestLogScreen.new(onClose)
    local self = setmetatable({}, QuestLogScreen)
    self.onClose = onClose
    self.width = love.graphics.getWidth()
    self.height = love.graphics.getHeight()
    
    self.activeQuests = {}
    if GameContext.data.activeQuests then
        for _, quest in pairs(GameContext.data.activeQuests) do
            table.insert(self.activeQuests, quest)
        end
    end
    
    self.completedQuests = {}
    if GameContext.data.completedQuests then
        for _, quest in pairs(GameContext.data.completedQuests) do
            table.insert(self.completedQuests, quest)
        end
    end

    self.selectedQuest = self.activeQuests[1] or self.completedQuests[1]
    
    self.closeBtn = Button.new("Close", self.width - 120, 20, 100, 40, onClose)

    self.titleFont = love.graphics.newFont(32)
    self.headerFont = love.graphics.newFont(24)
    self.bodyFont = love.graphics.newFont(16)
    
    return self
end

function QuestLogScreen:update(dt)
    self.closeBtn:update(dt)
end

function QuestLogScreen:draw()
    -- Background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    
    -- Header
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.setFont(self.titleFont)
    love.graphics.print("Quest Log", 20, 20)
    
    self.closeBtn:draw()
    
    -- Layout
    local listX = 20
    local listY = 80
    local detailsX = 340
    local detailsY = 80
    
    -- Draw List
    love.graphics.setFont(self.bodyFont)
    local y = listY
    
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Active Quests", listX, y)
    y = y + 30
    
    for _, quest in ipairs(self.activeQuests) do
        if quest == self.selectedQuest then
            love.graphics.setColor(1, 1, 0.2, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.print("- " .. quest.title, listX + 10, y)
        y = y + 25
    end
    
    y = y + 20
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("Completed", listX, y)
    y = y + 30
    
    for _, quest in ipairs(self.completedQuests) do
        if quest == self.selectedQuest then
            love.graphics.setColor(0.8, 0.8, 0.2, 1)
        else
            love.graphics.setColor(0.6, 0.6, 0.6, 1)
        end
        love.graphics.print("- " .. quest.title, listX + 10, y)
        y = y + 25
    end
    
    -- Draw Details
    if self.selectedQuest then
        local q = self.selectedQuest
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(self.headerFont)
        love.graphics.print(q.title, detailsX, detailsY)
        
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print("Given by: " .. (q.giver or "Unknown"), detailsX, detailsY + 35)
        
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.printf(q.description, detailsX, detailsY + 65, self.width - detailsX - 20, "left")
        
        local objY = detailsY + 125
        love.graphics.setColor(1, 0.8, 0.2, 1)
        love.graphics.print("Objectives:", detailsX, objY)
        objY = objY + 30
        
        love.graphics.setColor(1, 1, 1, 1)
        for _, obj in ipairs(q.objectives) do
            local status = obj:isCompleted() and "[x]" or "[ ]"
            local desc = obj.description or (obj.type .. " " .. (obj.target or "?"))
            if obj.required and obj.required > 1 then
                desc = desc .. " (" .. obj.current .. "/" .. obj.required .. ")"
            end
            
            if obj:isCompleted() then
                love.graphics.setColor(0.5, 1, 0.5, 1)
            else
                love.graphics.setColor(1, 1, 1, 1)
            end
            love.graphics.print(status .. " " .. desc, detailsX, objY)
            objY = objY + 25
        end
    end
end

function QuestLogScreen:mousepressed(x, y, button)
    if button ~= 1 then return end
    
    local listX = 20
    local listY = 80
    
    -- Simple hit detection for quest list selection could be added here
    -- For now, we rely on the visual list. 
    -- A full implementation would check y coordinates against the list items drawn above.
end

return QuestLogScreen
