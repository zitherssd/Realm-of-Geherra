-- game/states/dialogue_state.lua
-- Dialogue interaction state
-- Drives conversation flow: resolves trees, filters options, handles actions.

local DialogueState = {}

local StateManager = require("src.core.state_manager")
local UIManager = require("src.ui.ui_manager")
local DialogueData = require("src.data.dialogue")
local DialogueScreen = require("src.ui.screens.dialogue_screen")
local DialogueSystem = require("src.systems.dialogue_system")
local LocationActions = require("src.systems.location_actions")
local QuestSystem = require("src.systems.quest_system")
local QuestAvailabilitySystem = require("src.systems.quest_availability_system")
local RelationshipSystem = require("src.systems.relationship_system")
local PartySystem = require("src.systems.party_system")
local TraderSystem = require("src.systems.trader_system")
-- npc_introductions was removed — all introductions now use introDialogue in dialogue trees
local GameContext = require("src.game.game_context")
local WorldState = require("src.game.states.world_state")

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

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

--- Result dialogue after rolling for recruits: offer to hire if any stepped forward.
local function buildRecruitmentResultTree(text, count)
    if count > 0 then
        return {
            speaker = "Village Elder",
            lines = {
                {
                    text = text .. " Will you take them into your company?",
                    options = {
                        { text = "Hire them (" .. LocationActions.HIRE_FAVOR_COST .. " favor).", action = "hire_recruits" },
                        { text = "Let them go.", action = "decline_recruits", next = "end" }
                    }
                }
            }
        }
    end

    return buildSystemDialogueTree(text)
end

--- Shallow-copy a dialogue tree, deep-copying only the options arrays
-- so filterDialogueTreeOptions can safely mutate them.
local function cloneDialogueTree(dialogueTree)
    if not dialogueTree then return nil end

    local copy = {}
    for key, value in pairs(dialogueTree) do
        copy[key] = value
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
    -- Evaluate dialogue variable conditions (use ["if"] since "if" is a Lua keyword)
    if option["if"] and not DialogueSystem.evaluateCondition(option["if"]) then
        return false
    end

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

    -- Introduction gating removed — all introductions handled via introDialogue in dialogue trees.
    -- NPCs without introDialogue are treated as always-introduced (see buildNpcContexts).

    return true
end

local function filterDialogueTreeOptions(dialogueTree, questDialogContext, relationshipContext, target)
    if not dialogueTree then return nil end

    local filtered = cloneDialogueTree(dialogueTree)
    for lineIndex, line in ipairs(filtered.lines or {}) do
        local allowedOptions = {}

        for _, option in ipairs(line.options or {}) do
            if shouldShowDialogueOption(option, questDialogContext, relationshipContext) then
                table.insert(allowedOptions, option)
            end
        end

        -- Auto-insertion of "Introduce yourself" removed — introductions are handled
        -- exclusively via introDialogue in dialogue trees.

        if #allowedOptions == 0 then
            allowedOptions = {
                { text = "Leave.", next = "end" }
            }
        end

        -- Any NPC merchant with stock gets a "Show me your wares." option on
        -- the first (greeting) line. This is what makes trading reusable.
        if lineIndex == 1 and target and target.inventory and #target.inventory > 0 then
            table.insert(allowedOptions, 1, {
                text = "Show me your wares.",
                action = "open_shop",
                next = "end"
            })
        end

        -- Travelling trader parties (see systems/trader_travel_system.lua)
        -- additionally offer to attack the caravan.
        if lineIndex == 1 and target and target.isTraderParty then
            table.insert(allowedOptions, {
                text = "Attack the caravan!",
                action = "battle",
                next = "end"
            })
        end

        line.options = allowedOptions
    end

    return filtered
end

