-- game/states/dialogue_state.lua
-- Dialogue interaction state

local DialogueState = {}

local Input = require("core.input")
local StateManager = require("core.state_manager")
local DialogueData = require("data.dialogue")
local DialogueScreen = require("ui.screens.dialogue_screen")

DialogueState.target = nil
DialogueState.currentDialogue = nil
DialogueState.currentNode = nil
DialogueState.selectedOption = 1
DialogueState.inputCooldown = 0.2
DialogueState.timer = 0

function DialogueState.enter(params)
    params = params or {}
    DialogueState.target = params.target -- The entity/party we are talking to
    
    local dialogueId = params.dialogueId
    if dialogueId and DialogueData[dialogueId] then
        DialogueState.currentDialogue = DialogueData[dialogueId]
        DialogueState.currentNode = DialogueState.currentDialogue.lines[1]
        DialogueState.selectedOption = 1
        DialogueScreen.show()
        DialogueState.timer = 0
    else
        print("Error: Dialogue ID not found: " .. tostring(dialogueId))
        StateManager.pop()
    end
end

function DialogueState.exit()
    DialogueState.target = nil
    DialogueState.currentDialogue = nil
    DialogueState.currentNode = nil
    DialogueScreen.hide()
end

function DialogueState.update(dt)
    if not DialogueState.currentNode then return end
    
    DialogueState.timer = DialogueState.timer + dt
    if DialogueState.timer < DialogueState.inputCooldown then return end
    
    local options = DialogueState.currentNode.options
    local handled = false
    
    -- Navigation
    if Input.isKeyDown("up") or Input.isKeyDown("w") then
        DialogueState.selectedOption = DialogueState.selectedOption - 1
        if DialogueState.selectedOption < 1 then DialogueState.selectedOption = #options end
        handled = true
    elseif Input.isKeyDown("down") or Input.isKeyDown("s") then
        DialogueState.selectedOption = DialogueState.selectedOption + 1
        if DialogueState.selectedOption > #options then DialogueState.selectedOption = 1 end
        handled = true
    end
    
    -- Selection
    if not handled and (Input.isKeyDown("return") or Input.isKeyDown("space")) then
        local choice = options[DialogueState.selectedOption]
        
        if choice.action == "battle" then
            -- TRANSITION TO BATTLE
            -- We swap so we don't return to dialogue after battle
            StateManager.swap("battle", { enemyParty = DialogueState.target })
            
        elseif choice.next == "end" then
            StateManager.pop()
            
        elseif choice.next then
            -- Simple navigation: In a full system, find node by ID.
            -- Here we just exit if logic isn't fully implemented for tree traversal
            StateManager.pop() 
        end
        handled = true
    end
    
    if handled then
        DialogueState.timer = 0
    end
end

function DialogueState.draw()
    DialogueScreen.draw(DialogueState.currentDialogue, DialogueState.currentNode, DialogueState.selectedOption)
end

return DialogueState
