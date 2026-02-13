-- game/states/dialogue_state.lua
-- Dialogue interaction state

local DialogueState = {}

local StateManager = require("core.state_manager")
local UIManager = require("ui.ui_manager")
local DialogueData = require("data.dialogue")
local DialogueScreen = require("ui.screens.dialogue_screen")

function DialogueState.enter(params)
    params = params or {}
    local target = params.target -- The entity/party we are talking to
    
    local dialogueId = params.dialogueId
    if dialogueId and DialogueData[dialogueId] then
        local dialogueTree = DialogueData[dialogueId]
        
        -- Create screen with a callback for choices
        local screen = DialogueScreen.new(dialogueTree, function(choice)
            if choice.action == "battle" then
                -- TRANSITION TO BATTLE
                StateManager.swap("battle", { enemyParty = target })
                
            elseif choice.next == "end" then
                StateManager.pop()
                
            elseif choice.next then
                -- Placeholder for navigation logic
                StateManager.pop() 
            end
        end)
        
        UIManager.registerScreen("dialogue", screen)
        UIManager.showScreen("dialogue")
    else
        print("Error: Dialogue ID not found: " .. tostring(dialogueId))
        StateManager.pop()
    end
end

function DialogueState.exit()
    UIManager.hideScreen()
end

function DialogueState.update(dt)
    UIManager.update(dt)
end

function DialogueState.draw()
    UIManager.draw()
end

function DialogueState.mousepressed(x, y, button)
    UIManager.mousepressed(x, y, button)
end

return DialogueState
