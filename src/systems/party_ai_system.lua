-- systems/party_ai_system.lua
-- Fallback world-map movement for non-player parties. Activities and trader
-- travel own movement when active; this system handles wandering otherwise.

local PartyAiSystem = {}

PartyAiSystem.wanderSpeed = 20
PartyAiSystem.wanderRadiusDefault = 220
PartyAiSystem.wanderPauseMin = 2
PartyAiSystem.wanderPauseMax = 6

-- Step a party directly toward (tx, ty) at `speed` px/s, factoring in map biome and road speed modifiers if map is available.
local function moveToward(party, tx, ty, speed, dt, map)
    local dx, dy = tx - party.x, ty - party.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return end

    local effectiveSpeed = speed
    if map and map.getTravelSpeedMod then
        local speedMod = map:getTravelSpeedMod(party.x, party.y)
        effectiveSpeed = speed * speedMod
    end

    local step = math.min(dist, effectiveSpeed * dt)
    local newX = party.x + (dx / dist) * step
    local newY = party.y + (dy / dist) * step

    if map and map.isWalkable then
        if not map:isWalkable(newX, newY) then
            local canMoveXOnly = map:isWalkable(newX, party.y)
            local canMoveYOnly = map:isWalkable(party.x, newY)

            if canMoveXOnly then
                newY = party.y
            elseif canMoveYOnly then
                newX = party.x
            else
                newX = party.x
                newY = party.y
            end
        end
    end

    party.x = newX
    party.y = newY
end

-- Shared world-map movement for pursuit-style activities.
function PartyAiSystem.moveToward(party, tx, ty, speed, dt, map)
    moveToward(party, tx, ty, speed, dt, map)
end

-- Advance `party` along `waypoints` starting at `index`, returning the
-- (possibly advanced) index and whether the party has reached the end.
-- Shared by trader_travel_system.lua for road-following.
function PartyAiSystem.followWaypoints(party, waypoints, index, speed, dt, map)
    if not waypoints or #waypoints == 0 then
        return index, true
    end

    local waypoint = waypoints[index]
    if not waypoint then
        return index, true
    end

    moveToward(party, waypoint.x, waypoint.y, speed, dt, map)

    local dx, dy = waypoint.x - party.x, waypoint.y - party.y
    if (dx * dx + dy * dy) <= 16 then
        index = index + 1
        if index > #waypoints then
            return index, true
        end
    end

    return index, false
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

    moveToward(party, party.wanderTarget.x, party.wanderTarget.y, PartyAiSystem.wanderSpeed, dt, map)

    if distanceTo(party.x, party.y, party.wanderTarget.x, party.wanderTarget.y) < 6 then
        party.wanderTarget = nil
        party.wanderPauseTimer = math.random(PartyAiSystem.wanderPauseMin, PartyAiSystem.wanderPauseMax)
    end
end

function PartyAiSystem.update(dt, map, playerParty)
    if not map or not playerParty then return end

    for _, party in ipairs(map:getParties() or {}) do
        local activity = party.world_activity
        local hasActiveActivity = activity and activity.status == "active"
        if party ~= playerParty and not party.activeEncounterId and not hasActiveActivity then
            if party.state == "travel" then
                -- Owned by trader_travel_system.lua.
            elseif party.state == "wander" or party.state == "chase" then
                updateWander(party, dt, map)
            end
        end
    end
end

return PartyAiSystem
