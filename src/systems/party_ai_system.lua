-- systems/party_ai_system.lua
-- Fallback world-map movement for non-player parties. Active activities own
-- movement; this system handles wandering otherwise.

local PartyAiSystem = {}

PartyAiSystem.wanderSpeed = 20
PartyAiSystem.wanderRadiusDefault = 220
PartyAiSystem.wanderPauseMin = 2
PartyAiSystem.wanderPauseMax = 6

-- Step a party directly toward (tx, ty) at `speed` px/s, factoring in map biome and road speed modifiers if map is available.
local function moveToward(party, tx, ty, speed, dt, map)
    local dx, dy = tx - party.x, ty - party.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= 0.000001 then return end

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

-- Follow every node without snapping or discarding time at cell boundaries.
-- Short movement steps retain the shared biome/road and collision behavior.
function PartyAiSystem.followWaypoints(party, waypoints, index, speed, dt, map)
    local remaining = math.max(0, dt)
    local grid = map and map.worldGen and map.worldGen.navigationGrid
    local maxStep = math.min(grid and grid.cellSize / 4 or 8, (map and map.roadOnDistance or 16) / 2)
    while waypoints and waypoints[index] do
        local point = waypoints[index]
        local dx, dy = point.x - party.x, point.y - party.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance <= 0.000001 then
            index = index + 1
        else
            if remaining <= 0 then break end
            local modifier = map and map.getTravelSpeedMod and map:getTravelSpeedMod(party.x, party.y) or 1
            local effectiveSpeed = speed * modifier
            if effectiveSpeed <= 0 then break end
            local stepTime = math.min(remaining, math.min(distance, maxStep) / effectiveSpeed)
            local oldX, oldY = party.x, party.y
            moveToward(party, point.x, point.y, speed, stepTime, map)
            remaining = remaining - stepTime
            if math.abs(party.x - oldX) + math.abs(party.y - oldY) <= 0.000001 then break end
        end
    end
    return index, not waypoints or index > #waypoints
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
        local activityOwnsParty = activity and activity.type
            and activity.status ~= "idle"
        if party ~= playerParty and not party.activeEncounterId and not activityOwnsParty
            and (party.state == "wander" or party.state == "chase") then
            updateWander(party, dt, map)
        end
    end
end

return PartyAiSystem
