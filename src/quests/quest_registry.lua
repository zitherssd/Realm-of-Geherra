-- quests/quest_registry.lua
-- Central quest registry and lookup

local QuestRegistry = {}

local quests = {}

function QuestRegistry.register(questId, quest)
    quests[questId] = quest
end

function QuestRegistry.getQuest(questId)
    return quests[questId]
end

function QuestRegistry.getAllQuests()
    return quests
end

function QuestRegistry.getQuestsByGiver(giverId)
    local result = {}
    for questId, quest in pairs(quests) do
        if quest.giver == giverId then
            table.insert(result, quest)
        end
    end
    return result
end

function QuestRegistry.getQuestsByType(questType)
    local result = {}
    for questId, quest in pairs(quests) do
        if quest.type == questType then
            table.insert(result, quest)
        end
    end
    return result
end

return QuestRegistry
