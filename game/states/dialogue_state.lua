-- game/states/dialogue_state.lua
-- Dialogue interaction state

local DialogueState = {}

local StateManager = require("core.state_manager")
local UIManager = require("ui.ui_manager")
local DialogueData = require("data.dialogue")
local DialogueScreen = require("ui.screens.dialogue_screen")
local LocationActions = require("systems.location_actions")
local QuestSystem = require("systems.quest_system")
local QuestAvailabilitySystem = require("systems.quest_availability_system")
local RelationshipSystem = require("systems.relationship_system")
local NpcIntroductions = require("data.npc_introductions")
local GameContext = require("game.game_context")
local WorldState = require("game.states.world_state")

local function buildSystemDialogueTree(text, nextId, speaker)
    return {
        speaker = speaker or "System",
        lines = {
            {
                text = text,
                options = {
                    { text = "Continue", next = nextId or "end" }
                }
            }
        }
    }
end

local function cloneDialogueTree(dialogueTree)
    if not dialogueTree then return nil end

    local copy = {}
    for key, value in pairs(dialogueTree) do
        if key ~= "lines" then
            copy[key] = value
        end
    end

    copy.lines = {}
    for i, line in ipairs(dialogueTree.lines or {}) do
        local lineCopy = {}
        for key, value in pairs(line) do
            if key ~= "options" then
                lineCopy[key] = value
            end
        end

        lineCopy.options = {}
        for _, option in ipairs(line.options or {}) do
            local optionCopy = {}
            for key, value in pairs(option) do
                optionCopy[key] = value
            end
            table.insert(lineCopy.options, optionCopy)
        end

        copy.lines[i] = lineCopy
    end

    return copy
end

local function shouldShowDialogueOption(option, questDialogContext, relationshipContext)
    if option.requiresQuestPool and not questDialogContext.hasQuestPool then
        return false
    end
    if option.requiresQuestOffer and not questDialogContext.hasOffer then
        return false
    end
    if option.requiresAcceptedQuest and not questDialogContext.hasAcceptedQuest then
        return false
    end
    if option.requiresReadyToTurnIn and not questDialogContext.readyToTurnIn then
        return false
    end

    if option.action == "accept_available_quest" then
        return questDialogContext.hasQuestPool and questDialogContext.hasOffer
    end
    if option.action == "turn_in_available_quest" then
        return questDialogContext.hasQuestPool and questDialogContext.readyToTurnIn
    end

    if option.requiresIntroduction and not relationshipContext.introduced then
        return false
    end

    if option.onlyBeforeIntroduction and relationshipContext.introduced then
        return false
    end

    -- While unintroduced, only allow explicit intro or clearly marked early options.
    if not relationshipContext.introduced and option.action ~= "introduce_self" then
        local isExitOption = (option.next == "end" and not option.action)
        if not option.allowBeforeIntroduction and not isExitOption then
            return false
        end
    end

    return true
end

local function getNpcIntroductionProfile(npc)
    if not npc then
        return NpcIntroductions.default or {}
    end

    local roleKey = npc.troopType or npc.type
    if roleKey and NpcIntroductions[roleKey] then
        return NpcIntroductions[roleKey]
    end

    return NpcIntroductions.default or {}
end

local function filterDialogueTreeOptions(dialogueTree, questDialogContext, relationshipContext)
    if not dialogueTree then return nil end

    local filtered = cloneDialogueTree(dialogueTree)
    for _, line in ipairs(filtered.lines or {}) do
        local allowedOptions = {}
        local hasIntroduceOption = false

        for _, option in ipairs(line.options or {}) do
            if shouldShowDialogueOption(option, questDialogContext, relationshipContext) then
                table.insert(allowedOptions, option)
                if option.action == "introduce_self" then
                    hasIntroduceOption = true
                end
            end
        end

        if not relationshipContext.introduced and not hasIntroduceOption then
            table.insert(allowedOptions, 1, {
                text = relationshipContext.introOptionText or "Introduce yourself.",
                action = "introduce_self",
                returnDialogueId = filtered.id,
                introResponseText = relationshipContext.introResponseText,
                next = filtered.id or "end"
            })
        end

        if #allowedOptions == 0 then
            allowedOptions = {
                { text = "Leave.", next = "end" }
            }
        end

        line.options = allowedOptions
    end

    return filtered
end

