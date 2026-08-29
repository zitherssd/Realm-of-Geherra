-- systems/party_ai_system.lua
-- Generic world-map AI for non-player parties: idle (default, unchanged
-- static behavior), wander (roam near a spawn point), chase (pursue the
-- player once spotted, give up if they escape far enough), and travel (owned
-- by systems/trader_travel_system.lua, which supplies waypoints and only
-- calls PartyAiSystem.followWaypoints -- this module skips "travel" parties).

local PartySystem = require("src.systems.party_system")
local VisibilityConfig = require("src.data.visibility")

local PartyAiSystem = {}

PartyAiSystem.wanderSpeed = 40
PartyAiSystem.chaseSpeed = 95
PartyAiSystem.wanderRadiusDefault = 220
PartyAiSystem.wanderPauseMin = 2
PartyAiSystem.wanderPauseMax = 6
PartyAiSystem.giveUpMultiplier = 1.6

-- Step a party directly toward (tx, ty) at `speed` px/s.
local function moveToward(party, tx, ty, speed, dt)
    local dx, dy = tx - party.x, ty - party.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return end

    local step = math.min(dist, speed * dt)
    party.x = party.x + (dx / dist) * step
    party.y = party.y + (dy / dist) * step
end

-- Advance `party` along `waypoints` starting at `index`, returning the
-- (possibly advanced) index and whether the party has reached the end.
-- Shared by trader_travel_system.lua for road-following.
function PartyAiSystem.followWaypoints(party, waypoints, index, speed, dt)
    if not waypoints or #waypoints == 0 then
        return index, true
    end

    local waypoint = waypoints[index]
    if not waypoint then
        return index, true
    end

    moveToward(party, waypoint.x, waypoint.y, speed, dt)

    local dx, dy = waypoint.x - party.x, waypoint.y - party.y
    if (dx * dx + dy * dy) <= 16 then
        index = index + 1
        if index > #waypoints then
            return index, true
        end
    end

    return index, false
end

-- Detection radius: the party's own sight vs the player party's profile,
-- mirroring systems/visibility_system.lua symmetrically.
local function detectionRadius(party, playerParty)
    local sight = PartySystem.getPartySight(party)
    local profile = PartySystem.getPartyProfile(playerParty)
    local divisor = VisibilityConfig.radiusDivisor or 1
    return (sight + profile) / divisor
end

local function distanceTo(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function updateWander(party, dt, map)
    if not party.wanderTarget then
        if party.wanderPauseTimer > 0 then
            party.wanderPauseTimer = party.wanderPauseTimer - dt
            return
        end

        local originX = party.wanderOriginX or party.x
        local originY = party.wanderOriginY or party.y
        local radius = party.wanderRadius or PartyAiSystem.wanderRadiusDefault
        local angle = math.random() * math.pi * 2
        local dist = math.random() * radius
        local tx, ty = originX + math.cos(angle) * dist, originY + math.sin(angle) * dist
        if map and map.nearestWalkable then
            tx, ty = map:nearestWalkable(tx, ty)
        end
        party.wanderTarget = { x = tx, y = ty }
        return
    end

    moveToward(party, party.wanderTarget.x, party.wanderTarget.y, PartyAiSystem.wanderSpeed, dt)

    if distanceTo(party.x, party.y, party.wanderTarget.x, party.wanderTarget.y) < 6 then
        party.wanderTarget = nil
        party.wanderPauseTimer = math.random(PartyAiSystem.wanderPauseMin, PartyAiSystem.wanderPauseMax)
    end
end

local function updateChase(party, dt, playerParty)
    moveToward(party, playerParty.x, playerParty.y, PartyAiSystem.chaseSpeed, dt)

    local dist = distanceTo(party.x, party.y, playerParty.x, playerParty.y)
    if dist > detectionRadius(party, playerParty) * PartyAiSystem.giveUpMultiplier then
        party.state = "wander"
        party.wanderOriginX, party.wanderOriginY = party.x, party.y
        party.wanderTarget = nil
    end
end

-- True when `party` is willing to chase the player if it spots them (mirrors
-- world_state.lua's hostility check).
local function isHostile(party)
    return party.hostile == true or party.faction == "bandits"
end

function PartyAiSystem.update(dt, map, playerParty)
    if not map or not playerParty then return end

    for _, party in ipairs(map:getParties() or {}) do
        if party ~= playerParty then
            if party.state == "travel" then
                -- Owned by trader_travel_system.lua.
            elseif party.state == "chase" then
                updateChase(party, dt, playerParty)
            elseif party.state == "wander" then
                if isHostile(party) and distanceTo(party.x, party.y, playerParty.x, playerParty.y) <= detectionRadius(party, playerParty) then
                    party.state = "chase"
                else
                    updateWander(party, dt, map)
                end
            end
        end
    end
end

return PartyAiSystem
