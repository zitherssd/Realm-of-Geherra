local WorldGeneration = {
    defaultSeed = 1337,
    -- Painted in-memory world map (world/generation/map_generator.lua).
    -- These defaults feed world/generation/painted_map_loader.lua.
    painted = {
        seed = 1336,
        sizeW = 3500,
        sizeH = 2048,
        detail = 2,
        siteCount = 14,
    },
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
        { id = "forest",    weight = 4, color = { 0.14, 0.32, 0.14, 0.28 } },
        { id = "desert",    weight = 2, color = { 0.78, 0.70, 0.22, 0.28 } },
        { id = "plains",    weight = 3, color = { 0.45, 0.62, 0.28, 0.26 } },
        { id = "highlands", weight = 2, color = { 0.48, 0.48, 0.52, 0.24 } },
        { id = "marsh",     weight = 1, color = { 0.20, 0.36, 0.30, 0.30 } }
    },
}

return WorldGeneration