local function buildQuestCompletionPopup(questInstanceId)
    if not questInstanceId then return nil end

    local quest = QuestSystem.findQuestByInstanceId(questInstanceId)
    if not quest or quest.state ~= "completed" then return nil end

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

    if target:has("party") then
        local leader = PartySystem.getLeader(target)
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

    RelationshipSystem.markMet(target)
    relationshipContext.introduced = RelationshipSystem.hasIntroduced(target)
    relationshipContext.relation = RelationshipSystem.getRelation(target)
    -- NPCs without introDialogue are always considered introduced.
    -- Those with introDialogue get introduced via the intro dialogue flow.

    questDialogContext.hasQuestPool = QuestAvailabilitySystem.hasQuestPoolForNpc(target)
    local npcQuestContext = QuestAvailabilitySystem.getNpcQuestContext(target)
    questDialogContext.hasOffer = npcQuestContext.hasOffer
    questDialogContext.hasAcceptedQuest = npcQuestContext.state == "accepted"
    questDialogContext.readyToTurnIn = npcQuestContext.readyToTurnIn
    questDialogContext.templateId = npcQuestContext.templateId
    questDialogContext.targetName = npcQuestContext.targetName

    return questDialogContext, relationshipContext
end

local function resolveDialogueTree(params, questSpeakerRef, questDialogContext)
    local dialogueTree = params.dialogueTree
    if not dialogueTree and params.dialogueId then
        dialogueTree = DialogueData[params.dialogueId]
    end

    local dialogueQuestContext

    -- Quest-state routing: checkQuest routes to a node based on a specific quest template
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

    -- Active-quest routing: checks the NPC's quest offer state for ANY active quest.
    -- Works with checkQuest — if checkQuest already routed (e.g. hunt_dogs matched),
    -- checkActiveQuest won't fire because dialogueTree has changed.
    if dialogueTree and dialogueTree.checkActiveQuest and questDialogContext then
        if questDialogContext.readyToTurnIn then
            local newId = dialogueTree.states and dialogueTree.states.ready_to_turn_in
            if newId then
                local newTree = DialogueData[newId]
                if newTree then dialogueTree = newTree end
            end
        elseif questDialogContext.hasAcceptedQuest then
            local newId = dialogueTree.states and dialogueTree.states.active
            if newId then
                local newTree = DialogueData[newId]
                if newTree then dialogueTree = newTree end
            end
        end
    end

    -- Offer routing: checkOffer routes to quest-specific offer text
    if dialogueTree and dialogueTree.checkOffer and questDialogContext then
        local templateId = questDialogContext.templateId
        if templateId and dialogueTree.checkOffer[templateId] then
            local newId = dialogueTree.checkOffer[templateId]
            local newTree = DialogueData[newId]
            if newTree then
                dialogueTree = newTree
            end
        end
    end

    -- No-offer routing: when the NPC has no offer and no active quest,
    -- route to a "nothing to offer" dialogue node
    if dialogueTree and dialogueTree.noOfferDialogue and questDialogContext then
        if not questDialogContext.hasOffer and not questDialogContext.hasAcceptedQuest then
            local newTree = DialogueData[dialogueTree.noOfferDialogue]
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
        if target:has("party") then
            local leader = PartySystem.getLeader(target)
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

    -- Apply dialogue variable mutations from the choice
    DialogueSystem.applySet(choice.set)

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
    elseif choice.action == "roll_recruitment" then
        local resultText, count = LocationActions.rollRecruitment(location)
        StateManager.swap("dialogue", {
            dialogueTree = buildRecruitmentResultTree(resultText, count),
            location = location,
            showFavor = true
        })
    elseif choice.action == "hire_recruits" then
        local hired, resultText = LocationActions.hireRecruits(location)
        StateManager.swap("dialogue", {
            dialogueTree = buildSystemDialogueTree(resultText, nil, "Village Elder"),
            location = location,
            showFavor = true
        })
    elseif choice.action == "decline_recruits" then
        LocationActions.clearPendingRecruitment(location)
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
    elseif choice.action == "buy_drink" then
        local playerParty = GameContext.data.playerParty
        local cost = choice.cost or 5
        if playerParty and PartySystem.getTreasury(playerParty) >= cost then
            PartySystem.withdrawTreasury(playerParty, cost)
            StateManager.swap("dialogue", {
                dialogueTree = buildSystemDialogueTree("You slide " .. cost .. " gold across the worn counter. The tavern keeper fills a clay mug and pushes it toward you. The ale is dark, bitter, and welcome.", nil, "Tavern Keeper"),
                location = location,
                showGold = options.showGold
            })
            result.handledNavigation = true
            return result
        else
            StateManager.swap("dialogue", {
                dialogueTree = buildSystemDialogueTree("The tavern keeper eyes your empty purse. 'Come back when you've got coin to spend.'", nil, "Tavern Keeper"),
                location = location
            })
            result.handledNavigation = true
            return result
        end
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
    elseif choice.action == "meet_npc" then
        -- Simple introduction: mark as met and let normal navigation handle the rest
        if target then
            RelationshipSystem.introduceToNpc(target)
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
    elseif choice.action == "open_shop" then
        -- Open the trading screen; return to the conversation when it closes.
        TraderSystem.maybeRefreshStock(target)
        StateManager.push("shop", { merchant = target, location = location })
        result.handledNavigation = true
        return result
    elseif choice.action == "open_world_map" then
        -- Debug: show the procedurally generated world map; return to the
        -- conversation when it closes.
        StateManager.push("world_map", {})
        result.handledNavigation = true
        return result
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
        completionPopup = params.completionPopup,
        textVars = {}
    }
    local favorCost = params.favorCost

    local questSpeakerRef = buildSpeakerRefFromTarget(target)
    local questDialogContext, relationshipContext = buildNpcContexts(target)

    -- Expose quest target name for {target} placeholder in dialogue text
    if questDialogContext.targetName then
        options.textVars.target = questDialogContext.targetName
    end

    -- Expose NPC sprite for the portrait
    if target then
        if target:has("party") then
            local leader = PartySystem.getLeader(target)
            if leader and leader.sprite then
                options.npcSprite = leader.sprite
            end
        elseif target.sprite then
            options.npcSprite = target.sprite
        end
    end

    local dialogueTree, dialogueQuestContext = resolveDialogueTree(params, questSpeakerRef, questDialogContext)

    -- Inherit display flags from the dialogue tree definition
    if dialogueTree then
        if dialogueTree.showFavor then options.showFavor = true end
        if dialogueTree.showGold  then options.showGold  = true end
    end
    
    if dialogueTree then
        -- Apply dialogue variable mutations from the tree itself (entering this node)
        DialogueSystem.applySet(dialogueTree.set)

        -- If the tree has a dedicated intro dialogue and player hasn't met the NPC yet,
        -- show the intro node first instead of the normal greeting.
        if dialogueTree.introDialogue and relationshipContext and not relationshipContext.introduced then
            local introTree = DialogueData[dialogueTree.introDialogue]
            if introTree then
                introTree = cloneDialogueTree(introTree)
                dialogueTree = introTree
            end
        end

        dialogueTree = filterDialogueTreeOptions(dialogueTree, questDialogContext, relationshipContext, target)
        local speakerName, speakerId = resolveSpeaker(target, dialogueTree)

        -- Add speaker to the dialogue tree for rendering
        dialogueTree.speaker = speakerName

        local function onChoice(choice)
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
        end

        local function onContinue()
            -- Player advanced past the last line with no options: end conversation
            StateManager.pop()
        end

        -- Create screen with callbacks for choices and multi-line continues
        local screen = DialogueScreen.new(dialogueTree, onChoice, onContinue, options)
        
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

function DialogueState.resume()
    -- Re-show the dialogue screen when returning from a pushed state (e.g. shop)
    UIManager.showScreen("dialogue")
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
