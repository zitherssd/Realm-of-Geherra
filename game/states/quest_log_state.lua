-- game/states/quest_log_state.lua
-- State for viewing the quest log

local QuestLogState = {}
local StateManager = require("core.state_manager")
local UIManager = require("ui.ui_manager")
local QuestLogScreen = require("ui.screens.quest_log_screen")

function QuestLogState.enter()
    local screen = QuestLogScreen.new(function()
        StateManager.pop()
    end)
    UIManager.registerScreen("quest_log", screen)
    UIManager.showScreen("quest_log")
end

function QuestLogState.exit()
    UIManager.hideScreen()
end

function QuestLogState.update(dt)
    UIManager.update(dt)
end

function QuestLogState.draw()
    UIManager.draw()
end

function QuestLogState.mousepressed(x, y, button)
    UIManager.mousepressed(x, y, button)
end

return QuestLogState