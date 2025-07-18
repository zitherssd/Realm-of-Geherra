local biomeTypes = {
    forest = {
        color = {0.2, 0.5, 0.2},
        description = "Dense forest, slows movement."
    },
    mountain = {
        color = {0.4, 0.4, 0.4},
        description = "Impassable mountains."
    },
    lake = {
        color = {0.2, 0.4, 0.8},
        description = "Water body, blocks movement."
    },
    river = {
        color = {0.3, 0.5, 0.9},
        description = "River, may block or slow movement."
    },
    -- Add more biome types as needed
}

return biomeTypes