-- systems/quest_system.lua
-- Track quest states, objectives, and conditions

local QuestSystem = {}

local QuestsData = require("data.quests")
local GameContext = require("game.game_context")
local EventBus = require("core.event_bus")
local Quest = require("quests.quest")
local Objective = require("quests.objective")
local Party = require("entities.party")
local Troop = require("entities.troop")
local Item = require("entities.item")
local ItemsData = require("data.items")
local ReputationSystem = require("systems.reputation_system")

local function _grantItemRewards(playerParty, itemsReward)
    if not playerParty or not itemsReward then return end

    if itemsReward[1] then
        for _, itemSpec in ipairs(itemsReward) do
            if itemSpec then
                local itemId = itemSpec.id or itemSpec.itemId
                local quantity = itemSpec.quantity or itemSpec.amount or 1
                local itemData = itemId and ItemsData[itemId]

                if itemData then
                    local item = Item.new(itemData.id, itemData.type)
                    item.name = itemData.name or itemData.id
                    item.description = itemData.description or ""
                    item.weight = itemData.weight or 1.0
                    item.value = itemData.value or 0
                    item.quantity = quantity
                    playerParty:addToInventory(item)
                end
            end
        end
        return
    end

    for itemId, quantity in pairs(itemsReward) do
        local itemData = ItemsData[itemId]
        if itemData then
            local item = Item.new(itemData.id, itemData.type)
            item.name = itemData.name or itemData.id
            item.description = itemData.description or ""
            item.weight = itemData.weight or 1.0
            item.value = itemData.value or 0
            item.quantity = quantity or 1
            playerParty:addToInventory(item)
        end
    end
end

function QuestSystem.init()
    -- Subscribe to relevant game events
    EventBus.subscribe("party_killed", QuestSystem.onPartyKilled)
end

function QuestSystem._normalizeGiverRef(giverRef)
    if type(giverRef) == "table" then
        return {
            id = giverRef.id,
            name = giverRef.name
        }
    end

    if type(giverRef) == "string" then
        return {
            id = nil,
            name = giverRef
        }
    end

    return {
        id = nil,
        name = nil
    }
end

function QuestSystem._isSameGiver(quest, giverRef)
    if not giverRef then return true end

    if giverRef.id then
        return quest.giverId == giverRef.id
    end

    if giverRef.name then
        return quest.giverName == giverRef.name
    end

    return true
end

function QuestSystem._nextQuestInstanceId(templateId)
    if not GameContext.data.questInstanceCounter then
        GameContext.data.questInstanceCounter = 0
    end

    GameContext.data.questInstanceCounter = GameContext.data.questInstanceCounter + 1
    return string.format("%s#%d", templateId, GameContext.data.questInstanceCounter)
end

function QuestSystem._nextQuestOfferId(templateId)
    if not GameContext.data.questOfferCounter then
        GameContext.data.questOfferCounter = 0
    end

    GameContext.data.questOfferCounter = GameContext.data.questOfferCounter + 1
    return string.format("offer:%s#%d", templateId, GameContext.data.questOfferCounter)
end

