-- src/data/location_types.lua
-- Defines the types of locations and their available options/services

local locationTypes = {
    Fort = {
        description = "A heavily fortified stronghold.",
        options = {"Recruit Units", "Shop", "Location Info", "Leave Location"}
    },
    Village = {
        description = "A peaceful farming village.",
        options = {"Recruit Units", "Shop", "Tavern", "Location Info", "Leave Location"}
    },
    Tower = {
        description = "A tall watchtower overlooking the land.",
        options = {"Recruit Units", "Location Info", "Leave Location"}
    },
    Hideout = {
        description = "A secretive hideout for bandits.",
        options = {"Recruit Units", "Shop", "Location Info", "Leave Location"}
    },
    Dungeon = {
        description = "A dark and dangerous dungeon.",
        options = {"Location Info", "Leave Location"}
    }
}

return locationTypes