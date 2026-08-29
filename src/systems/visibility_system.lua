-- systems/visibility_system.lua
-- Spotting/scouting: decides which roaming parties and hidden locations the
-- player can currently see on the world map, based on party sight vs the
-- target's profile (see data/visibility.lua for the tunable radius divisor).

local PartySystem = require("src.systems.party_system")
local VisibilityConfig = require("src.data.visibility")

local VisibilitySystem = {}

local function withinRadius(ax, ay, bx, by, radius)
    local dx, dy = ax - bx, ay - by
    return (dx * dx + dy * dy) <= radius * radius
end

-- Refresh `party.visible` on every other roaming party and flip
-- `location.discovered` (sticky) on any hidden location now in range.
function VisibilitySystem.update(playerParty, map)
    if not playerParty or not map then return end

    playerParty.visible = true

    local sight = PartySystem.getPartySight(playerParty)
    local divisor = VisibilityConfig.radiusDivisor or 1

    for _, party in ipairs(map:getParties() or {}) do
        if party.id ~= playerParty.id then
            local radius = (sight + PartySystem.getPartyProfile(party)) / divisor
            party.visible = withinRadius(playerParty.x, playerParty.y, party.x, party.y, radius)
        end
    end

    for _, location in ipairs(map:getLocations() or {}) do
        if not location.discovered then
            local radius = (sight + (location.profile or 0)) / divisor
            if withinRadius(playerParty.x, playerParty.y, location.x, location.y, radius) then
                location.discovered = true
            end
        end
    end
end

return VisibilitySystem
