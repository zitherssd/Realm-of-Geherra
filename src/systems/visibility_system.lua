-- systems/visibility_system.lua
-- Spotting/scouting: evaluates observer sight against target profile for
-- parties and hidden locations (see data/visibility.lua for the radius divisor).

local PartySystem = require("src.systems.party_system")
local VisibilityConfig = require("src.data.visibility")

local VisibilitySystem = {}

local function withinRadius(ax, ay, bx, by, radius)
    local dx, dy = ax - bx, ay - by
    return (dx * dx + dy * dy) <= radius * radius
end

local function canSeePoint(observerParty, x, y, profile)
    local divisor = VisibilityConfig.radiusDivisor or 1
    local radius = (PartySystem.getPartySight(observerParty) + (profile or 0)) / divisor
    return withinRadius(observerParty.x, observerParty.y, x, y, radius)
end

function VisibilitySystem.canSee(observerParty, targetParty)
    if not observerParty or not targetParty then return false end

    return canSeePoint(
        observerParty,
        targetParty.x,
        targetParty.y,
        PartySystem.getPartyProfile(targetParty)
    )
end

-- Refresh `party.visible` on every other roaming party and flip
-- `location.discovered` (sticky) on any hidden location now in range.
function VisibilitySystem.update(playerParty, map)
    if not playerParty or not map then return end

    playerParty.visible = true

    for _, party in ipairs(map:getParties() or {}) do
        if party.id ~= playerParty.id then
            party.visible = VisibilitySystem.canSee(playerParty, party)
        end
    end

    for _, location in ipairs(map:getLocations() or {}) do
        if not location.discovered then
            if canSeePoint(playerParty, location.x, location.y, location.profile) then
                location.discovered = true
            end
        end
    end

    for _, site in ipairs(map:getBattlefieldRemains() or {}) do
        local position = site.history and site.history.position
        local currentlyVisible = position and canSeePoint(playerParty, position.x,
            position.y, site.profile) or false
        site.currentlyVisible = currentlyVisible
        if currentlyVisible then
            site.discovered = true
        end
    end
end

return VisibilitySystem
