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

function QuestSystem.init()
    -- Subscribe to relevant game events
    EventBus.subscribe("party_killed", QuestSystem.onPartyKilled)
end

-- Activates a quest by creating an instance and adding it to the global context.
function QuestSystem.activateQuest(questId, giverName)
    if QuestSystem.getQuestState(questId) ~= "inactive" then
        print("QuestSystem: Attempted to activate quest that is not inactive: " .. questId)
        return
    end

    local questData = QuestsData[questId]
    if not questData then
        print("QuestSystem: Could not find quest data for: " .. questId)
        return
    end

    -- Create a new Quest instance
    local newQuest = Quest.new(questId, questData.title)
    newQuest.description = questData.description
    newQuest.giver = giverName or questData.giver
    newQuest.rewards = questData.rewards
    newQuest:setState("active")

    -- Create Objective instances from data
    if questData.objectives then
        for i, objData in ipairs(questData.objectives) do
            local objective = Objective.new(tostring(i), objData.type)
            objective.target = objData.target
            objective.required = objData.required or 1
            objective.description = objData.description or ""
            newQuest:addObjective(objective)
        end
    end

    -- Add to active quests in GameContext
    if not GameContext.data.activeQuests then GameContext.data.activeQuests = {} end
    GameContext.data.activeQuests[questId] = newQuest
    
    -- Handle onStart actions defined in data
    if questData.onStart then
        QuestSystem._handleQuestAction(questData.onStart)
    end
end

-- Event handler for when a party is killed
function QuestSystem.onPartyKilled(partyId)
    print("QuestSystem: onPartyKilled event received for " .. tostring(partyId))
    if not GameContext.data.activeQuests then return end

    for questId, quest in pairs(GameContext.data.activeQuests) do
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
        QuestSystem.completeQuest(quest.id)
    end
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
        -- TODO: Add item and reputation rewards
    end

    -- Move from active to completed
    if not GameContext.data.completedQuests then GameContext.data.completedQuests = {} end
    GameContext.data.completedQuests[questId] = quest
    GameContext.data.activeQuests[questId] = nil

    print("Quest Completed: " .. quest.title)
    EventBus.emit("quest_completed", questId)
end

function QuestSystem.getQuestState(questId)
    if GameContext.data.completedQuests and GameContext.data.completedQuests[questId] then
        return "completed"
    end
    if GameContext.data.activeQuests and GameContext.data.activeQuests[questId] then
        return GameContext.data.activeQuests[questId]:getState()
    end
    return "inactive"
end

-- Internal handler for quest actions (spawning, etc.)
function QuestSystem._handleQuestAction(action)
    if action.type == "spawn_party" then
        local playerParty = GameContext.data.playerParty
        local map = GameContext.data.currentMap
        
        if playerParty and map then
            local party = Party.new(action.name, nil, action.partyId)
            print(string.format("QuestSystem: Spawning quest party '%s' with ID: '%s'", party.name, party.id))
            party.faction = action.faction or "bandits"
            
            for _, troopId in ipairs(action.troops or {}) do
                party:addActor(Troop.new(troopId))
            end
            
            local ox = action.offset and action.offset.x or 50
            local oy = action.offset and action.offset.y or 0
            party:setPosition(playerParty.x + ox, playerParty.y + oy)
            
            map:addParty(party)
        end
    end
end

return QuestSystem