local function buildQuestCompletionPopup(questInstanceId)
    if not questInstanceId then return nil end

    local quest = GameContext.data.completedQuests and GameContext.data.completedQuests[questInstanceId]
    if not quest then return nil end

    local lines = {}
    local rewards = quest.rewards or {}

    if rewards.favor and rewards.favor > 0 then
        table.insert(lines, string.format("+%d Favor", rewards.favor))
    end
    if rewards.reputation then
        for factionId, amount in pairs(rewards.reputation) do
            table.insert(lines, string.format("+%d Reputation (%s)", amount, factionId))
        end
    end
    if rewards.gold and rewards.gold > 0 then
        table.insert(lines, string.format("+%d Gold", rewards.gold))
    end

    if #lines == 0 then
        return nil
    end

    return { lines = lines }
end

local function buildSpeakerRefFromTarget(target)
    local speakerRef = { id = nil, name = nil }
    if not target then
        return speakerRef
    end

    if target.getLeader then
        local leader = target:getLeader()
        if leader then
            speakerRef.id = leader.id
            speakerRef.name = leader.name
        end
    elseif target.name then
        speakerRef.id = target.id
        speakerRef.name = target.name
    end

    return speakerRef
end

local function buildNpcContexts(target)
    local questDialogContext = {
        hasQuestPool = false,
        hasOffer = false,
        hasAcceptedQuest = false,
        readyToTurnIn = false
    }
    local relationshipContext = {
        introduced = true,
        relation = 0,
        introOptionText = nil,
        introResponseText = nil
    }

    if not target or not target.name then
        return questDialogContext, relationshipContext
    end

    local introProfile = getNpcIntroductionProfile(target)
    RelationshipSystem.markMet(target)
    relationshipContext.introduced = RelationshipSystem.hasIntroduced(target)
    relationshipContext.relation = RelationshipSystem.getRelation(target)
    relationshipContext.introOptionText = introProfile.optionText
    relationshipContext.introResponseText = introProfile.responseText

    if introProfile.skip then
        RelationshipSystem.introduceToNpc(target)
        relationshipContext.introduced = true
    end

    questDialogContext.hasQuestPool = QuestAvailabilitySystem.hasQuestPoolForNpc(target)
    local npcQuestContext = QuestAvailabilitySystem.getNpcQuestContext(target)
    questDialogContext.hasOffer = npcQuestContext.hasOffer
    questDialogContext.hasAcceptedQuest = npcQuestContext.state == "accepted"
    questDialogContext.readyToTurnIn = npcQuestContext.readyToTurnIn

    return questDialogContext, relationshipContext
end

local function resolveDialogueTree(params, questSpeakerRef)
    local dialogueTree = params.dialogueTree
    if not dialogueTree and params.dialogueId then
        dialogueTree = DialogueData[params.dialogueId]
    end

    local dialogueQuestContext
    if dialogueTree and dialogueTree.checkQuest then
        dialogueQuestContext = QuestSystem.getDialogueQuestContext(dialogueTree.checkQuest, questSpeakerRef)
        local status = dialogueQuestContext.state
        if dialogueTree.states and dialogueTree.states[status] then
            local newId = dialogueTree.states[status]
            local newTree = DialogueData[newId]
            if newTree then
                dialogueTree = newTree
            end
        end
    end

    return dialogueTree, dialogueQuestContext
end

local function resolveSpeaker(target, dialogueTree)
    local speakerName
    local speakerId

    if target then
        if target.getLeader then
            local leader = target:getLeader()
            if leader then
                speakerName = leader.name
                speakerId = leader.id
            end
        elseif target.name then
            speakerName = target.name
            speakerId = target.id
        end
    end

    if not speakerName and dialogueTree then
        speakerName = dialogueTree.speaker
    end

    return speakerName, speakerId
end

