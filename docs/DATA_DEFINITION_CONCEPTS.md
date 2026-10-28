# Archived data-definition concepts

Archived on 2026-10-28 during the conservative L4/T3 cleanup. These snapshots are design notes, not modules loaded by the game. They preserve proposed content and mechanics without presenting them as active configuration.

## Handcrafted locations

Former source: `src/data/static_locations.lua`. No runtime or test consumer was found. The proposed handcrafted map, Craiuva/Hunedora locations, descriptions, faction intent, recruitment cooldowns and NPC mixes are preserved verbatim below. Coordinates of zero are placeholders, and the historical `pelasgians` faction spelling is not a decision about the current faction model. Reintroduction should use the existing site overrides, location definitions and population profiles after choosing actual coordinates and ownership.

```lua
-- data/static_locations.lua
-- Hand-authored location catalog for a future handcrafted world map.
-- This file is intentionally not wired into generation yet. These older concept
-- records are not live definitions; see docs/POPULATION_AUTHORING.md for the typed model.

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
    -- actions/npcs: legacy concept notes; migrate to location definitions/population profiles before use
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
```

## Progression proposals

Former source: `src/data/progression.lua`. No runtime or test consumer was found. The proposed experience thresholds, level-up bonuses and skill unlock/scaling values are preserved verbatim below. They have never controlled the current `ProgressionSystem`, which retains its existing threshold formula and health bonus. The historical `slash` identifier has no current skill definition. Choosing progression balance, adding unlocks/scaling, or renaming that proposed skill requires a future design decision; none is implemented by this cleanup.

```lua
-- data/progression.lua
-- Character progression and leveling

return {
    experienceTable = {
        100,    -- Level 1 -> 2
        200,    -- Level 2 -> 3
        300,    -- Level 3 -> 4
        450,    -- Level 4 -> 5
        600,    -- Level 5 -> 6
    },
    
    levelUpBonuses = {
        health = 10,
        defense = 1,
        speed = 0.5
    },
    
    skillProgression = {
        ["slash"] = {
            unlockLevel = 1,
            scalingFactor = 0.5
        },
        ["fireball"] = {
            unlockLevel = 3,
            scalingFactor = 1.0
        }
    }
}
```

## Legacy faction lore

Former source: `src/data/factions.lua`, before F1 consolidation. Names, colors and descriptions for matching faction IDs have been retained in the canonical faction records. The old `pelasgians` record describes a broad people, not the specific `pelasgian_clan` political group; its original lore/color is preserved here without making all culturally Pelasgian actors members of that clan. The unchanged historical snapshot follows.

```lua

-- data/factions.lua
-- Faction definitions

return {
    ["menari"] = {
        id = "menari",
        name = "The Menari",
        color = {r = 0.2, g = 0.5, b = 0.8},
        description = "The widespread common people, fragmented into countless cultures."
    },
    
    ["dacians"] = {
        id = "dacians",
        name = "The Dacians",
        color = {r = 0.8, g = 0.2, b = 0.2},
        description = "Rivals to the Menari with strong cultural memory and shared identity."
    },
    
    ["hyperboreans"] = {
        id = "hyperboreans",
        name = "The Hyperboreans",
        color = {r = 0.8, g = 0.9, b = 1.0},
        description = "Rare, mythic figures who intervene when balance is broken."
    },
    
    ["undead"] = {
        id = "undead",
        name = "Undead Forces",
        color = {r = 0.3, g = 0.0, b = 0.3},
        description = "The restless dead."
    },
    
    ["neutral"] = {
        id = "neutral",
        name = "Neutral",
        color = {r = 0.9, g = 0.9, b = 0.9},
        description = "Animals and unaligned entities."
    },
    
    ["bandits"] = {
        id = "bandits",
        name = "Bandit Clans",
        color = {r = 0.5, g = 0.2, b = 0.5},
        description = "Organized bandit groups"
    },

    ["pelasgians"] = {
        id = "pelasgians",
        name = "The Pelasgians",
        color = {r = 0.58, g = 0.44, b = 0.24},
        description = "Mountain and frontier tribal communities with strong local identity."
    }
}
```

