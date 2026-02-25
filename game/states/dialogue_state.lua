-- game/states/dialogue_state.lua
-- Dialogue interaction state

local DialogueState = {}

local StateManager = require("core.state_manager")
local UIManager = require("ui.ui_manager")
local DialogueData = require("data.dialogue")
local DialogueScreen = require("ui.screens.dialogue_screen")
local LocationActions = require("systems.location_actions")
local QuestSystem = require("systems.quest_system")

function DialogueState.enter(params)
    params = params or {}
    local target = params.target -- The entity/party we are talking to
    local location = params.location
    local options = { showFavor = params.showFavor }
    local favorCost = params.favorCost

    local dialogueTree = params.dialogueTree
    if not dialogueTree and params.dialogueId then
        dialogueTree = DialogueData[params.dialogueId]
    end

    -- Check for dynamic redirects based on quest state
    if dialogueTree and dialogueTree.checkQuest then
        local status = QuestSystem.getQuestState(dialogueTree.checkQuest)
        if dialogueTree.states and dialogueTree.states[status] then
            local newId = dialogueTree.states[status]
            local newTree = DialogueData[newId]
            if newTree then dialogueTree = newTree end
        end
    end
    
    if dialogueTree then
        local speakerName
        if target then
            -- Duck-typing: if it has a getLeader method, we assume it's a Party.
            if target.getLeader then
                local leader = target:getLeader()
                if leader then
                    speakerName = leader.name
                end
            -- Otherwise, assume it's an NPC or other entity with a name.
            elseif target.name then
                speakerName = target.name
            end
        end

        -- Fallback to the hardcoded name in the dialogue file (which is good for safety)
        if not speakerName then
            speakerName = dialogueTree.speaker
        end

        -- Add speaker to the dialogue tree for rendering
        dialogueTree.speaker = speakerName

        -- Create screen with a callback for choices
        local screen = DialogueScreen.new(dialogueTree, function(choice)
            if choice.action == "battle" then
                -- TRANSITION TO BATTLE
                StateManager.swap("battle", { enemyParty = target })
            elseif choice.action == "recruit_volunteers" then
                local resultText = LocationActions.performRecruitment(location, favorCost)
                StateManager.swap("dialogue", { -- Use swap to replace current dialogue
                    dialogueTree = {
                        speaker = "System",
                        lines = { { text = resultText, options = {{ text = "Continue", next = "end" }} } }
                    },
                    location = location, -- pass location along if needed for other actions
                    showFavor = true,
                    favorCost = favorCost
                })
            elseif choice.action == "accept_quest" then
                local questId = choice.questId
                if questId then
                    QuestSystem.activateQuest(questId, speakerName)
                end
            end

            -- Navigation Logic
            if choice.next == "end" then
                StateManager.pop()
                
            elseif choice.next then
                -- Navigate to next dialogue node by swapping state
                StateManager.swap("dialogue", {
                    dialogueId = choice.next,
                    target = target,
                    location = location,
                    showFavor = options.showFavor
                })
            end
        end, options)
        
        UIManager.registerScreen("dialogue", screen)
        UIManager.showScreen("dialogue")
    else
        print("Error: Dialogue ID not found or invalid tree")
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
