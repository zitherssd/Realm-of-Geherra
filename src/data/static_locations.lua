-- data/static_locations.lua
-- Hand-authored location catalog for a future handcrafted world map.
-- This file is intentionally not wired into generation yet.

local StaticLocations = {
    meta = {
        mapId = "handcrafted_world_v1",
        coordinateSystem = "map_cells", -- change to "pixels" if your map uses pixel positions
        notes = "Use this file to capture location concepts now; wire it into world generation later."
    },

    -- Keep these aligned with existing location behavior tables unless you add new handling.
    allowedTypes = {
        "village",
        "town",
        "castle",
        "shrine",
        "ruins"
    },

    -- Duplicate entries in this list as your location ideas grow.
    -- Suggested fields:
    -- id          : unique string key (snake_case)
    -- name        : display name
    -- type        : village | town | castle | shrine | ruins
    -- x, y        : handcrafted map coordinates (optional for now)
    -- faction     : owning faction id
    -- description : short lore or gameplay intent
    -- actions     : same shape as data/location_npc_spawn_rules.lua actions list
    -- npcs        : same shape as data/location_npc_spawn_rules.lua npcs list
    locations = {
        {
            id = "craiuva",
            name = "Craiuva",
            type = "village",
            x = 0,
            y = 0,
            faction = "pelasgians",
            description = "Market and trading village.",
            actions = {
                {
                    label = "Recruit Volunteers",
                    action = "startRecruitmentDialogue",
                    cooldown = { key = "lastRecruitDay", days = 5 }
                }
            },
            npcs = {
                { troopType = "trader", count = 3, chance = 0.8 },
                { troopType = "elder", count = 2, chance = 0.8 },
                { troopType = "soldier", count = 1, chance = 1.0 },
                { troopType = "tavern_keeper", count = 1, chance = 1.0 }
            }
        },
        {
            id = "hunedora",
            name = "Hunedora",
            type = "village",
            x = 0,
            y = 0,
            faction = "pelasgians",
            description = "Mountain village.",
            actions = {
                {
                    label = "Recruit Volunteers",
                    action = "startRecruitmentDialogue",
                    cooldown = { key = "lastRecruitDay", days = 5 }
                }
            },
            npcs = {
                { troopType = "trader", count = 1, chance = 0.8 },
                { troopType = "elder", count = 2, chance = 0.8 },
                { troopType = "soldier", count = 1, chance = 1.0 },
                { troopType = "tavern_keeper", count = 1, chance = 1.0 }
            }
        }
    }
}

return StaticLocations
