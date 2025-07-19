-- src/data/location_types.lua
-- Defines the types of locations and their available options/services

local locationOptions = require('src.data.location_options')

local locationTypes = {
    Fort = {
        description = "A heavily fortified stronghold.",
        options = {
            locationOptions.recruit_soldiers,
            locationOptions.shop_basic,
            locationOptions.info,
            locationOptions.leave
        }
    },
    Village = {
        description = "A peaceful farming village.",
        options = {
            locationOptions.recruit_villagers,
            locationOptions.trade_goods,
            locationOptions.tavern,
            locationOptions.info,
            locationOptions.leave
        }
    },
    Tower = {
        description = "A tall watchtower overlooking the land.",
        options = {
            locationOptions.recruit_soldiers,
            locationOptions.info,
            locationOptions.leave
        }
    },
    Hideout = {
        description = "A secretive hideout for bandits.",
        options = {
            locationOptions.recruit_soldiers,
            locationOptions.shop_basic,
            locationOptions.info,
            locationOptions.leave
        }
    },
    Dungeon = {
        description = "A dark and dangerous dungeon.",
        options = {
            locationOptions.info,
            locationOptions.leave
        }
    }
}

return locationTypes