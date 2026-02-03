-- data/locations.lua
--
-- Data for all locations on the world map.

local Location = require("core.location")

local location_definitions = {
    {
        id = "town_greenside",
        name = "Greenside",
        type = "town",
        faction = "neutral",
        position = { x = 420, y = 520 },
        persistent = true,
        recruitment_pool = {
            "human_infantry",
            "human_swordsman",
        },
        trade_inventory = {
            "iron_spear",
            "iron_sword",
            "wooden_shield",
            "leather_armor",
        },
        interaction_modules = {
            "trade",
            "recruit",
            "rest",
        },
        battle_stage = "town_stage",
        region = "plains",
        cooldowns = {
            recruitment = 86400,
        },
    },
    {
        id = "village_elmwatch",
        name = "Elmwatch",
        type = "village",
        faction = "neutral",
        position = { x = 1550, y = 900 },
        persistent = true,
        recruitment_pool = {
            "human_infantry",
        },
        trade_inventory = {
            "iron_spear",
            "leather_boots",
        },
        interaction_modules = {
            "trade",
            "recruit",
            "rest",
        },
        battle_stage = "village_stage",
        region = "forest",
        cooldowns = {
            recruitment = 43200,
        },
    },
    {
        id = "ruins_stone",
        name = "Stone Ruins",
        type = "ruins",
        faction = nil,
        position = { x = 1150, y = 1500 },
        persistent = false,
        recruitment_pool = {},
        trade_inventory = {},
        interaction_modules = {
            "explore",
            "fight",
        },
        battle_stage = "ruin_stage",
        region = "mountain",
        cooldowns = {},
    },
}

local location_index, errors = Location.build_index(location_definitions)

return {
    list = location_definitions,
    by_id = location_index,
    errors = errors,
}
