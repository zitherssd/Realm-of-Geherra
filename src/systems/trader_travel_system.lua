-- systems/trader_travel_system.lua
-- Travelling merchants: an NPC trader stationed in a location rolls a random
-- stay (7-28 days), then leaves the location's NPC list, becomes a real map
-- Party (with 1-2 soldier escorts) that follows the road graph to another
-- settlement, and rejoins that location's NPCs on arrival. The travelling
-- party mirrors the trader's inventory/trading fields directly so the
-- existing generic dialogue/shop code (which only reads target.inventory
-- etc., regardless of entity type) works unmodified.

local TraderTravelSystem = {}

local GameContext = require("src.game.game_context")
local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.party_system")
local LocationSystem = require("src.systems.location_system")
local TimeSystem = require("src.systems.time_system")
local EventBus = require("src.core.event_bus")
local PartyAiSystem = require("src.systems.party_ai_system")

TraderTravelSystem.travelSpeed = 70
TraderTravelSystem.escortMin = 1
TraderTravelSystem.escortMax = 2

local lastProcessedDay = nil

-- Settlement types traders can travel between (matches location_npc_spawn_rules.lua).
local DESTINATION_TYPES = { village = true, town = true, castle = true }

-- ---------------------------------------------------------------------------
-- Road graph (built once per map, cached on map.worldGen)
-- ---------------------------------------------------------------------------

local function buildRoadGraph(map)
    local graph = {}
    for _, road in ipairs((map.worldGen and map.worldGen.roads) or {}) do
        graph[road.from] = graph[road.from] or {}
        table.insert(graph[road.from], { to = road.to, points = road.points, forward = true })

        graph[road.to] = graph[road.to] or {}
        table.insert(graph[road.to], { to = road.from, points = road.points, forward = false })
    end
    return graph
end

local function roadGraph(map)
    if not map.worldGen then return {} end
    if not map.worldGen._roadGraph then
        map.worldGen._roadGraph = buildRoadGraph(map)
    end
    return map.worldGen._roadGraph
end

