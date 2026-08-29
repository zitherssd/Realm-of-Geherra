-- systems/painted_map_loader.lua
-- Builds the playable world Map from an in-memory painted map produced by
-- systems/map_generator.lua (no files on disk).
--
-- The painted PNG already contains terrain, water, rivers, roads, mountains
-- and trees, so the runtime water/biome/road overlays are disabled. The
-- navigation grid is derived from the generator's biome grid: ocean, marsh
-- lakes and snowy peaks are impassable.

local Map = require("src.world.map")
local MapGenerator = require("src.systems.map_generator")
local WorldGenerationConfig = require("src.data.world_generation")

local PaintedMapLoader = {}

-- Biome colours for the painted map (matches systems/map_generator.lua CONFIG
-- palette). Only used as fallback data; the biome overlay is disabled because
-- the painted PNG already shows terrain colours.
local BIOME_COLORS = {
    ocean         = {  40 / 255,  50 / 255, 120 / 255, 1 },
    oceanDeep     = {  26 / 255,  33 / 255,  86 / 255, 1 },
    beach         = { 236 / 255, 214 / 255, 160 / 255, 1 },
    coast         = { 150 / 255,  84 / 255,  54 / 255, 1 },
    cliff         = { 118 / 255, 108 / 255, 118 / 255, 1 },
    plains        = { 116 / 255, 148 / 255,  88 / 255, 1 },
    plainsDry     = { 196 / 255, 176 / 255,  84 / 255, 1 },
    forest        = {  78 / 255, 128 / 255, 100 / 255, 1 },
    forestDark    = {  58 / 255, 104 / 255,  82 / 255, 1 },
    desert        = { 212 / 255, 172 / 255,  94 / 255, 1 },
    hills         = { 126 / 255, 124 / 255,  92 / 255, 1 },
    hill          = { 118 / 255, 118 / 255,  86 / 255, 1 },
    hillDark      = {  94 / 255,  96 / 255,  68 / 255, 1 },
    plateau       = { 148 / 255, 144 / 255, 106 / 255, 1 },
    marsh         = {  52 / 255, 102 / 255,  96 / 255, 1 },
    marshLake     = {  34 / 255,  68 / 255,  74 / 255, 1 },
    marshLakeDeep = {  22 / 255,  48 / 255,  54 / 255, 1 },
    mountain      = { 108 / 255, 104 / 255, 118 / 255, 1 },
    mountainDark  = {  84 / 255,  82 / 255,  96 / 255, 1 },
    snow          = { 230 / 255, 215 / 255, 185 / 255, 1 },
    tree          = {  60 / 255, 118 / 255,  88 / 255, 1 },
    treeDark      = {  46 / 255,  96 / 255,  72 / 255, 1 },
    lush          = {  92 / 255, 150 / 255, 112 / 255, 1 },
    river         = {  62 / 255,  92 / 255, 148 / 255, 1 },
    road          = { 196 / 255, 166 / 255, 106 / 255, 1 },
    site          = { 235 / 255, 165 / 255,  35 / 255, 1 },
}

-- Resolve generation options, merging caller overrides with the
-- data/world_generation.lua "painted" defaults.
local function resolveOptions(options)
    options = options or {}
    local cfg = WorldGenerationConfig.painted or {}
    local navigation = WorldGenerationConfig.navigation or {}
    return {
        seed      = options.seed      or cfg.seed      or MapGenerator.defaultSeed,
        sizeW     = options.sizeW     or cfg.sizeW     or MapGenerator.defaultWidth,
        sizeH     = options.sizeH     or cfg.sizeH     or MapGenerator.defaultHeight,
        detail    = options.detail    or cfg.detail    or MapGenerator.defaultDetail,
        siteCount = options.siteCount or cfg.siteCount or MapGenerator.defaultSiteCount or 14,
        cellSize  = options.cellSize  or navigation.cellSize or 16,
    }
end

