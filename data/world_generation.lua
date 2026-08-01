local WorldGeneration = {
    defaultSeed = 1336,
    map = {
        visualPath = nil,
        terrainMaskPath = nil
    },
    navigation = {
        cellSize = 16,
        blackThreshold = 0.08,
        continent = {
            enabled = true,
            edgeWaterBandCells = 3,
            radius = 0.9,
            noiseScale = 2.2,
            noiseStrength = 0.08,
            waterColor = { 0.08, 0.26, 0.48, 0.85 }
        }
    },
    sites = {
        majorCount = 18,
        minDistanceCells = 10,
        maxPlacementAttempts = 2500,
        edgePaddingCells = 2,
        distanceRelaxation = {
            enabled = true,
            startAttemptRatio = 0.35,
            endDistanceMultiplier = 0.55
        }
    },
    roads = {
        connectNearest = true,
        extraConnections = 2,
        diagonalCost = 1.414,
        blockedCost = 1000000
    },
    biomes = {
        { id = "forest",    weight = 4, color = { 0.14, 0.32, 0.14, 0.28 }, locationBias = { village = 3, town = 2, castle = 1, shrine = 3, ruins = 2, bandit_camp = 3, windmill = 2 } },
        { id = "desert",    weight = 2, color = { 0.78, 0.70, 0.22, 0.28 }, locationBias = { village = 1, town = 2, castle = 1, shrine = 1, ruins = 1, bandit_camp = 1, windmill = 1 } },
        { id = "plains",    weight = 3, color = { 0.45, 0.62, 0.28, 0.26 }, locationBias = { village = 3, town = 2, castle = 1, shrine = 1, ruins = 1, bandit_camp = 2, windmill = 3 } },
        { id = "highlands", weight = 2, color = { 0.48, 0.48, 0.52, 0.24 }, locationBias = { village = 1, town = 2, castle = 2, shrine = 1, ruins = 3, bandit_camp = 3, windmill = 1 } },
        { id = "marsh",     weight = 1, color = { 0.20, 0.36, 0.30, 0.30 }, locationBias = { village = 2, town = 1, castle = 1, shrine = 1, ruins = 2, bandit_camp = 2, windmill = 1 } }
    },
    locationPopulation = {
        majorTypes = { "village", "town", "castle", "shrine", "ruins", "bandit_camp", "windmill" },
        typeWeights = { village = 4, town = 3, castle = 2, shrine = 3, ruins = 2, bandit_camp = 2, windmill = 2 },
        namePools = {
            ruins = {
                "The Hollow Keep", "Gravenwall", "Ashfeld Remnants", "Crestfall Ruins",
                "The Broken Spire", "Vordenmoor", "The Sunken Hall", "Duskwall",
                "The Forgotten Gate", "Irenmoth Ruins"
            },
            shrine = {
                "The Pale Altar", "Shrine of Aethon", "The Weeping Stone", "Shroud Hollow",
                "The Bound Grove", "Omen's Rest", "The Silent Pyre", "Dusk Sanctum",
                "The Red Idol", "Vigil's End"
            },
            village = {
                "Briar Glen", "Willowmere", "Thornfield", "Ashbrook", "Mossford",
                "Raven Hollow", "Oakrest", "Emberfen", "Stonebrook", "Redmeadow"
            },
            town = {
                "Dunhollow", "Ironford", "Westhaven", "Blackmere", "Graywatch",
                "Highbridge", "Crowport", "Stormcross", "Goldbarrow", "Driftmark"
            },
            castle = {
                "Fort Varkos", "Red Bastion", "Ironkeep", "Skystone Hold", "Dreadwatch",
                "Castle Morn", "Northwall Keep", "Blackgate", "Stormhold", "Grimspire"
            },
            bandit_camp = {
                "The Sullen Warren", "Rattlesnake Gorge", "Fang's Rest", "The Thorned Cache",
                "Gutterman's Hollow", "The Rotted Post", "Blood-Marked Grove", "Stone-Eye Camp",
                "The Beggar's Mire", "Wolfsbane Clearing"
            },
            windmill = {
                "Mill at Amberfield", "Sorrowstone Mill", "The Wren's Post", "Dustmill",
                "Old Crookstone Mill", "Hollowridge Windpost", "The Granary Rest", "Pale Flour Mill",
                "The Crestwood Post", "Weary Wheel Mill"
            }
        },
        populationByType = {
            village = { min = 500, max = 1500 },
            town = { min = 1800, max = 4200 },
            castle  = { min = 3200, max = 6200 },
            shrine  = { min = 0,    max = 0    },
            ruins   = { min = 0,    max = 0    },
            bandit_camp = { min = 0, max = 0 },
            windmill = { min = 10, max = 30 }
        },
        prosperityByType = {
            village = { min = 35, max = 60 },
            town    = { min = 45, max = 75 },
            castle  = { min = 55, max = 85 },
            shrine  = { min = 0,  max = 0  },
            ruins   = { min = 0,  max = 0  },
            bandit_camp = { min = 0, max = 0 },
            windmill = { min = 25, max = 45 }
        },
        defaultFactions = { "menari", "dacians", "hyperboreans", "neutral" }
    }
}

return WorldGeneration