-- BFS over the road graph from fromLocation to toLocation (both keyed by
-- siteId), returning an ordered list of {x, y} waypoints, or nil if no path
-- exists (shouldn't happen: road-worthy sites form a connected spanning tree).
local function findRoadPath(map, fromLocation, toLocation)
    local graph = roadGraph(map)
    local startId, goalId = fromLocation.siteId, toLocation.siteId
    if not startId or not goalId or startId == goalId then
        return nil
    end

    local visited = { [startId] = true }
    local queue = { { id = startId, edges = {} } }
    local head = 1

    while head <= #queue do
        local current = queue[head]
        head = head + 1

        if current.id == goalId then
            local waypoints = {}
            for _, edge in ipairs(current.edges) do
                local pts = edge.points
                if edge.forward then
                    for _, p in ipairs(pts) do
                        table.insert(waypoints, { x = p.x, y = p.y })
                    end
                else
                    for i = #pts, 1, -1 do
                        table.insert(waypoints, { x = pts[i].x, y = pts[i].y })
                    end
                end
            end
            return waypoints
        end

        for _, edge in ipairs(graph[current.id] or {}) do
            if not visited[edge.to] then
                visited[edge.to] = true
                local edges = {}
                for _, e in ipairs(current.edges) do table.insert(edges, e) end
                table.insert(edges, edge)
                table.insert(queue, { id = edge.to, edges = edges })
            end
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Depart / arrive
-- ---------------------------------------------------------------------------

local function pickDestination(map, currentLocation)
    local candidates = {}
    for _, location in ipairs(map:getLocations() or {}) do
        if location ~= currentLocation and DESTINATION_TYPES[location.type] then
            table.insert(candidates, location)
        end
    end
    if #candidates == 0 then return nil end
    return candidates[math.random(#candidates)]
end

local function departTrader(map, location, npc)
    -- Remove the trader from the location's NPC list.
    for i, other in ipairs(location.npcs) do
        if other == npc then
            table.remove(location.npcs, i)
            break
        end
    end

    local destination = pickDestination(map, location)
    if not destination then
        -- No other settlement to travel to; put the trader back and try again later.
        table.insert(location.npcs, npc)
        return
    end

    local waypoints = findRoadPath(map, location, destination)
    if not waypoints or #waypoints == 0 then
        table.insert(location.npcs, npc)
        return
    end

    local party = Party.create(EcsWorld.campaign, npc.name, npc.id)
    party.state = "travel"
    party.isTraderParty = true
    party.hostile = false
    party.faction = "neutral"
    party.dialogueId = npc.dialogueId or "trader_greeting"
    party.name = npc.name
    party.inventory = npc.inventory
    party.buysFromPlayers = npc.buysFromPlayers
    party.sellPriceFactor = npc.sellPriceFactor
    party.traderActor = npc
    party.destinationLocationId = destination.id
    party.pathWaypoints = waypoints
    party.waypointIndex = 1

    PartySystem.setPosition(party, location.x, location.y)
    PartySystem.addActor(party, npc)

    local escortCount = math.random(TraderTravelSystem.escortMin, TraderTravelSystem.escortMax)
    for _ = 1, escortCount do
        PartySystem.addActor(party, Unit.create(EcsWorld.campaign, "soldier"))
    end

    map:addParty(party)
end

local function arriveAtDestination(map, party)
    local destination
    for _, location in ipairs(map:getLocations() or {}) do
        if location.id == party.destinationLocationId then
            destination = location
            break
        end
    end

    local npc = party.traderActor
    if destination and npc then
        PartySystem.removeActor(party, npc)
        npc.daysAtLocation = 0
        npc.travelThresholdDays = math.random(7, 28)
        LocationSystem.addNPC(destination, npc)
    end

    map:removeParty(party.id)
end

-- ---------------------------------------------------------------------------
-- Per-frame update
-- ---------------------------------------------------------------------------

local function processDayTick(map)
    for _, location in ipairs(map:getLocations() or {}) do
        -- Iterate backwards: departTrader mutates location.npcs.
        for i = #location.npcs, 1, -1 do
            local npc = location.npcs[i]
            if npc.troopType == "trader" then
                npc.daysAtLocation = (npc.daysAtLocation or 0) + 1
                if npc.travelThresholdDays and npc.daysAtLocation >= npc.travelThresholdDays then
                    departTrader(map, location, npc)
                end
            end
        end
    end
end

function TraderTravelSystem.update(dt, map)
    if not map then return end

    -- Collect arrivals first: arriveAtDestination() removes the party from
    -- map:getParties(), which would corrupt an in-progress ipairs over it.
    local arrivedParties = {}
    for _, party in ipairs(map:getParties() or {}) do
        if party.state == "travel" then
            local arrived
            party.waypointIndex, arrived = PartyAiSystem.followWaypoints(
                party, party.pathWaypoints, party.waypointIndex, TraderTravelSystem.travelSpeed, dt
            )
            if arrived then
                table.insert(arrivedParties, party)
            end
        end
    end

    for _, party in ipairs(arrivedParties) do
        arriveAtDestination(map, party)
    end

    local day = TimeSystem.getDay()
    if day ~= lastProcessedDay then
        lastProcessedDay = day
        processDayTick(map)
    end
end

function TraderTravelSystem._onPartyKilled(partyId)
    local map = GameContext.data.currentMap
    if not map then return end

    for _, party in ipairs(map:getParties() or {}) do
        if party.id == partyId and party.isTraderParty then
            map:removeParty(partyId)
            break
        end
    end
end

function TraderTravelSystem.init()
    EventBus.subscribe("party_killed", TraderTravelSystem._onPartyKilled)
end

-- Called on a fresh WorldState.enter() (new game / map load) so a stale day
-- number from a previous game doesn't skip this game's first day-tick.
function TraderTravelSystem.resetDayTick()
    lastProcessedDay = nil
end

return TraderTravelSystem
