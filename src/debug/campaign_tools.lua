-- Debug actions resolve IDs at use time and call the normal campaign APIs.
local Mode = require("src.debug.mode")
local EcsWorld = require("src.ecs.world")
local PartySystem = require("src.systems.parties.party_system")
local GoalSystem = require("src.systems.goals.goal_system")
local Activities = require("src.systems.world_activities.world_activity_system")
local GameContext = require("src.game.game_context")
local Knowledge = require("src.systems.knowledge.knowledge_system")

local Services = require("src.systems.services.service_system")
local Tools = {}

function Tools.searchHere(map, partyId)
    local actor, reason = Tools.editableLeader(map, partyId, nil, true)
    if not actor then return false, reason end
    if Services.hasObligation(actor, {world = actor.__world, map = map}) then
        return false, "Resolve the accepted service before assigning debug Search."
    end
    local party = Tools.resolve(map, "party", partyId)
    local started, err = Activities.start(party, "search", {originX = party.x, originY = party.y,
        radius = 150, durationSeconds = require("src.systems.campaign.time_system").worldHoursToSeconds(6)}, map)
    return started, err or "Search started: radius 150, six world hours. Advance world time."
end

function Tools.enableCaravan(map, actorId, sponsorRole)
    if not Mode.enabled then return false, "Enable debug mode with F1 first." end
    local actor = Tools.resolve(map, "unit", actorId)
    if not actor or actor.player or not actor.memory or (actor.hp or 0) <= 0 then
        return false, "Select a living important NPC."
    end
    actor:ensure("npc_goals")
    actor.npc_goals.capabilities[sponsorRole and "caravanFormation" or "leadCaravan"] = true
    local kind = sponsorRole and "acquire_gold" or "provide_service"
    for _, goal in ipairs(actor.npc_goals.goals) do
        if goal.type == kind then return true, "Capability enabled; existing goal retained." end
    end
    local fundsOwner = Services.getParty(actor, actor.__world) or actor
    GoalSystem.addGoal(actor, sponsorRole and {type = kind, amount = (fundsOwner.treasury or 0) + 1000} or {type = kind})
    return true, "Capability and goal added. Advance world time; sponsors need 500 available gold."
end

function Tools.addRecoveryGoal(map, actorId)
    if not Mode.enabled then return false, "Enable debug mode with F1 first." end
    local actor = Tools.resolve(map, "unit", actorId)
    if not actor or actor.player or not actor.memory or (actor.hp or 0) <= 0 then
        return false, "Select a living important NPC."
    end
    for _, goal in ipairs(actor.npc_goals and actor.npc_goals.goals or {}) do
        if goal.type == "rest_and_recover" then return true, "Recovery goal already assigned." end
    end
    GoalSystem.addGoal(actor, {type = "rest_and_recover"})
    return true, "Recovery goal added. Advance world time to evaluate it."
end

-- Append a local healing goal without replacing capabilities, goals or runtime state.
function Tools.addHealingService(map, actorId)
    if not Mode.enabled then return false, "Enable debug mode with F1 first." end
    local actor = Tools.resolve(map, "unit", actorId)
    if not actor or actor.player or not actor.memory or (actor.hp or 0) <= 0 then
        return false, "Select a living important NPC."
    end
    actor:ensure("npc_goals")
    actor.npc_goals.capabilities.heal = true
    for _, goal in ipairs(actor.npc_goals.goals) do
        if goal.type == "provide_service" then return true, "Heal enabled; ProvideService already present." end
    end
    GoalSystem.addGoal(actor, {type = "provide_service"})
    return true, "Heal and ProvideService added. Advance world time to select the goal."
end

function Tools.resolve(map, kind, id)
    if not map then return nil end
    local entity = EcsWorld.findEntityById(id, kind)
    if not entity then return nil end
    if kind == "location" then
        for _, location in ipairs(map:getLocations()) do
            if location == entity then return entity end
        end
    elseif kind == "party" then
        for _, party in ipairs(map:getParties()) do
            if party == entity then return entity end
        end
        for _, location in ipairs(map:getLocations()) do
            for _, party in ipairs(location.stationedParties or {}) do
                if party == entity then return entity end
            end
        end
    elseif kind == "unit" then
        for _, party in ipairs(map:getParties()) do
            for _, actor in ipairs(party.actors) do if actor == entity then return entity end end
        end
        for _, location in ipairs(map:getLocations()) do
            for _, actor in ipairs(location.npcs or {}) do if actor == entity then return entity end end
            for _, party in ipairs(location.stationedParties or {}) do
                for _, actor in ipairs(party.actors) do if actor == entity then return entity end end
            end
        end
    end
end

function Tools.grantKnowledge(map, kind, id, eventId, details)
    if not Mode.enabled then return false, "Enable debug mode with F1 first." end
    local owner = Tools.resolve(map, kind, id)
    if not owner then return false, "This memory owner is no longer on this map." end
    local ok, err = Knowledge.learn(owner, eventId, details, owner.__world)
    return ok, err or "Knowledge granted."
end