-- Create the async generation stepper. A splash state calls :advance() once
-- per frame to show live step-by-step progress (result shape:
-- { world, sites, roads }).
function PaintedMapLoader.createGeneration(options)
    local o = resolveOptions(options)
    return MapGenerator.createGeneration(o.seed, o.sizeW, o.sizeH, o.detail, o.siteCount)
end

-- Run the whole generation synchronously and return the finished Map.
function PaintedMapLoader.generate(options)
    local gen = PaintedMapLoader.createGeneration(options)
    gen:runAll()
    return PaintedMapLoader.buildMap(gen.result, options)
end

-- Build the playable Map from a finished generation result.
function PaintedMapLoader.buildMap(result, options)
    local o = resolveOptions(options)
    local world = result.world
    local sites = result.sites or {}
    local roads = result.roads or {}

    local map = Map.new("realm_of_geherra", "Realm of Geherra")
    map.width = world.targetW
    map.height = world.targetH
    map:setBounds(0, 0, world.targetW, world.targetH)

    -- Painted terrain image (the PNG already contains water, biomes and roads).
    -- Nearest filtering so the world-state 2x zoom shows the slightly-pixelated
    -- upscaled look the user wants.
    map.visuals.image = love.graphics.newImage(world.base)
    map.visuals.image:setFilter("nearest", "nearest")
    map.visuals.overlayImage = love.graphics.newImage(world.overlay)
    map.visuals.overlayImage:setFilter("nearest", "nearest")
    map.renderOptions.showWater = false
    map.renderOptions.showBiomeOverlay = false
    -- Road polylines connect only road-worthy locations (rebuilt after typing
    -- in location_population_system.populate), so draw them on the world map.
    map.renderOptions.showRoads = true

    -- Navigation grid from the biome grid (ocean + marsh lakes impassable).
    local cellSize = o.cellSize
    local cols = math.max(1, math.floor(map.width / cellSize))
    local rows = math.max(1, math.floor(map.height / cellSize))
    local grid = {}
    for y = 1, rows do
        grid[y] = {}
        for x = 1, cols do
            local worldX = (x - 0.5) * cellSize
            local worldY = (y - 0.5) * cellSize
            local sx = math.max(1, math.min(world.sampleW, math.floor(worldX / world.targetW * world.sampleW) + 1))
            local sy = math.max(1, math.min(world.sampleH, math.floor(worldY / world.targetH * world.sampleH) + 1))
            local b = world.biome[sy][sx]
            -- Snowy peaks are impassable along with water (ocean / marsh lake)
            local walkable = (b ~= "ocean" and b ~= "marsh_lake" and b ~= "snow")
            grid[y][x] = {
                x = x,
                y = y,
                worldX = worldX,
                worldY = worldY,
                walkable = walkable,
                blockedReason = walkable and nil or (b == "snow" and "snow" or "water"),
                biomeId = b,
            }
        end
    end

    -- Reuse the existing biome configs (weights / colours / location bias)
    -- for the biome labels the painted map shares with the procedural world.
    local biomeById = {}
    for _, biomeCfg in ipairs(WorldGenerationConfig.biomes or {}) do
        biomeById[biomeCfg.id] = biomeCfg
    end
    if biomeById.marsh and not biomeById.marsh_lake then
        biomeById.marsh_lake = biomeById.marsh
    end

    local generationData = {
        seed = world.seed,
        world = world,          -- kept so roads can be rebuilt after typing
        sites = sites,
        roads = roads,
        biomeById = biomeById,
        biomeColors = BIOME_COLORS,
        waterColor = { 0.08, 0.26, 0.48, 0.85 },
        navigationGrid = {
            cellSize = cellSize,
            cols = cols,
            rows = rows,
            cells = grid,
        },
    }

    map:setWorldGenerationData(generationData)

    -- Snap sites onto walkable nav cells (the coarse nav grid may classify a
    -- cell as water even when the site's pixel is on a land sample cell).
    for _, s in ipairs(sites) do
        local nx, ny = map:nearestWalkable(s.x, s.y)
        s.x, s.y = nx, ny
        s.px, s.py = nx, ny
    end

    return map
end

return PaintedMapLoader
