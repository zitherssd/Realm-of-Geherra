-- Campaign scheduling; callers decide when time may advance and handle presentation.
local GameContext = require("src.game.game_context")
local EcsWorld = require("src.ecs.world")
local EventBus = require("src.core.event_bus")
local TimeSystem = require("src.systems.campaign.time_system")
local EncounterSystem = require("src.systems.campaign.encounter_system")
local QuestSystem = require("src.systems.quests.quest_system")
local WorldEncounterSystem = require("src.systems.campaign.world_encounter_system")
local WorldActivitySystem = require("src.systems.world_activities.world_activity_system")
local GoalSystem = require("src.systems.goals.goal_system")
local Services = require("src.systems.services.service_system")
local Caravans = require("src.systems.services.caravan_system")
local Investigations = require("src.systems.services.investigation_system")
local Recovery = require("src.systems.actors.recovery")
local Treatment = require("src.systems.actors.injury_treatment")
local PartyAiSystem = require("src.systems.parties.party_ai_system")

local CampaignRuntime = {}

function CampaignRuntime.init()
    EventBus.unsubscribe("party_killed", QuestSystem.onPartyKilled)
    EventBus.unsubscribe("party_killed", EncounterSystem._onPartyKilled)
    QuestSystem.init()
    EncounterSystem.init()
end

function CampaignRuntime.beginNewGame(options)
    GameContext.init()
    local world = EcsWorld.init()
    -- Preserve the existing debug-only clock reset (including transient clock state).
    if options and options.debugCampaign then TimeSystem.reset() end
    CampaignRuntime.init()
    return world
end

function CampaignRuntime.enterWorld()
    EncounterSystem.reset()
    WorldEncounterSystem.init()
    WorldActivitySystem.init()
end

function CampaignRuntime.resumeWorld()
    EncounterSystem.reset()
end

function CampaignRuntime.advanceTime(dt)
    local elapsedWorldHours = TimeSystem.update(dt)
    return elapsedWorldHours, TimeSystem.worldHoursToSeconds(elapsedWorldHours)
end

-- Runs after manual movement, before hover inspection and actor decisions.
function CampaignRuntime.updateEncounters(elapsedWorldHours, elapsedWorldSeconds, map, playerParty, distanceTraveled)
    if elapsedWorldSeconds > 0 and distanceTraveled ~= nil then
        EncounterSystem.update(elapsedWorldSeconds, distanceTraveled)
    end
    local reserved = elapsedWorldSeconds > 0 and Recovery.encounterReservations(map, playerParty) or nil
    if elapsedWorldHours > 0 then WorldEncounterSystem.update(elapsedWorldHours, map) end
    return reserved
end

function CampaignRuntime.updateGoals(elapsedWorldSeconds, map, playerParty)
    if not map or elapsedWorldSeconds <= 0 or not EcsWorld.campaign then return end
    local world = EcsWorld.campaign
    world:__flush()
    Services.update({world = world, map = map})
    Caravans.update({world = world, map = map})
    GoalSystem.evaluate(elapsedWorldSeconds, map, playerParty)
    Caravans.updateWork({world = world, map = map})
    Investigations.updateWork({world = world, map = map})
end

function CampaignRuntime.update(elapsedWorldSeconds, map, playerParty, isResting, recoveryReservations, elapsedWorldHours)
    -- Treatment takes actual game hours; movement/recovery retain their existing simulation-second units.
    Treatment.update(elapsedWorldHours or 0, EcsWorld.campaign, recoveryReservations)
    if elapsedWorldSeconds > 0 then
        CampaignRuntime.updateGoals(elapsedWorldSeconds, map, playerParty)
        Recovery.update(elapsedWorldSeconds, map, playerParty, isResting, recoveryReservations)
        WorldActivitySystem.ensureDefaultActivities(map, playerParty)
        PartyAiSystem.update(elapsedWorldSeconds, map, playerParty)
    end
    -- Terminal activities release ownership even on idle/zero-scale frames.
    WorldActivitySystem.update(elapsedWorldSeconds, map, playerParty)
end

return CampaignRuntime
