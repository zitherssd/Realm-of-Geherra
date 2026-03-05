local QuestSystem = require("systems.quest_system")
local GameContext = require("game.game_context")
local NpcQuestPools = require("data.npc_quest_pools")

local QuestAvailabilitySystem = {}

local function random01()
    if love and love.math and love.math.random then
        return love.math.random()
    end
    return math.random()
end

local function getCurrentDay()
    local timeData = GameContext.data and GameContext.data.time
    return (timeData and timeData.day) or 1
end

local function getNpcRoleKey(npc)
    if not npc then return nil end
    return npc.troopType or npc.type
end

local function getProfileForNpc(npc)
    local roleKey = getNpcRoleKey(npc)
    local profile = roleKey and NpcQuestPools[roleKey]

    if profile then
        return profile
    end

    return NpcQuestPools.default
end

function QuestAvailabilitySystem.hasQuestPoolForNpc(npc)
    local profile = getProfileForNpc(npc)
    return profile and profile.questPool and #profile.questPool > 0 or false
end

local function getActiveQuest(instanceId)
    local active = GameContext.data.activeQuests
    return active and active[instanceId] or nil
end

local function getCompletedQuest(instanceId)
    local completed = GameContext.data.completedQuests
    return completed and completed[instanceId] or nil
end

local function ensureOfferState(npc)
    if not npc.questOfferState then
        npc.questOfferState = {
            status = "none"
        }
    end
    return npc.questOfferState
end

local function isQuestReadyToTurnIn(quest)
    if not quest or not quest.objectives then return false end

    local hasReportObjective = false
    for _, objective in ipairs(quest.objectives) do
        if objective.type == "report_to_giver" then
            hasReportObjective = true
            if objective.current >= objective.required then
                return false
            end
        elseif objective.current < objective.required then
            return false
        end
    end

    return hasReportObjective
end

local function clearOffer(state)
    state.offerId = nil
    state.templateId = nil
    state.generatedDay = nil
    state.expiresDay = nil
end

local function moveToCooldown(state, day, profile)
    state.status = "cooldown"
    state.questInstanceId = nil
    state.acceptedDay = nil
    state.cooldownUntilDay = day + (profile.cooldownDays or 7)
    clearOffer(state)
end

function QuestAvailabilitySystem.syncNpcOfferState(npc)
    if not npc then return nil end

    local day = getCurrentDay()
    local profile = getProfileForNpc(npc)
    local state = ensureOfferState(npc)

    if state.status == "accepted" and state.questInstanceId then
        local activeQuest = getActiveQuest(state.questInstanceId)
        if activeQuest then
            return state
        end

        if getCompletedQuest(state.questInstanceId) then
            moveToCooldown(state, day, profile)
            return state
        end

        moveToCooldown(state, day, profile)
        return state
    end

    if state.status == "available" then
        if state.expiresDay and day > state.expiresDay then
            state.status = "none"
            clearOffer(state)
        else
            return state
        end
    end

    if state.status == "cooldown" then
        if day <= (state.cooldownUntilDay or day) then
            return state
        end

        state.status = "none"
        state.cooldownUntilDay = nil
    end

    return state
end

function QuestAvailabilitySystem.rollOfferForNpc(npc)
    if not npc then return nil end

    local day = getCurrentDay()
    local profile = getProfileForNpc(npc)
    local state = QuestAvailabilitySystem.syncNpcOfferState(npc)

    if not profile or not profile.questPool or #profile.questPool == 0 then
        return state
    end

    if state.status ~= "none" then
        return state
    end

    if random01() > (profile.rollChance or 0) then
        return state
    end

    local offer = QuestSystem.generateProceduralQuestOffer(
        { id = npc.id, name = npc.name },
        { questPool = profile.questPool }
    )

    if not offer then
        return state
    end

    state.status = "available"
    state.offerId = offer.offerId
    state.templateId = offer.templateId
    state.generatedDay = day
    state.expiresDay = day + (profile.offerDurationDays or 7)

    return state
end

function QuestAvailabilitySystem.refreshLocationOffers(location)
    if not location or not location.npcs then return end

    for _, npc in ipairs(location.npcs) do
        QuestAvailabilitySystem.rollOfferForNpc(npc)
    end
end

function QuestAvailabilitySystem.acceptOfferForNpc(npc)
    if not npc then return nil end

    local day = getCurrentDay()
    local state = QuestAvailabilitySystem.syncNpcOfferState(npc)
    if not state or state.status ~= "available" or not state.templateId then
        return nil
    end

    local instanceId = QuestSystem.acceptProceduralQuestOffer({
        templateId = state.templateId,
        giverRef = { id = npc.id, name = npc.name }
    })

    if not instanceId then
        return nil
    end

    state.status = "accepted"
    state.questInstanceId = instanceId
    state.acceptedDay = day
    clearOffer(state)

    return instanceId
end

function QuestAvailabilitySystem.turnInQuestForNpc(npc)
    if not npc then return false, nil end

    local day = getCurrentDay()
    local profile = getProfileForNpc(npc)
    local state = QuestAvailabilitySystem.syncNpcOfferState(npc)

    if not state or state.status ~= "accepted" or not state.questInstanceId then
        return false, nil
    end

    local questInstanceId = state.questInstanceId
    local turnedIn = QuestSystem.reportQuestToGiver(questInstanceId, {
        id = npc.id,
        name = npc.name
    })

    if not turnedIn then
        return false, nil
    end

    state.status = "cooldown"
    state.questInstanceId = nil
    state.acceptedDay = nil
    state.cooldownUntilDay = day + (profile.cooldownDays or 7)
    clearOffer(state)

    return true, questInstanceId
end

function QuestAvailabilitySystem.getNpcQuestContext(npc)
    if not npc then
        return {
            state = "none",
            hasOffer = false,
            activeQuestInstanceId = nil,
            readyToTurnIn = false,
            templateId = nil,
            expiresDay = nil
        }
    end

    local state = QuestAvailabilitySystem.syncNpcOfferState(npc)
    local context = {
        state = state.status or "none",
        hasOffer = state.status == "available",
        activeQuestInstanceId = nil,
        readyToTurnIn = false,
        templateId = state.templateId,
        expiresDay = state.expiresDay
    }

    if state.status == "accepted" and state.questInstanceId then
        context.activeQuestInstanceId = state.questInstanceId

        local quest = getActiveQuest(state.questInstanceId)
        if quest then
            context.templateId = quest.templateId
            context.readyToTurnIn = isQuestReadyToTurnIn(quest)
        end
    end

    return context
end

return QuestAvailabilitySystem
