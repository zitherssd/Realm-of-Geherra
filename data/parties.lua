-- data/parties.lua
--
-- Data for all party types.

local Party = require("core.party")

local party_definitions = {
    {
        id = "player_party",
        name = "Player",
        faction = "neutral",
        position = { x = 1024, y = 1024 },
        speed = 180,
        commanders = { "human_commander" },
        units = { "human_infantry", "human_infantry", "human_swordsman" },
        inventory = { "iron_spear", "iron_sword", "wooden_shield" },
        gold = 120,
        is_player = true,
        color = { 0.95, 0.9, 0.2 },
        radius = 14,
    },
    {
        id = "ai_patrol_1",
        name = "Patrol",
        faction = "neutral",
        position = { x = 720, y = 920 },
        speed = 120,
        commanders = {},
        units = { "human_infantry", "human_infantry" },
        inventory = {},
        gold = 40,
        is_player = false,
        color = { 0.85, 0.3, 0.3 },
        radius = 11,
    },
    {
        id = "ai_patrol_2",
        name = "Patrol",
        faction = "neutral",
        position = { x = 1350, y = 860 },
        speed = 120,
        commanders = {},
        units = { "human_infantry" },
        inventory = {},
        gold = 35,
        is_player = false,
        color = { 0.3, 0.7, 0.9 },
        radius = 11,
    },
    {
        id = "ai_raiders",
        name = "Raiders",
        faction = "bandits",
        position = { x = 1120, y = 1280 },
        speed = 125,
        commanders = {},
        units = { "human_infantry", "human_swordsman" },
        inventory = {},
        gold = 60,
        is_player = false,
        color = { 0.8, 0.4, 0.75 },
        radius = 11,
    },
}

local party_index, errors = Party.build_index(party_definitions)

return {
    list = party_definitions,
    by_id = party_index,
    errors = errors,
}