function Tools.hitTest(map, camera, x, y)
    local hits = {}
    if not Mode.enabled or not map or not camera then return hits end
    local function consider(entity, kind)
        if Tools.resolve(map, kind, entity.id) ~= entity then return end
        local sx, sy = camera:worldToScreen(entity.x, entity.y)
        local distance = (sx - x)^2 + (sy - y)^2
        if distance <= 25^2 then
            hits[#hits + 1] = {kind = kind, id = entity.id, name = entity.name, distance = distance}
        end
    end
    for _, party in ipairs(map:getParties()) do consider(party, "party") end
    for _, location in ipairs(map:getLocations()) do
        if location.discovered then consider(location, "location") end
    end
    table.sort(hits, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        if a.kind ~= b.kind then return a.kind == "party" end
        return tostring(a.id) < tostring(b.id)
    end)
    return hits
end

function Tools.locations(map)
    local locations = {}
    for _, location in ipairs(map and map:getLocations() or {}) do
        if Tools.resolve(map, "location", location.id) then locations[#locations + 1] = location end
    end
    table.sort(locations, function(a, b)
        if a.name == b.name then return tostring(a.id) < tostring(b.id) end
        return a.name < b.name
    end)
    return locations
end

function Tools.editableLeader(map, partyId, expectedLeaderId, readOnly)
    if not Mode.enabled then return nil, "Enable debug mode with F1 first." end
    local party = Tools.resolve(map, "party", partyId)
    if not party then return nil, "This party is no longer on this map." end
    if party == GameContext.data.playerParty then return nil, "NPC goals cannot control the player party." end
    local leader = PartySystem.getLeader(party)
    if not leader or EcsWorld.findActorById(leader.id) ~= leader or (leader.hp or 0) <= 0 or leader.player then
        return nil, "This party needs a living NPC leader." end
    if expectedLeaderId and leader.id ~= expectedLeaderId then
        return nil, "The leader changed. Close and reopen the goal editor." end
    if party.activeEncounterId then return nil, "Finish the party's encounter before editing its goals." end
    if not readOnly and Services.hasObligation(leader, {world = leader.__world}) then
        return nil, "Complete or cancel the accepted service before replacing goals."
    end
    return leader, nil, party
end

-- Resolve the selected NPC independently of whether it commands a party.
function Tools.editableActor(map, actorId, readOnly, expectedCommandPartyId)
    if not Mode.enabled then return nil, "Enable debug mode with F1 first." end
    if expectedCommandPartyId then
        return Tools.editableLeader(map, expectedCommandPartyId, actorId, readOnly)
    end
    local actor = Tools.resolve(map, "unit", actorId)
    if not actor or actor.player or (actor.hp or 0) <= 0 then
        return nil, "Select a living NPC on this map."
    end
    local party = Services.getParty(actor, actor.__world)
    if party and party == GameContext.data.playerParty then
        return nil, "NPC goals cannot control the player party."
    end
    if actor.activeEncounterId or (party and party.activeEncounterId) then
        return nil, "Finish the NPC's encounter before editing its goals."
    end
    if not readOnly and Services.hasObligation(actor, {world = actor.__world}) then
        return nil, "Complete or cancel the accepted service before replacing goals."
    end
    return actor, nil, party
end

local Definitions = require("src.systems.goals.goal_definitions")

local function saveGoals(map, actor, party, forms, capabilities)
    local definitions, flags = {}, {}
    local valid, message = pcall(function()
        for _, form in ipairs(forms) do
            definitions[#definitions + 1] = Definitions.definition(form, function(id)
                return Tools.resolve(map, "location", id)
            end)
        end
        for name, allowed in pairs(capabilities) do
            assert(type(name) == "string" and name:match("^[%a][%w_]*$") and type(allowed) == "boolean",
                "Capabilities must be named boolean flags")
            flags[name] = allowed
        end
    end)
    if not valid then return false, tostring(message) end
    local stopped = GoalSystem.cancelActivities(actor, "debug_goal_replaced")
    if not stopped then return false, "An existing goal still owns an encounter. Finish it first." end
    if party and PartySystem.getLeader(party) == actor then
        Activities.cancel(party, "debug_goal_replaced")
    end
    GoalSystem.configure(actor, definitions, flags)
    return true, "Goals saved. Advance world time to evaluate them; existing cooldowns still apply."
end

function Tools.configureGoals(map, partyId, expectedLeaderId, forms, capabilities)
    local leader, err, party = Tools.editableLeader(map, partyId, expectedLeaderId)
    if not leader then return false, err end
    return saveGoals(map, leader, party, forms, capabilities)
end

function Tools.configureActorGoals(map, actorId, forms, capabilities, expectedCommandPartyId)
    local actor, err, party = Tools.editableActor(map, actorId, false, expectedCommandPartyId)
    if not actor then return false, err end
    return saveGoals(map, actor, party, forms, capabilities)
end

-- Single-goal entry point retained for callers using the original debug form.
function Tools.configureGoal(map, partyId, expectedLeaderId, form)
    return Tools.configureGoals(map, partyId, expectedLeaderId, {form},
        {raid = form.raid == true, travel = form.travel == true, roam = form.roam == true})
end

return Tools
