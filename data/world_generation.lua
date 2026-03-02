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
        majorCount = 8,
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
        { id = "forest", weight = 4, color = { 0.14, 0.32, 0.14, 0.28 }, locationBias = { village = 3, town = 2, castle = 1 } },
        { id = "desert", weight = 2, color = { 0.78, 0.70, 0.22, 0.28 }, locationBias = { village = 1, town = 2, castle = 1 } },
        { id = "plains", weight = 3, color = { 0.45, 0.62, 0.28, 0.26 }, locationBias = { village = 3, town = 2, castle = 1 } },
        { id = "highlands", weight = 2, color = { 0.48, 0.48, 0.52, 0.24 }, locationBias = { village = 1, town = 2, castle = 2 } },
        { id = "marsh", weight = 1, color = { 0.20, 0.36, 0.30, 0.30 }, locationBias = { village = 2, town = 1, castle = 1 } }
    },
    locationPopulation = {
        majorTypes = { "village", "town", "castle" },
        typeWeights = { village = 4, town = 3, castle = 2 },
        namePools = {
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
            }
        },
        populationByType = {
            village = { min = 500, max = 1500 },
            town = { min = 1800, max = 4200 },
            castle = { min = 3200, max = 6200 }
        },
        prosperityByType = {
            village = { min = 35, max = 60 },
            town = { min = 45, max = 75 },
            castle = { min = 55, max = 85 }
        },
        defaultFactions = { "menari", "dacians", "hyperboreans", "neutral" }
    }
}

return WorldGeneration
