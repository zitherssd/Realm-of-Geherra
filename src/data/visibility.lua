-- data/visibility.lua
-- Tunables for the spotting/scouting system (systems/visibility_system.lua).

return {
    -- Divides (partySight + targetProfile) into a world-map detection radius (px).
    radiusDivisor = 1.5,

    -- Location types that start undiscovered and must be found via sight vs profile.
    hiddenLocationTypes = {
        ruins = true,
        bandit_camp = true,
        shrine = true
    }
}
