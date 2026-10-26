-- Debug actions resolve IDs at use time and call the normal campaign APIs.
local Mode = require("src.debug.mode")
local EcsWorld = require("src.ecs.world")
local PartySystem = require("src.systems.party_system")
local GoalSystem = require("src.systems.goal_system")
local Activities = require("src.systems.world_activity_system")
local GameContext = require("src.game.game_context")

local Tools = {}

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
    end
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

function Tools.editableLeader(map, partyId, expectedLeaderId)
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
    return leader, nil, party
end

local function number(value)
    value = tonumber(value)
    if value and value == value and value ~= math.huge and value ~= -math.huge then return value end
end

function Tools.configureGoal(map, partyId, expectedLeaderId, form)
    local leader, err, party = Tools.editableLeader(map, partyId, expectedLeaderId)
    if not leader then return false, err end
    local priority = number(form.priority)
    if not priority then return false, "Priority must be a finite number." end
    local definition = {type = form.type, priority = priority}
    if form.type == "acquire_gold" then
        local amount = number(form.amount)
        if not amount or amount < 0 then return false, "Gold target must be zero or a positive number." end
        definition.amount = amount
        if form.roam == true then
            local x, y, radius = number(form.originX), number(form.originY), number(form.radius)
            local duration = form.durationSeconds ~= "" and number(form.durationSeconds) or nil
            if not x or not y or not radius or radius <= 0 then
                return false, "Roam needs finite origin coordinates and a positive radius."
            end
            if form.durationSeconds and form.durationSeconds ~= "" and (not duration or duration <= 0) then
                return false, "Roam duration must be positive, or blank for no limit."
            end
            definition.roam = {originX = x, originY = y, radius = radius, durationSeconds = duration}
        end
    elseif form.type == "reach_location" then
        if not Tools.resolve(map, "location", form.destinationLocationId) then
            return false, "Choose an existing destination on this map."
        end
        definition.destinationLocationId = form.destinationLocationId
    else
        return false, "Choose Acquire Gold or Reach Location."
    end
    -- Validate everything before cancelling any existing work.
    local stopped = GoalSystem.cancelActivities(leader, "debug_goal_replaced")
    if not stopped then return false, "An existing goal still owns an encounter. Finish it first." end
    Activities.cancel(party, "debug_goal_replaced")
    GoalSystem.configure(leader, {definition}, {raid = form.raid == true, travel = form.travel == true,
        roam = form.roam == true})
    return true, "Goal saved. Advance world time to evaluate it; existing cooldowns still apply."
end

return Tools