function QuestSystem._pickRandomFromList(values)
    if not values or #values == 0 then return nil end

    if love and love.math and love.math.random then
        return values[love.math.random(1, #values)]
    end

    return values[math.random(1, #values)]
end

function QuestSystem.findActiveQuestInstance(templateId, giverRef)
    if not GameContext.data.activeQuests then return nil end

    local normalizedGiver = QuestSystem._normalizeGiverRef(giverRef)
    for _, quest in pairs(GameContext.data.activeQuests) do
        if quest.templateId == templateId and QuestSystem._isSameGiver(quest, normalizedGiver) then
            return quest
        end
    end

    return nil
end

function QuestSystem.findCompletedQuestInstance(templateId, giverRef)
    if not GameContext.data.completedQuests then return nil end

    local normalizedGiver = QuestSystem._normalizeGiverRef(giverRef)
    for _, quest in pairs(GameContext.data.completedQuests) do
        if quest.templateId == templateId and QuestSystem._isSameGiver(quest, normalizedGiver) then
            return quest
        end
    end

    return nil
end

function QuestSystem.getDialogueQuestContext(templateId, giverRef)
    local context = {
        state = "inactive",
        activeQuestInstanceId = nil,
        completedQuestInstanceId = nil
    }

    local activeQuest = QuestSystem.findActiveQuestInstance(templateId, giverRef)
    if activeQuest then
        context.activeQuestInstanceId = activeQuest.instanceId
        if activeQuest:getState() == "active" and QuestSystem._isReadyToTurnIn(activeQuest) then
            context.state = "ready_to_turn_in"
        else
            context.state = activeQuest:getState()
        end
        return context
    end

    local completedQuest = QuestSystem.findCompletedQuestInstance(templateId, giverRef)
    if completedQuest then
        context.state = "completed"
        context.completedQuestInstanceId = completedQuest.instanceId
    end

    return context
end

function QuestSystem.generateProceduralQuestOffer(giverRef, options)
    local normalizedGiver = QuestSystem._normalizeGiverRef(giverRef)
    local pool = {}

    if options and options.questPool then
        for _, templateId in ipairs(options.questPool) do
            local questData = QuestsData[templateId]
            if questData and questData.procedural then
                local hasActive = QuestSystem.findActiveQuestInstance(templateId, normalizedGiver)
                if not hasActive then
                    table.insert(pool, templateId)
                end
            end
        end
    else
        for templateId, questData in pairs(QuestsData) do
            if questData.procedural then
                local hasActive = QuestSystem.findActiveQuestInstance(templateId, normalizedGiver)
                if not hasActive then
                    if questData.repeatable or not QuestSystem.findCompletedQuestInstance(templateId, normalizedGiver) then
                        table.insert(pool, templateId)
                    end
                end
            end
        end
    end

    local selectedTemplateId = QuestSystem._pickRandomFromList(pool)
    if not selectedTemplateId then
        return nil
    end

    return {
        offerId = QuestSystem._nextQuestOfferId(selectedTemplateId),
        templateId = selectedTemplateId,
        giverRef = normalizedGiver,
        source = "procedural"
    }
end

function QuestSystem.acceptProceduralQuestOffer(offer)
    if not offer or not offer.templateId then return nil end
    return QuestSystem.activateQuest(offer.templateId, offer.giverRef)
end

function QuestSystem._findActiveQuestByIdOrTemplate(questIdOrTemplateId, giverRef)
    if not GameContext.data.activeQuests then return nil end

    local direct = GameContext.data.activeQuests[questIdOrTemplateId]
    if direct then
        return direct
    end

    return QuestSystem.findActiveQuestInstance(questIdOrTemplateId, giverRef)
end

function QuestSystem._bindSpawnedPartyToObjectives(quest, templatePartyId, runtimePartyId)
    if not templatePartyId then return end

    for _, objective in ipairs(quest.objectives) do
        if objective.type == "kill_party" and objective.target == templatePartyId then
            objective.target = runtimePartyId
        end
    end
end

-- Activates a quest by creating an instance and adding it to the global context.
function QuestSystem.activateQuest(templateId, giverRef)
    local normalizedGiver = QuestSystem._normalizeGiverRef(giverRef)
    local existingInstance = QuestSystem.findActiveQuestInstance(templateId, normalizedGiver)
    if existingInstance then
        return existingInstance.instanceId
    end

    local questData = QuestsData[templateId]
    if not questData then
        print("QuestSystem: Could not find quest data for: " .. templateId)
        return
    end

    local instanceId = QuestSystem._nextQuestInstanceId(templateId)

    -- Create a new Quest instance
    local newQuest = Quest.new(instanceId, questData.title, templateId)
    newQuest.description = questData.description
    newQuest.giverId = normalizedGiver.id
    newQuest.giverName = normalizedGiver.name or questData.giver
    newQuest.giver = newQuest.giverName

    -- Remember where the quest was accepted so the quest log can point the way
    -- from the settlement, rather than acting as a live radar for the player.
    local giverLocation = QuestSystem._findGiverLocation(normalizedGiver)
    if giverLocation then
        newQuest.giverLocationName = giverLocation.name or "the village"
        newQuest.giverLocationX = giverLocation.x
        newQuest.giverLocationY = giverLocation.y
    end

    newQuest.rewards = questData.rewards
    newQuest:setState("active")

    -- Create Objective instances from data
    if questData.objectives then
        for i, objData in ipairs(questData.objectives) do
            local objective = Objective.new(tostring(i), objData.type)
            objective.target = objData.target
            objective.required = objData.required or 1
            objective.description = objData.description or ""

            -- Resolve dynamic location target at activation time
            if objData.pickTarget then
                local resolved = QuestSystem._resolvePickTarget(objData.pickTarget, newQuest)
                if resolved then
                    objective.target = resolved.id
                    objective.description = string.format("Travel to %s", resolved.name)
                    -- Remember where the target is so the quest log can point the way
                    objective.targetName = resolved.name
                    objective.targetX = resolved.x
                    objective.targetY = resolved.y
                end
            end

            newQuest:addObjective(objective)
        end
    end

    -- Add to active quests in GameContext
    if not GameContext.data.activeQuests then GameContext.data.activeQuests = {} end
    GameContext.data.activeQuests[instanceId] = newQuest
    
    -- Handle onStart actions defined in data
    if questData.onStart then
        QuestSystem._handleQuestAction(questData.onStart, newQuest)
    end

    return instanceId
end

-- Event handler for when a party is killed
function QuestSystem.onPartyKilled(partyId)
    print("QuestSystem: onPartyKilled event received for " .. tostring(partyId))
    if not GameContext.data.activeQuests then return end

    for _, quest in pairs(GameContext.data.activeQuests) do
        if quest:getState() == "active" then
            for _, objective in ipairs(quest.objectives) do
                if objective.type == "kill_party" then
                    print(string.format("QuestSystem Debug: Checking objective for quest '%s'. Target: '%s' vs Killed: '%s'", quest.title, tostring(objective.target), tostring(partyId)))
                end
                if objective.type == "kill_party" and objective.target == partyId and not objective:isCompleted() then
                    objective:advance(1)
                    print(string.format("Quest '%s' progress: kill_party %s (%d/%d)", quest.title, partyId, objective.current, objective.required))
                    QuestSystem.checkQuestCompletion(quest)
                end
            end
        end
    end
end

-- Checks if all objectives of a quest are met and completes it.
function QuestSystem.checkQuestCompletion(quest)
    if quest:isCompleted() then
        QuestSystem.completeQuest(quest.instanceId)
    end
end

function QuestSystem._isReadyToTurnIn(quest)
    local hasReportObjective = false

    for _, objective in ipairs(quest.objectives) do
        if objective.type == "report_to_giver" then
            hasReportObjective = true
            if objective:isCompleted() then
                return false
            end
        elseif not objective:isCompleted() then
            return false
        end
    end

    return hasReportObjective
end

function QuestSystem.reportQuestToGiver(questIdOrTemplateId, giverRef)
    if not GameContext.data.activeQuests then return false end

    local normalizedGiver = QuestSystem._normalizeGiverRef(giverRef)
    local quest = QuestSystem._findActiveQuestByIdOrTemplate(questIdOrTemplateId, normalizedGiver)
    if not quest or quest:getState() ~= "active" then
        return false
    end

    if not QuestSystem._isSameGiver(quest, normalizedGiver) then
        return false
    end

    for _, objective in ipairs(quest.objectives) do
        if objective.type == "report_to_giver" and not objective:isCompleted() then
            local remaining = objective.required - objective.current
            objective:advance(remaining > 0 and remaining or 1)
        end
    end

    QuestSystem.checkQuestCompletion(quest)
    return true
end

function QuestSystem.completeQuest(questId)
    if not GameContext.data.activeQuests then return end
    local quest = GameContext.data.activeQuests[questId]
    if not quest or quest:getState() ~= "active" then return end

    quest:setState("completed")
    
    -- Grant rewards
    local rewards = quest.rewards
    if rewards then
        local playerParty = GameContext.data.playerParty
        if rewards.gold and playerParty then
            playerParty:addTreasury(rewards.gold)
        end

        if rewards.favor then
            GameContext.data.favor = (GameContext.data.favor or 0) + rewards.favor
        end

        _grantItemRewards(playerParty, rewards.items)

        if rewards.reputation and playerParty then
            for factionId, amount in pairs(rewards.reputation) do
                ReputationSystem.addReputation(playerParty, factionId, amount)
            end
        end

        if rewards.unlock then
            GameContext.setGlobalFlag(rewards.unlock, true)
        end
        if rewards.unlocks then
            for _, unlockId in ipairs(rewards.unlocks) do
                GameContext.setGlobalFlag(unlockId, true)
            end
        end
    end

    -- Move from active to completed
    if not GameContext.data.completedQuests then GameContext.data.completedQuests = {} end
    GameContext.data.completedQuests[quest.instanceId] = quest
    GameContext.data.activeQuests[questId] = nil

    print("Quest Completed: " .. quest.title)
    EventBus.emit("quest_completed", quest.instanceId, quest.templateId)
end

function QuestSystem.getQuestState(templateId, giverRef)
    local context = QuestSystem.getDialogueQuestContext(templateId, giverRef)
    return context.state
end

-- Finds the location on the current map whose NPC roster contains the quest
-- giver, so the quest log can reference the place where the quest was accepted.
function QuestSystem._findGiverLocation(normalizedGiver)
    local map = GameContext.data.currentMap
    if not map or not normalizedGiver then return nil end

    for _, loc in ipairs(map:getLocations()) do
        for _, npc in ipairs(loc.npcs or {}) do
            local isGiver = false
            if normalizedGiver.id and npc.id == normalizedGiver.id then
                isGiver = true
            elseif not normalizedGiver.id and normalizedGiver.name and npc.name == normalizedGiver.name then
                isGiver = true
            end
            if isGiver then
                return loc
            end
        end
    end

    return nil
end

-- Finds a location on the current map matching criteria, preferring those nearest to the player.
function QuestSystem._resolvePickTarget(pickTarget, quest)
    local map = GameContext.data.currentMap
    if not map then return nil end

    local locationType = pickTarget.locationType
    local candidates = {}

    for _, loc in ipairs(map:getLocations()) do
        if not locationType or loc.type == locationType then
            table.insert(candidates, loc)
        end
    end

    if #candidates == 0 then
        print(string.format("QuestSystem: No locations of type '%s' found for pickTarget", tostring(locationType)))
        return nil
    end

    -- Prefer nearest to the player party
    local playerParty = GameContext.data.playerParty
    if playerParty then
        local px, py = playerParty.x or 0, playerParty.y or 0
        table.sort(candidates, function(a, b)
            local da = (a.x - px)^2 + (a.y - py)^2
            local db = (b.x - px)^2 + (b.y - py)^2
            return da < db
        end)
    end

    return candidates[1]
end

-- For a quest template, resolve the pickTarget location name (used in dialogue text).
-- This picks the target at offer-time so the NPC can mention it by name.
function QuestSystem.resolveQuestTargetName(templateId)
    local questData = QuestsData[templateId]
    if not questData or not questData.objectives then return nil end

    for _, obj in ipairs(questData.objectives) do
        if obj.pickTarget then
            local resolved = QuestSystem._resolvePickTarget(obj.pickTarget)
            return resolved and resolved.name or nil
        end
    end
    return nil
end

-- Advance travel objectives when the player enters a location.
function QuestSystem.onLocationEntered(location)
    if not location or not GameContext.data.activeQuests then return end

    for _, quest in pairs(GameContext.data.activeQuests) do
        if quest:getState() == "active" then
            for _, objective in ipairs(quest.objectives) do
                if objective.type == "travel"
                    and objective.target == location.id
                    and not objective:isCompleted()
                then
                    objective:advance(1)
                    print(string.format("Quest '%s': reached travel target '%s'", quest.title, location.id))
                    QuestSystem.checkQuestCompletion(quest)
                end
            end
        end
    end
end

-- Internal handler for quest actions (spawning, etc.)
function QuestSystem._handleQuestAction(action, quest)
    if action.type == "spawn_party" then
        local playerParty = GameContext.data.playerParty
        local map = GameContext.data.currentMap
        
        if playerParty and map then
            local basePartyId = action.partyId or "quest_party"
            local runtimePartyId = string.format("%s__%s", basePartyId, quest.instanceId)
            local party = Party.new(action.name, nil, runtimePartyId)
            print(string.format("QuestSystem: Spawning quest party '%s' with ID: '%s'", party.name, party.id))
            party.faction = action.faction or "bandits"
            
            for _, troopId in ipairs(action.troops or {}) do
                party:addActor(Troop.new(troopId))
            end
            
            local ox = action.offset and action.offset.x or 50
            local oy = action.offset and action.offset.y or 0
            party:setPosition(playerParty.x + ox, playerParty.y + oy)
            
            map:addParty(party)
            table.insert(quest.spawnedPartyIds, party.id)
            QuestSystem._bindSpawnedPartyToObjectives(quest, action.partyId, party.id)
        end
    elseif action.type == "give_item" then
        local playerParty = GameContext.data.playerParty
        if playerParty and action.itemId then
            local itemData = ItemsData[action.itemId]
            if itemData then
                local item = Item.new(itemData.id, itemData.type)
                item.name = itemData.name or itemData.id
                item.description = itemData.description or ""
                item.weight = itemData.weight or 1.0
                item.value = itemData.value or 0
                item.quantity = action.quantity or 1
                playerParty:addToInventory(item)
                print(string.format("QuestSystem: Granted item '%s' (x%d) for quest '%s'", action.itemId, action.quantity or 1, quest.instanceId))
            end
        end
    end
end

return QuestSystem
