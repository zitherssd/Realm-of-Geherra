-- systems/quest_system.lua
-- Track quest states, objectives, and conditions

local QuestSystem = {}

-- Quest states: inactive, active, completed, failed

function QuestSystem.activateQuest(actor, questId)
    if not actor.quests then
        actor.quests = {}
    end
    actor.quests[questId] = {state = "active", progress = {}}
end

function QuestSystem.completeQuest(actor, questId)
    if not actor.quests or not actor.quests[questId] then return end
    actor.quests[questId].state = "completed"
end

function QuestSystem.failQuest(actor, questId)
    if not actor.quests or not actor.quests[questId] then return end
    actor.quests[questId].state = "failed"
end

function QuestSystem.getQuestState(actor, questId)
    if not actor.quests or not actor.quests[questId] then return "inactive" end
    return actor.quests[questId].state
end

function QuestSystem.updateQuestProgress(actor, questId, objectiveId, progress)
    if not actor.quests or not actor.quests[questId] then return end
    actor.quests[questId].progress[objectiveId] = progress
end

return QuestSystem
