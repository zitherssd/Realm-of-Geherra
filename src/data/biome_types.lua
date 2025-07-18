local biomeTypes = {
    ["#228B22"] = { -- Forest green
        name = "forest",
        movement_speed_rate = 0.75,
        healing_rate = 1.0,
        color = {0.2, 0.55, 0.13},
        passable = true,
        description = "Dense forest, slows movement."
    },
    ["#FFFF00"] = { -- Beach yellow
        name = "beach",
        movement_speed_rate = 1.0,
        healing_rate = 2.0,
        color = {1.0, 1.0, 0.0},
        passable = true,
        description = "Sandy beach, heals faster."
    },
    ["#8B4513"] = { -- Road (saddle brown)
        name = "road",
        movement_speed_rate = 1.5,
        healing_rate = 1.0,
        color = {0.545, 0.27, 0.075},
        passable = true,
        description = "Road, greatly increases movement speed."
    },
    ["#0000FF"] = { -- Water (blue)
        name = "water",
        movement_speed_rate = 0.0,
        healing_rate = 0.0,
        color = {0, 0, 1},
        passable = false,
        description = "Water, impassable terrain."
    },
    -- Add more biomes as needed
}

return biomeTypes