local function handleDialogueAction(choice, context)
    local target = context.target
    local location = context.location
    local favorCost = context.favorCost
    local options = context.options
    local speakerId = context.speakerId
    local speakerName = context.speakerName
    local dialogueQuestContext = context.dialogueQuestContext

    local result = {
        handledNavigation = false,
        completionPopup = nil
    }

    if choice.action == "battle" then
        StateManager.swap("battle", { enemyParty = target })
    elseif choice.action == "recruit_volunteers" then
        local resultText = LocationActions.performRecruitment(location, favorCost)
        StateManager.swap("dialogue", {
            dialogueTree = buildSystemDialogueTree(resultText),
            location = location,
            showFavor = true,
            favorCost = favorCost
        })
    elseif choice.action == "pay_for_rest" then
        local paid, resultText = LocationActions.payForTavernRest(location, choice.cost)
        if paid then
            WorldState.requestRestMode(true)
            StateManager.swap("world")
            result.handledNavigation = true
            return result
        end

        StateManager.swap("dialogue", {
            dialogueTree = buildSystemDialogueTree(resultText),
            location = location
        })
    elseif choice.action == "accept_quest" then
        local questId = choice.questId
        if questId then
            QuestSystem.activateQuest(questId, {
                id = speakerId,
                name = speakerName
            })
        end
    elseif choice.action == "accept_procedural_quest" then
        if target then
            QuestAvailabilitySystem.acceptOfferForNpc(target)
        end
    elseif choice.action == "accept_available_quest" then
        if target then
            QuestAvailabilitySystem.acceptOfferForNpc(target)
        end
    elseif choice.action == "introduce_self" then
        if target then
            RelationshipSystem.introduceToNpc(target)
        end

        local introText = choice.introResponseText
            or "You exchange names and a few words before continuing."
        local returnDialogueId = choice.returnDialogueId or choice.next

        if returnDialogueId and returnDialogueId ~= "end" then
            StateManager.swap("dialogue", {
                dialogueTree = {
                    speaker = speakerName or "Local",
                    lines = {
                        {
                            text = introText,
                            options = {
                                { text = "Continue", next = returnDialogueId }
                            }
                        }
                    }
                },
                target = target,
                location = location,
                showFavor = options.showFavor,
                showGold = options.showGold
            })
            result.handledNavigation = true
            return result
        end
    elseif choice.action == "turn_in_quest" then
        local questIdOrTemplateId = choice.questInstanceId
            or (dialogueQuestContext and dialogueQuestContext.activeQuestInstanceId)
            or choice.questId

        if questIdOrTemplateId then
            local turnInSucceeded = QuestSystem.reportQuestToGiver(questIdOrTemplateId, {
                id = speakerId,
                name = speakerName
            })

            if turnInSucceeded then
                if target then
                    RelationshipSystem.addRelation(target, 2)
                end
                local completedInstanceId = (dialogueQuestContext and dialogueQuestContext.activeQuestInstanceId)
                    or questIdOrTemplateId
                result.completionPopup = buildQuestCompletionPopup(completedInstanceId)
            end
        end
    elseif choice.action == "turn_in_available_quest" then
        if target then
            local turnedIn, completedInstanceId = QuestAvailabilitySystem.turnInQuestForNpc(target)
            if turnedIn then
                RelationshipSystem.addRelation(target, 2)
                result.completionPopup = buildQuestCompletionPopup(completedInstanceId)
            end
        end
    end

    return result
end

function DialogueState.enter(params)
    params = params or {}
    local target = params.target -- The entity/party we are talking to
    local location = params.location
    local options = {
        showFavor = params.showFavor,
        showGold  = params.showGold,
        completionPopup = params.completionPopup
    }
    local favorCost = params.favorCost

    local questSpeakerRef = buildSpeakerRefFromTarget(target)
    local questDialogContext, relationshipContext = buildNpcContexts(target)

    local dialogueTree, dialogueQuestContext = resolveDialogueTree(params, questSpeakerRef)

    -- Inherit display flags from the dialogue tree definition
    if dialogueTree then
        if dialogueTree.showFavor then options.showFavor = true end
        if dialogueTree.showGold  then options.showGold  = true end
    end
    
    if dialogueTree then
        dialogueTree = filterDialogueTreeOptions(dialogueTree, questDialogContext, relationshipContext)
        local speakerName, speakerId = resolveSpeaker(target, dialogueTree)

        -- Add speaker to the dialogue tree for rendering
        dialogueTree.speaker = speakerName

        -- Create screen with a callback for choices
        local screen = DialogueScreen.new(dialogueTree, function(choice)
            local actionResult = handleDialogueAction(choice, {
                target = target,
                location = location,
                favorCost = favorCost,
                options = options,
                speakerId = speakerId,
                speakerName = speakerName,
                dialogueQuestContext = dialogueQuestContext
            })
            if actionResult.handledNavigation then
                return
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
                    showFavor = options.showFavor,
                    showGold  = options.showGold,
                    completionPopup = actionResult.completionPopup
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
