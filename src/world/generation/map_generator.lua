-- world/generation/map_generator.lua
-- Self-contained procedural world map generator for Realm of Geherra.
--
-- Produces ONE continuous painted map (no tiles, no grid) in two stages:
--   Stage "world": generate terrain (height, moisture, biomes, coasts,
--                  rivers, mountains, forests)
--                    -> assets/map/generated/<seed>/world.png
--   Stage "sites": load the finished world, place sites + generate roads
--                    -> assets/map/generated/<seed>/map_with_sites.png
--                    -> assets/map/generated/<seed>/sites_roads.lua
--
-- Two ways to use it:
--   1. Standalone export tool (wire an entry point, then run from the root):
--        love . --generate-map world --seed 1336 --size 4096 --detail 4
--        love . --generate-map sites --seed 1336 --sites 14
--   2. In-memory generation for the in-game debug world map view:
--        local MapGenerator = require("src.world.generation.map_generator")
--        local world = MapGenerator.generateWorld(seed, sizeW, sizeH, detail)
--
-- The default output is a golden-ratio landscape (W:H = ~1.618) and the size
-- is arbitrary: --size W (width, height derived) or --size WxH. Noise is
-- sampled on a coarser internal buffer (--detail, a linear divisor) and
-- bilinearly upscaled at render time, so large outputs stay fast.

local MapGenerator = {}

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------

local PHI = (1 + math.sqrt(5)) / 2  -- golden ratio ~1.61803 (W:H)

local CONFIG = {
    defaultSeed   = 1336,
    defaultWidth  = 3500,       -- wide landscape (user: ~3.5k wide x 2k tall)
    defaultHeight = 2048,
    defaultDetail = 2,          -- field-buffer divisor; the base is rendered at
                                -- full target resolution for pixel-level detail
    minSample     = 128,        -- never sample terrain smaller than this
    maxSample     = 2048,       -- never sample terrain larger than this

    islandMix     = 0.40,       -- weaker edge pull -> land fills the map
    islandPower   = 3.2,        -- concentrate the ocean falloff near the rim
    heightExponent = 1.05,      -- ~neutral; high values push land below the sea

    warpFreq     = 1.6,         -- frequency of the domain-warp field (broad,
                                -- curvy displacements across the whole map)
    warpStrength = 0.12,        -- how far samples are displaced (frac of map)

    oceanLevel    = 0.42,       -- water threshold
    beachLevel    = 0.46,       -- top of the sandy band
    hillsLevel    = 0.72,       -- narrower hills band (was 0.66 -> too dominant)
    mountainLevel = 0.79,
    snowLevel     = 0.85,       -- high peaks get snow caps
    sandThreshold = 0.5,        -- coasts above this sand-noise are sandy beaches

    moistureDry    = 0.18,
    moisturePlains = 0.42,
    moistureForest = 0.62,
    moistureWet    = 0.85,

    marshLakeThreshold = 0.62,  -- patch-noise peaks in the marsh become lakes

    aridSpread    = 0.6,        -- push moisture toward distinct dry/wet zones
    aridBand      = 0.55,       -- strength of large-scale dry regions
    poleDry       = 0.10,       -- extra dryness toward the map poles

    riverCount       = 12,
    riverSourceLevel = 0.55,    -- minimum elevation for a river source
    riverWidth       = 0.010,   -- river line width as a fraction of map width
    riverGreenRadius = 8,       -- sample cells of lush growth around rivers
    riverGreenStrength = 0.4,

    mountainRanges = 18,        -- traced peak-line chains in mountains/snow
    hillRanges     = 18,        -- traced peak-line chains in the hills
    rangeMinRidge  = 0.55,      -- min ridge value to start/continue a range
    rangeMinHeight = 0.62,
    rangeMaxSteps  = 420,       -- max points in one chain
    rangeGlyphStep = 1.0,       -- glyph spacing along a mountain chain (denser)
    hillGlyphStep  = 1.2,       -- glyph spacing along a hill chain
    snowGlyphStep  = 1.0,       -- tightest spacing on snowy peaks (jagged)

    forestDensity = 0.17,       -- base tree chance in a dense forest grove
    marshDensity  = 0.04,       -- tree chance in marsh (kept mostly open)

    siteCount      = 14,
    siteMinDist    = 32,        -- min separation between sites, in sample cells
    sitePadding    = 5,         -- keep sites this many sample cells from water
    roadWidthFrac  = 0.0016,    -- road line width as a fraction of map width
    siteRadiusFrac = 0.006,     -- site marker radius as a fraction of map width

    -- Road pathfinding (A* over the sample grid). Roads follow the lay of the
    -- land: they never cross impassable terrain (water, marsh lakes, snowy
    -- peaks), prefer cheap easy ground (plains/forest/valleys), and only cut
    -- through marsh/desert/mountains when there is no reasonable way around.
    roadPath = {
        blocked = { ocean = true, marsh_lake = true, snow = true },
        cost = {
            plains   = 1.00,
            beach    = 1.10,
            forest   = 1.15,
            cliff    = 1.55,
            hills    = 1.45,
            mountain = 2.60,
            desert   = 2.30,
            marsh    = 2.90,
        },
        climbCost       = 2.2,     -- extra cost per unit of elevation climbed
        heightCost      = 0.40,    -- extra cost per unit above the hills level
        valleyBonus     = 0.45,    -- cost discount per unit of valley (flow)
        shortcutMaxCost = 1.8,     -- straightening won't cut cells costing more
        maxExpansions   = 400000,  -- A* safety cap per road
    },

    -- art-bible palette (art-bible.md §4.1/4.3)
    palette = {
        ocean        = {  40,  50, 120 },  -- Deep Indigo
        oceanDeep    = {  26,  33,  86 },
        beach        = { 236, 214, 160 },  -- Parchment sand
        coast        = { 150,  84,  54 },  -- darker Terracotta waterline
        cliff        = { 118, 108, 118 },  -- rocky shore where the coast is steep
        plains       = { 116, 148,  88 },  -- grassland green
        plainsDry    = { 196, 176,  84 },  -- yellow-green dry-grass patches
        forest       = {  78, 128, 100 },  -- Verdigris
        forestDark   = {  58, 104,  82 },
        desert       = { 212, 172,  94 },  -- Ochre
        hills        = { 126, 124,  92 },  -- sage/olive: plains -> mountain transition
        hill         = { 118, 118,  86 },  -- raised hill mound (glyph)
        hillDark     = {  94,  96,  68 },  -- shaded flank of a mound
        plateau      = { 148, 144, 106 },  -- pale tone for flat elevated land
        marsh        = {  52, 102,  96 },  -- murky Verdigris swamp (darker +
                                            -- more teal than forest)
        marshLake    = {  34,  68,  74 },  -- dark water pocket inside marsh
        marshLakeDeep= {  22,  48,  54 },  -- deepest centre of a marsh lake
        mountain     = { 108, 104, 118 },  -- Charcoal rock
        mountainDark = {  84,  82,  96 },
        snow         = { 230, 215, 185 },  -- Parchment
        tree         = {  60, 118,  88 },  -- drawn tree canopy
        treeDark     = {  46,  96,  72 },
        lush         = {  92, 150, 112 },  -- river-greened land
        river        = {  62,  92, 148 },
        road         = { 196, 166, 106 },
        site         = { 235, 165,  35 },  -- Amber
    },
}

-- ---------------------------------------------------------------------------
-- Small utilities
-- ---------------------------------------------------------------------------

local function makeRng(seed)
    local state = math.max(1, math.floor(seed or CONFIG.defaultSeed))
    return function()
        state = (1103515245 * state + 12345) % 2147483648
        return state / 2147483648
    end
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function absPath(p)
    return love.filesystem.getSourceBaseDirectory() .. "/" .. p
end

local function ensureDir(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir and dir ~= "" then
        local d = dir:gsub("/", "\\")
        os.execute('mkdir "' .. d .. '" 2>nul')
    end
end

local function writeTextFile(path, text)
    ensureDir(path)
    local f = io.open(absPath(path), "w")
    if not f then
        error("map_generator: could not write " .. path)
    end
    f:write(text)
    f:close()
end

-- Read a "--name value" / "--name=value" option from the global arg table.
-- (love.arg.getOption is not reliably exposed in this LÖVE build.)
local function getOption(name, default)
    local args = _G.arg
    if type(args) ~= "table" then
        return default
    end
    for i = 1, #args do
        local token = tostring(args[i])
        if token:sub(1, 2) == "--" then
            local body = token:sub(3)
            local eq = body:find("=")
            if eq then
                if body:sub(1, eq - 1) == name then
                    return body:sub(eq + 1)
                end
            elseif body == name then
                local nextVal = args[i + 1]
                if nextVal ~= nil and tostring(nextVal):sub(1, 1) ~= "-" then
                    return tostring(nextVal)
                end
                return "true"
            end
        end
    end
    return default
end

-- --size WxH uses both values; --size W uses W as the width and derives the
-- height from the golden ratio so the map always keeps a landscape aspect.
local function parseSize(s)
    if not s then
        return CONFIG.defaultWidth, CONFIG.defaultHeight
    end
    local sw, sh = s:match("^(%d+)[xX,](%d+)$")
    if sw then
        local w, h = tonumber(sw), tonumber(sh)
        return (w and w > 0) and w or CONFIG.defaultWidth,
               (h and h > 0) and h or CONFIG.defaultHeight
    end
    local w = tonumber(s)
    if w and w > 0 then
        return w, math.max(1, math.floor(w / PHI))
    end
    return CONFIG.defaultWidth, CONFIG.defaultHeight
end

local function seedDir(seed)
    return "src/assets/map/generated/" .. seed
end

-- Progress logging: love.exe is a GUI app, so console output is invisible.
-- Mirror every log line into assets/map/generated/run.log as well.
local runLog = nil
local function log(msg)
    if not runLog then
        ensureDir("src/assets/map/generated/run.log")
        local ok, f = pcall(io.open, absPath("src/assets/map/generated/run.log"), "a")
        if ok then
            runLog = f
        end
    end
    if runLog then
        runLog:write(tostring(msg) .. "\n")
    end
    print(msg)
end

-- ---------------------------------------------------------------------------
-- Noise / height fields (procedural-gen patterns: fBm, island shaping,
-- redistribution, ridged transform; two decorrelated fields, per-seed offsets)
-- ---------------------------------------------------------------------------

-- LÖVE's love.math.noise is deterministic and cannot be seeded directly, so we
-- shift the sample coordinates by per-seed / per-channel offsets.
local function perlin(x, y, seed, channel)
    local ox = (seed % 104729) * 0.0013 + channel * 17.131
    local oy = (seed % 104729) * 0.0007 + channel * 31.719
    return love.math.noise(x + ox, y + oy)
end

local function fbm(seed, x, y, channel, octaves, lacunarity, gain)
    local total, amp, freq, norm = 0, 1, 1, 0
    for i = 1, octaves do
        total = total + amp * perlin(x * freq, y * freq, seed + i * 1013, channel)
        norm = norm + amp
        amp = amp * gain
        freq = freq * lacunarity
    end
    return total / norm
end

-- Fractal domain warp: displace the sample coordinates with a pair of
-- low-frequency fractal fields before evaluating fBm, so coastlines, rivers
-- and ridge lines wind and curl organically instead of reading as smooth
-- blobs. This is the classic "fractal noise" upgrade over plain fBm.
local function domainWarp(seed, u, v)
    local wx = fbm(seed + 271828, u * CONFIG.warpFreq, v * CONFIG.warpFreq, 0, 3, 2.0, 0.5) - 0.5
    local wy = fbm(seed + 314159, u * CONFIG.warpFreq, v * CONFIG.warpFreq, 1, 3, 2.0, 0.5) - 0.5
    return u + wx * CONFIG.warpStrength, v + wy * CONFIG.warpStrength
end

local function generateFields(seed, sampleW, sampleH)
    local height = {}
    local moisture = {}
    local ridge = {}
    local sand = {}
    local patch = {}
    for y = 1, sampleH do
        height[y] = {}
        moisture[y] = {}
        ridge[y] = {}
        sand[y] = {}
        patch[y] = {}
        local ny = (y - 0.5) / sampleH * 2 - 1
        local lat = math.abs(ny)               -- 0 equator, 1 pole
        for x = 1, sampleW do
            local nx = (x - 0.5) / sampleW * 2 - 1
            local u = (x - 0.5) / sampleW
            local v = (y - 0.5) / sampleH

            -- sample every fractal field through warped coordinates so all
            -- features share the same organic curl (coherent domain warp)
            local uw, vw = domainWarp(seed, u, v)

            local e = fbm(seed, uw * 2.4, vw * 2.4, 0, 5, 2.0, 0.5)
            local m = fbm(seed + 7919, uw * 2.2, vw * 2.2, 1, 4, 2.0, 0.5)
            local r = fbm(seed + 104729, uw * 3.0, vw * 3.0, 2, 4, 2.0, 0.5)
            r = 1 - math.abs(2 * r - 1)        -- ridged field for mountain spines
            local sd = fbm(seed + 33013, uw * 1.8, vw * 1.8, 4, 3, 2.0, 0.5)
            -- small-scale "patchiness": drives marsh lake pockets and the
            -- grove/clearing variation inside forests
            local pt = fbm(seed + 59049, uw * 6.5, vw * 6.5, 5, 2, 2.0, 0.5)

            -- island shaping: pull only the outer rim toward the sea so the
            -- interior stays land (much less ocean than before)
            local d = 1 - (1 - nx * nx) * (1 - ny * ny)
            d = math.pow(d, CONFIG.islandPower)
            e = e * (1 - CONFIG.islandMix) + (1 - d) * CONFIG.islandMix
            e = clamp(math.pow(clamp(e, 0, 1), CONFIG.heightExponent), 0, 1)

            -- moisture: push toward distinct dry / wet regions, add big dry
            -- belts (arid) and make the poles drier (cold desert / tundra)
            m = (m - 0.5) * (1 + CONFIG.aridSpread) + 0.5
            local arid = fbm(seed + 22073, uw * 1.1, vw * 1.1, 3, 3, 2.0, 0.5)
            m = m - (arid - 0.5) * CONFIG.aridBand
            m = m - lat * CONFIG.poleDry
            m = clamp(m, 0, 1)

            height[y][x] = e
            moisture[y][x] = m
            ridge[y][x] = r
            sand[y][x] = sd
            patch[y][x] = pt
        end
    end
    return height, moisture, ridge, sand, patch
end

-- ---------------------------------------------------------------------------
-- Colour helpers: smooth blending (no more hard biome edges)
-- ---------------------------------------------------------------------------

local function smoothstep(a, b, v)
    if b <= a then
        return v >= b and 1 or 0
    end
    v = clamp((v - a) / (b - a), 0, 1)
    return v * v * (3 - 2 * v)
end

-- ---------------------------------------------------------------------------
-- Biome classification
-- ---------------------------------------------------------------------------

-- Discrete biome label. Used for gameplay data (forest/mountain cells, ...)
-- and for deciding where drawn trees/mountains go. Coasts are sandy "beach"
-- where the sand-noise is high, and rocky "cliff" (no sand) elsewhere, so not
-- every coastline has a beach. Marsh lowlands whose patch-noise peaks into a
-- lake are labelled "marsh_lake" (their own biome, impassable) instead of
-- plain "marsh".
local function biomeOf(e, m, r, sand, patch)
    if e < CONFIG.oceanLevel then
        return "ocean"
    elseif e < CONFIG.beachLevel then
        return (sand > CONFIG.sandThreshold) and "beach" or "cliff"
    elseif e > CONFIG.snowLevel then
        return "snow"
    elseif e > CONFIG.mountainLevel then
        return (r > 0.45) and "mountain" or "hills"
    elseif e > CONFIG.hillsLevel then
        return "hills"
    elseif m < CONFIG.moistureDry then
        return "desert"
    elseif m < CONFIG.moisturePlains then
        return "plains"
    elseif m < CONFIG.moistureWet then
        return "forest"
    else
        if patch and patch > CONFIG.marshLakeThreshold then
            return "marsh_lake"
        end
        return "marsh"
    end
end

-- Per-pixel land colour, computed at the full output resolution from smoothly
-- interpolated fields, so coastlines and biome transitions are smooth (no
-- blocky upscaling). No allocations; returns r, g, b scalars.
local function pxColor(e, m, r, sand, lush, valley, patch)
    local p = CONFIG.palette
    valley = valley or 0

    if e < CONFIG.oceanLevel then
        local depth = clamp((CONFIG.oceanLevel - e) / CONFIG.oceanLevel, 0, 1)
        local t = smoothstep(0.2, 0.7, depth)
        local o, od = p.ocean, p.oceanDeep
        return o[1] + (od[1] - o[1]) * t, o[2] + (od[2] - o[2]) * t, o[3] + (od[3] - o[3]) * t
    end

    -- vegetation factor for the lowlands (0 = dry, 1 = lush)
    local veg = smoothstep(CONFIG.moistureDry, CONFIG.moistureForest, m)
    veg = veg * (1 - smoothstep(CONFIG.hillsLevel, CONFIG.snowLevel, e) * 0.65)

    -- hills/highland factors: dry -> desert yellow, wet -> green, flat -> plateau
    local dryW = 1 - smoothstep(CONFIG.moistureDry, CONFIG.moisturePlains, m)
    local wetW = smoothstep(CONFIG.moisturePlains, CONFIG.moistureForest, m)
    local platRidge = 1 - smoothstep(0.0, 0.30, r)   -- low ridge = flat land

    local cr, cg, cb
    if e < CONFIG.beachLevel then
        if sand > CONFIG.sandThreshold then
            cr, cg, cb = p.beach[1], p.beach[2], p.beach[3]
        else
            local t = smoothstep(0.0, 0.18, e - CONFIG.oceanLevel)
            local a, b = p.cliff, p.hills
            cr, cg, cb = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
        end
    elseif e < CONFIG.hillsLevel then
        -- ONE dryness ramp spanning the desert<->plains boundary, so the
        -- transition is a single smooth yellow -> yellow-green -> green (no
        -- banding: desert stays dry/yellow at its edge, plains green at its
        -- edge, instead of each side swinging to the other's colour)
        local dry = 1 - smoothstep(CONFIG.moistureDry - 0.05, CONFIG.moistureDry + 0.18, m)
        local a, b = p.desert, p.plains
        cr, cg, cb = a[1] + (b[1] - a[1]) * (1 - dry), a[2] + (b[2] - a[2]) * (1 - dry), a[3] + (b[3] - a[3]) * (1 - dry)
        -- dry-grass yellow spots: peak mid-transition, fade to 0 in pure
        -- desert and pure plains so they never form a second band
        local dryG = 4 * (1 - dry) * dry
        a = p.plainsDry
        cr, cg, cb = cr + (a[1] - cr) * dryG * 0.55, cg + (a[2] - cg) * dryG * 0.55, cb + (a[3] - cb) * dryG * 0.55
        a = p.forest
        cr, cg, cb = cr + (a[1] - cr) * veg, cg + (a[2] - cg) * veg, cb + (a[3] - cb) * veg
        local mt = smoothstep(CONFIG.moistureForest, CONFIG.moistureWet, m) * 0.75
        a = p.marsh
        cr, cg, cb = cr + (a[1] - cr) * mt, cg + (a[2] - cg) * mt, cb + (a[3] - cb) * mt
        -- marsh lakes: dark water pockets where the patch noise peaks, only in
        -- the wettest lowlands so forests keep their dry grove look
        local lg = smoothstep(CONFIG.moistureWet - 0.06, CONFIG.moistureWet + 0.02, m)
        local lake = smoothstep(0.62, 0.74, patch) * lg
        if lake > 0.01 then
            a = p.marshLake
            cr, cg, cb = cr + (a[1] - cr) * lake, cg + (a[2] - cg) * lake, cb + (a[3] - cb) * lake
            local deep = smoothstep(0.78, 0.88, patch) * lg
            if deep > 0.01 then
                a = p.marshLakeDeep
                cr, cg, cb = cr + (a[1] - cr) * deep, cg + (a[2] - cg) * deep, cb + (a[3] - cb) * deep
            end
        end
    elseif e < CONFIG.mountainLevel then
        -- Hills band. Elevation reads like the mountains: low hills stay
        -- plains-green (valleys), high hills are olive. Moisture adds
        -- variety -- dry hills take the desert's yellow, wet hills go green
        -- -- and flat elevated land shows as paler plateaus.
        local t = smoothstep(CONFIG.hillsLevel, CONFIG.mountainLevel, e)
        local a, b = p.plains, p.hills
        cr, cg, cb = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
        a = p.desert
        cr, cg, cb = cr + (a[1] - cr) * dryW * 0.55, cg + (a[2] - cg) * dryW * 0.55, cb + (a[3] - cb) * dryW * 0.55
        a = p.forest
        cr, cg, cb = cr + (a[1] - cr) * wetW * 0.45, cg + (a[2] - cg) * wetW * 0.45, cb + (a[3] - cb) * wetW * 0.45
        local plat = platRidge * smoothstep(CONFIG.hillsLevel + 0.02, CONFIG.hillsLevel + 0.12, e)
        a = p.plateau
        cr, cg, cb = cr + (a[1] - cr) * plat * 0.45, cg + (a[2] - cg) * plat * 0.45, cb + (a[3] - cb) * plat * 0.45
        -- hill crest lines: subtle ridge darkening so the ridges read clearly
        local rw = smoothstep(0.45, 0.70, r)
        if rw > 0.01 then
            a = p.hillDark
            cr, cg, cb = cr + (a[1] - cr) * rw * 0.35, cg + (a[2] - cg) * rw * 0.35, cb + (a[3] - cb) * rw * 0.35
        end
    elseif e < CONFIG.snowLevel then
        local h = smoothstep(CONFIG.mountainLevel, CONFIG.snowLevel, e)
        local a, b = p.mountain, p.hills
        cr, cg, cb = a[1] + (b[1] - a[1]) * (1 - h), a[2] + (b[2] - a[2]) * (1 - h), a[3] + (b[3] - a[3]) * (1 - h)
        if r > 0.45 then
            -- sharper crest lines: stronger ridge darkening for visibility
            a = p.mountainDark
            local rw = smoothstep(0.45, 0.70, r) * (0.3 + 0.5 * h)
            cr, cg, cb = cr + (a[1] - cr) * rw, cg + (a[2] - cg) * rw, cb + (a[3] - cb) * rw
        else
            -- rolling highlands (classified "hills"): same dry/wet/plateau
            -- variety as the hills band
            a = p.desert
            cr, cg, cb = cr + (a[1] - cr) * dryW * 0.55, cg + (a[2] - cg) * dryW * 0.55, cb + (a[3] - cb) * dryW * 0.55
            a = p.forest
            cr, cg, cb = cr + (a[1] - cr) * wetW * 0.45, cg + (a[2] - cg) * wetW * 0.45, cb + (a[3] - cb) * wetW * 0.45
            a = p.plateau
            cr, cg, cb = cr + (a[1] - cr) * platRidge * 0.45, cg + (a[2] - cg) * platRidge * 0.45, cb + (a[3] - cb) * platRidge * 0.45
        end
    else
        local t = smoothstep(CONFIG.snowLevel, 1.0, e)
        local a, b = p.mountain, p.snow
        cr, cg, cb = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
    end

    -- oases: greener land along rivers (lowlands only)
    if lush > 0 and e < CONFIG.hillsLevel then
        local a = p.lush
        cr, cg, cb = cr + (a[1] - cr) * lush, cg + (a[2] - cg) * lush, cb + (a[3] - cb) * lush
    end

    -- smooth coastal waterline on rocky shores only (sandy beaches stay clean)
    if e < CONFIG.beachLevel and sand <= CONFIG.sandThreshold then
        local wt = (1 - smoothstep(CONFIG.oceanLevel, CONFIG.oceanLevel + 0.025, e)) * 0.5
        if wt > 0.004 then
            local a = p.coast
            cr, cg, cb = cr + (a[1] - cr) * wt, cg + (a[2] - cg) * wt, cb + (a[3] - cb) * wt
        end
    end

    -- erosion / valley lines: where water gathers (flow accumulation) the
    -- terrain is shaded darker as indentations; strongest in the mountains,
    -- almost fully faded out by the time elevation drops into the hills
    local vs = valley * smoothstep(CONFIG.hillsLevel + 0.03, CONFIG.mountainLevel, e)
    if vs > 0.01 then
        cr, cg, cb = cr * (1 - vs * 0.36), cg * (1 - vs * 0.36), cb * (1 - vs * 0.36)
        -- a hint of gathered moisture (green) where the valley cuts lowlands
        if e < CONFIG.mountainLevel then
            local g = p.forest
            cr = cr + (g[1] - cr) * vs * 0.28
            cg = cg + (g[2] - cg) * vs * 0.28
            cb = cb + (g[3] - cb) * vs * 0.28
        end
    end

    return cr, cg, cb
end

-- Discrete biome labels (used for gameplay data and tree/mountain placement).
-- Colour is computed later, per output pixel, so the image stays smooth.
local function classifyBiomes(height, moisture, ridge, sand, patch, sampleW, sampleH)
    local biome = {}
    for y = 1, sampleH do
        biome[y] = {}
        for x = 1, sampleW do
            biome[y][x] = biomeOf(height[y][x], moisture[y][x], ridge[y][x], sand[y][x], patch and patch[y][x])
        end
    end
    return biome
end

-- ---------------------------------------------------------------------------
-- Rivers (steepest descent from high sources to the coast)
-- ---------------------------------------------------------------------------

local function generateRivers(height, sampleW, sampleH, seed)
    local rng = makeRng(seed + 31)
    local rivers = {}
    local isRiver = {}
    local target = CONFIG.riverCount
    local attempts = target * 80

    for _ = 1, attempts do
        if #rivers >= target then
            break
        end

        local x = math.floor(rng() * sampleW) + 1
        local y = math.floor(rng() * sampleH) + 1
        local e = height[y][x]
        if e < CONFIG.riverSourceLevel then
            goto continue
        end

        local path = {}
        local cx, cy = x, y
        local steps = 0
        local maxSteps = sampleW * 2
        while steps < maxSteps do
            local cellE = height[cy][cx]
            if cellE < CONFIG.oceanLevel then
                break
            end
            if isRiver[cy] and isRiver[cy][cx] then
                break -- merge into an existing river
            end
            table.insert(path, { x = cx, y = cy })

            -- steepest descent among the 8 neighbours
            local bx, by, be = cx, cy, cellE
            for dy = -1, 1 do
                for dx = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        local nx, ny = cx + dx, cy + dy
                        if nx >= 1 and nx <= sampleW and ny >= 1 and ny <= sampleH then
                            local ne = height[ny][nx]
                            if ne < be then
                                be, bx, by = ne, nx, ny
                            end
                        end
                    end
                end
            end
            if bx == cx and by == cy then
                break
            end
            cx, cy = bx, by
            steps = steps + 1
        end

        if #path >= 4 then
            for _, p in ipairs(path) do
                isRiver[p.y] = isRiver[p.y] or {}
                isRiver[p.y][p.x] = true
            end
            table.insert(rivers, path)
        end
        ::continue::
    end

    return rivers
end

-- ---------------------------------------------------------------------------
-- River greening, mountain chains, and the painted overlay
-- ---------------------------------------------------------------------------

-- River "lushness" weight field (0..1) painted around rivers on land. Sampled
-- bilinearly at full resolution, so oases fade smoothly into the terrain.
local function buildLushGrid(rivers, height, sampleW, sampleH)
    local lush = {}
    for y = 1, sampleH do
        lush[y] = {}
        for x = 1, sampleW do
            lush[y][x] = 0
        end
    end
    if #rivers == 0 then
        return lush
    end
    local R = CONFIG.riverGreenRadius
    local R2 = R * R
    local strength = CONFIG.riverGreenStrength
    for _, path in ipairs(rivers) do
        for _, pt in ipairs(path) do
            local cx, cy = math.floor(pt.x), math.floor(pt.y)
            for dy = -R, R do
                for dx = -R, R do
                    local x, y = cx + dx, cy + dy
                    if x >= 1 and x <= sampleW and y >= 1 and y <= sampleH then
                        local d2 = dx * dx + dy * dy
                        if d2 <= R2 then
                            local w = (1 - math.sqrt(d2) / R) * strength
                            if w > lush[y][x] and height[y][x] >= CONFIG.oceanLevel then
                                lush[y][x] = w
                            end
                        end
                    end
                end
            end
        end
    end
    return lush
end

-- 3x3 box blur: softens the D8 valley lines into organic, curvy channels.
local function blurField(field, sampleW, sampleH)
    local out = {}
    for y = 1, sampleH do
        out[y] = {}
        local y0, y1 = math.max(1, y - 1), math.min(sampleH, y + 1)
        for x = 1, sampleW do
            local sum, n = 0, 0
            local x0, x1 = math.max(1, x - 1), math.min(sampleW, x + 1)
            for yy = y0, y1 do
                local row = field[yy]
                for xx = x0, x1 do
                    sum = sum + row[xx]
                    n = n + 1
                end
            end
            out[y][x] = sum / n
        end
    end
    return out
end

-- D8 flow accumulation: every land cell sends 1 unit of water to its steepest
-- downhill neighbour, so cells where water gathers accumulate large flows.
-- Returns a 0..1 "valley" strength field (log-scaled, blurred) used to paint
-- erosion lines / valleys and to place hill & mountain glyphs along them.
local function buildValleyField(height, sampleW, sampleH)
    local oceanLevel = CONFIG.oceanLevel
    local B = 256   -- elevation buckets (process high -> low without a full sort)
    local buckets = {}
    for i = 1, B do
        buckets[i] = {}
    end
    local flow = {}
    for y = 1, sampleH do
        local row = height[y]
        for x = 1, sampleW do
            local e = row[x]
            if e >= oceanLevel then
                local idx = (y - 1) * sampleW + (x - 1)
                flow[idx] = 1
                local b = math.max(1, math.min(B, math.floor(e * B) + 1))
                buckets[b][#buckets[b] + 1] = idx
            end
        end
    end
    -- highest first, so a cell's upstream flow is added before it passes down
    for b = B, 1, -1 do
        local list = buckets[b]
        for i = 1, #list do
            local idx = list[i]
            local x = idx % sampleW + 1
            local y = math.floor(idx / sampleW) + 1
            local ey, ex = y, x
            local be = height[y][x]
            for dy = -1, 1 do
                local ny = y + dy
                if ny >= 1 and ny <= sampleH then
                    local nrow = height[ny]
                    for dx = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            local nx = x + dx
                            if nx >= 1 and nx <= sampleW then
                                local ne = nrow[nx]
                                if ne < be then
                                    be = ne
                                    ey, ex = ny, nx
                                end
                            end
                        end
                    end
                end
            end
            if ey ~= y or ex ~= x then
                local down = (ey - 1) * sampleW + (ex - 1)
                local f = flow[down]
                if f then
                    flow[down] = f + flow[idx]
                end
            end
        end
    end
    -- log-scaled 0..1 strength (only the significant drainages show)
    local lLo, lHi = 3.0, 10.5   -- flow 2^lLo .. 2^lHi maps to 0..1
    local valley = {}
    for y = 1, sampleH do
        local row = {}
        local base = (y - 1) * sampleW
        for x = 1, sampleW do
            local f = flow[base + x - 1]
            local v = 0
            if f and f > 6 then
                v = clamp((math.log(f) / math.log(2) - lLo) / (lHi - lLo), 0, 1)
            end
            row[x] = v
        end
        valley[y] = row
    end
    -- smooth the D8 lines into organic, curvy channels (two passes)
    valley = blurField(valley, sampleW, sampleH)
    valley = blurField(valley, sampleW, sampleH)
    return valley
end

-- Walk a single chain of high-ridge cells so ridges form connected crest
-- lines (not scattered peaks). cfg band-constrains the chain. Returns a
-- polyline in sample coordinates.
local function traceRidgeChain(ridge, height, sampleW, sampleH, rng, cfg)
    local minRidge = cfg.minRidge or CONFIG.rangeMinRidge
    local minHeight = cfg.minHeight or CONFIG.rangeMinHeight
    local stopHeight = cfg.stopHeight or (CONFIG.mountainLevel - 0.20)
    local maxHeight = cfg.maxHeight or 1
    local maxSteps = cfg.maxSteps or CONFIG.rangeMaxSteps

    -- find a strong seed cell
    local sx, sy
    local found = false
    for _ = 1, 400 do
        local x = math.floor(rng() * sampleW) + 1
        local y = math.floor(rng() * sampleH) + 1
        local e = height[y][x]
        if ridge[y][x] > minRidge and e > minHeight and e <= maxHeight then
            sx, sy, found = x, y, true
            break
        end
    end
    if not found then
        return nil
    end

    local points = { { x = sx, y = sy } }
    local cx, cy = sx, sy
    local heading = rng() * math.pi * 2
    for step = 1, maxSteps do
        local bestX, bestY, bestScore = cx, cy, -1e9
        for dy = -2, 2 do
            for dx = -2, 2 do
                if dx ~= 0 or dy ~= 0 then
                    local nx, ny = cx + dx, cy + dy
                    if nx >= 1 and nx <= sampleW and ny >= 1 and ny <= sampleH then
                        local len = math.sqrt(dx * dx + dy * dy)
                        local align = (dx * math.cos(heading) + dy * math.sin(heading)) / len
                        local score = ridge[ny][nx] * 1.6
                            + height[ny][nx] * 1.2
                            + align * 0.8
                            + (rng() - 0.5) * 0.4
                        if score > bestScore then
                            bestScore, bestX, bestY = score, nx, ny
                        end
                    end
                end
            end
        end
        if bestX == cx and bestY == cy then
            break
        end
        -- stop when we wander well out of the ridge band (keeps chains long)
        if height[bestY][bestX] < stopHeight
            or height[bestY][bestX] > maxHeight
            or ridge[bestY][bestX] < minRidge - 0.20 then
            break
        end
        cx, cy = bestX, bestY
        local prev = points[#points]
        heading = heading * 0.7 + math.atan2(cy - prev.y, cx - prev.x) * 0.3
        points[#points + 1] = { x = cx, y = cy }
    end
    return points
end

local function generateRanges(ridge, height, sampleW, sampleH, seed, count, cfg)
    local rng = makeRng(seed + 57)
    local ranges = {}
    for _ = 1, count * 3 do
        local r = traceRidgeChain(ridge, height, sampleW, sampleH, rng, cfg)
        if r and #r >= 12 then
            table.insert(ranges, r)
            if #ranges >= count then
                break
            end
        end
    end
    return ranges
end

-- ---------------------------------------------------------------------------
-- Painted glyphs (mountains + trees) baked into a transparent overlay layer
-- ---------------------------------------------------------------------------

local function setPx(img, x, y, r, g, b)
    local w, h = img:getDimensions()
    if x >= 0 and x < w and y >= 0 and y < h then
        img:setPixel(x, y, r / 255, g / 255, b / 255, 1)
    end
end

local function fillTriangle(img, x0, y0, x1, y1, x2, y2, r, g, b)
    local pts = { { x0, y0 }, { x1, y1 }, { x2, y2 } }
    table.sort(pts, function(a, bb) return a[2] < bb[2] end)
    local ymin, ymax = math.floor(pts[1][2]), math.ceil(pts[3][2])
    for y = ymin, ymax do
        local xs = {}
        for i = 1, 3 do
            local j = i % 3 + 1
            local ax, ay = pts[i][1], pts[i][2]
            local bx, by = pts[j][1], pts[j][2]
            if (ay <= y + 0.5 and by > y + 0.5) or (by <= y + 0.5 and ay > y + 0.5) then
                local t = (y + 0.5 - ay) / (by - ay)
                xs[#xs + 1] = ax + (bx - ax) * t
            end
        end
        if #xs == 2 then
            local xa, xb = math.floor(math.min(xs[1], xs[2])), math.ceil(math.max(xs[1], xs[2]))
            for x = xa, xb do
                setPx(img, x, y, r, g, b)
            end
        end
    end
end

local function fillCircle(img, cx, cy, rad, r, g, b)
    local r2 = rad * rad
    for dy = -rad, rad do
        for dx = -rad, rad do
            if dx * dx + dy * dy <= r2 then
                setPx(img, cx + dx, cy + dy, r, g, b)
            end
        end
    end
end

-- Upper half of a disc: a flat-bottomed dome, used for hill mounds.
local function fillDome(img, cx, cy, rad, r, g, b)
    local r2 = rad * rad
    for dy = -rad, 0 do
        for dx = -rad, rad do
            if dx * dx + dy * dy <= r2 then
                setPx(img, cx + dx, cy + dy, r, g, b)
            end
        end
    end
end

local function drawMountain(img, cx, cy, u)
    local p = CONFIG.palette
    local w = math.max(2, math.floor(3 * u))     -- half width at this scale
    local h = math.max(2, math.floor(3 * u))     -- half height
    -- shaded peak
    fillTriangle(img, cx - w, cy + h, cx + w, cy + h, cx, cy - h,
        p.mountain[1], p.mountain[2], p.mountain[3])
    -- shadowed east face
    local eo = math.max(0, math.floor(w * 0.33))
    local ty = math.max(0, math.floor(h * 0.33))
    fillTriangle(img, cx + eo, cy - ty, cx + w, cy + h, cx + eo, cy + h,
        p.mountainDark[1], p.mountainDark[2], p.mountainDark[3])
    -- snow cap
    local sw2 = math.max(1, math.floor(w * 0.4))
    local sh2 = math.max(1, math.floor(h * 0.4))
    fillTriangle(img, cx - sw2, cy - h + sh2, cx + sw2, cy - h + sh2, cx, cy - h,
        p.snow[1], p.snow[2], p.snow[3])
end

local function drawTree(img, cx, cy, u)
    local p = CONFIG.palette
    local tr = math.max(1, math.floor(u * 0.5))
    for i = 0, tr do
        setPx(img, cx, cy + i, 92, 70, 52)
    end
    local rad = math.max(1, math.floor(1.6 * u))
    local cy0 = cy - math.max(1, math.floor(u * 0.6))
    fillCircle(img, cx, cy0, rad, p.tree[1], p.tree[2], p.tree[3])
    setPx(img, cx - math.max(1, math.floor(rad * 0.6)), cy0 - math.max(1, math.floor(rad * 0.5)),
        p.treeDark[1], p.treeDark[2], p.treeDark[3])
end

-- A low rounded hill mound (dome with a shaded right flank) so hills read as
-- gentle bumps, distinct from the sharp snow-capped mountain triangles.
local function drawHill(img, cx, cy, u)
    local p = CONFIG.palette
    local r = math.max(2, math.floor(1.5 * u))
    fillDome(img, cx, cy, r, p.hill[1], p.hill[2], p.hill[3])
    local sr = math.max(1, math.floor(r * 0.8))
    fillDome(img, cx + math.max(1, math.floor(r * 0.25)), cy, sr,
        p.hillDark[1], p.hillDark[2], p.hillDark[3])
end

-- Bake mountains + trees into a transparent overlay at FULL target resolution,
-- scaled from the sample-space chains / forest cells (u = targetW / sampleW).
local function makeOverlay(targetW, targetH, biome, mountainChains, hillChains, patch, seed, u)
    -- newImageData starts fully transparent (0,0,0,0), so no clear pass needed
    local img = love.image.newImageData(targetW, targetH)

    local rng = makeRng(seed + 199)

    -- ridge / peak lines: glyphs are placed ONLY along the traced chains, in
    -- the biome each point lands in (hills -> mound, mountain/snow -> peak),
    -- so the map shows crest lines instead of a glyph fill across a biome.
    -- Snowy peaks get the tightest spacing (the most jagged).
    local function chainStep(b)
        if b == "snow" then return CONFIG.snowGlyphStep end
        if b == "mountain" then return CONFIG.rangeGlyphStep end
        return CONFIG.hillGlyphStep
    end
    local function drawChain(chain)
        local lx, ly = chain[1].x, chain[1].y
        local dist = 0
        for _, pt in ipairs(chain) do
            dist = dist + math.abs(pt.x - lx) + math.abs(pt.y - ly)
            lx, ly = pt.x, pt.y
            local py = math.floor(pt.y)
            local px = math.floor(pt.x)
            local b = biome[py] and biome[py][px]
            if dist >= chainStep(b) then
                local gx = math.floor((pt.x - 0.5) * u)
                local gy = math.floor((pt.y - 0.5) * u)
                if b == "hills" then
                    drawHill(img, gx, gy, u)
                elseif b == "mountain" or b == "snow" then
                    drawMountain(img, gx, gy, u)
                end
                dist = 0
            end
        end
    end
    for _, c in ipairs(mountainChains) do drawChain(c) end
    for _, c in ipairs(hillChains) do drawChain(c) end

    -- trees: forest gets blobby groves/clearings (density driven by the patch
    -- noise, so dense groves clump and clearings stay open); marsh is kept
    -- mostly open with only a few scattered trees
    local sw = math.max(1, math.floor(targetW / u + 0.5))
    local sh = math.max(1, math.floor(targetH / u + 0.5))
    for y = 2, sh - 2 do
        local row = biome[y]
        local prow = patch[y]
        for x = 2, sw - 2 do
            local b = row and row[x]
            if b == "forest" or b == "marsh" then
                local dens
                if b == "forest" then
                    dens = CONFIG.forestDensity * (0.15 + 2.4 * (prow and prow[x] or 0.5))
                    dens = clamp(dens, 0.02, 0.9)
                else
                    dens = CONFIG.marshDensity
                end
                if rng() < dens then
                    local tx = math.floor((x - 0.5) * u)
                    local ty = math.floor((y - 0.5) * u)
                    drawTree(img, tx, ty, u)
                    -- grove clustering: clump extra trees when this cell is
                    -- dense so groves stay tight and clearings stay open
                    if b == "forest" then
                        if rng() < dens then drawTree(img, tx + math.floor(u), ty, u) end
                        if rng() < dens then drawTree(img, tx, ty + math.floor(u), u) end
                        if rng() < dens * 0.6 then drawTree(img, tx + math.floor(u), ty + math.floor(u), u) end
                    end
                end
            end
        end
    end

    return img
end

-- ---------------------------------------------------------------------------
-- ImageData helpers
-- ---------------------------------------------------------------------------

-- Render the base terrain at the FULL target resolution: the coarse noise
-- fields are bilinearly interpolated per pixel and coloured with pxColor, so
-- coastlines and biome edges come out smooth instead of blocky.
local function renderBaseFull(height, moisture, ridge, sand, lush, valley, patch,
                              targetW, targetH, sampleW, sampleH)
    local img = love.image.newImageData(targetW, targetH)
    local su = sampleW / targetW
    local sv = sampleH / targetH
    for py = 0, targetH - 1 do
        local fy = (py + 0.5) * sv - 0.5
        local y0 = math.max(0, math.floor(fy))
        local y1 = math.min(sampleH - 1, y0 + 1)
        local ty = fy - y0
        local rh1, rh2 = height[y0 + 1], height[y1 + 1]
        local rm1, rm2 = moisture[y0 + 1], moisture[y1 + 1]
        local rr1, rr2 = ridge[y0 + 1], ridge[y1 + 1]
        local rs1, rs2 = sand[y0 + 1], sand[y1 + 1]
        local rl1, rl2 = lush[y0 + 1], lush[y1 + 1]
        local rv1, rv2 = valley[y0 + 1], valley[y1 + 1]
        local rp1, rp2 = patch[y0 + 1], patch[y1 + 1]
        for px = 0, targetW - 1 do
            local fx = (px + 0.5) * su - 0.5
            local x0 = math.max(0, math.floor(fx))
            local x1 = math.min(sampleW - 1, x0 + 1)
            local tx = fx - x0
            local a, b, c, d

            a, b = rh1[x0 + 1], rh1[x1 + 1]
            c, d = rh2[x0 + 1], rh2[x1 + 1]
            local e = a + (b - a) * tx + (c - a) * ty + (a + d - b - c) * tx * ty

            a, b = rm1[x0 + 1], rm1[x1 + 1]
            c, d = rm2[x0 + 1], rm2[x1 + 1]
            local m = a + (b - a) * tx + (c - a) * ty + (a + d - b - c) * tx * ty

            a, b = rr1[x0 + 1], rr1[x1 + 1]
            c, d = rr2[x0 + 1], rr2[x1 + 1]
            local r = a + (b - a) * tx + (c - a) * ty + (a + d - b - c) * tx * ty

            a, b = rs1[x0 + 1], rs1[x1 + 1]
            c, d = rs2[x0 + 1], rs2[x1 + 1]
            local sd = a + (b - a) * tx + (c - a) * ty + (a + d - b - c) * tx * ty

            a, b = rl1[x0 + 1], rl1[x1 + 1]
            c, d = rl2[x0 + 1], rl2[x1 + 1]
            local lu = a + (b - a) * tx + (c - a) * ty + (a + d - b - c) * tx * ty

            a, b = rv1[x0 + 1], rv1[x1 + 1]
            c, d = rv2[x0 + 1], rv2[x1 + 1]
            local vl = a + (b - a) * tx + (c - a) * ty + (a + d - b - c) * tx * ty

            a, b = rp1[x0 + 1], rp1[x1 + 1]
            c, d = rp2[x0 + 1], rp2[x1 + 1]
            local pt = a + (b - a) * tx + (c - a) * ty + (a + d - b - c) * tx * ty

            local cr, cg, cb = pxColor(e, m, r, sd, lu, vl, pt)
            img:setPixel(px, py, cr / 255, cg / 255, cb / 255, 1)
        end
    end
    return img
end

local function persistField(path, field, sampleW, sampleH)
    local img = love.image.newImageData(sampleW, sampleH)
    for y = 1, sampleH do
        for x = 1, sampleW do
            local v = clamp(field[y][x], 0, 1)
            img:setPixel(x - 1, y - 1, v, v, v, 1)
        end
    end
    ensureDir(absPath(path))
    img:encode("png", absPath(path))
end

local function loadField(path, sampleW, sampleH)
    local img = love.image.newImageData(absPath(path))
    local field = {}
    for y = 1, sampleH do
        field[y] = {}
        for x = 1, sampleW do
            local r = img:getPixel(x - 1, y - 1)
            field[y][x] = r
        end
    end
    return field
end

-- ---------------------------------------------------------------------------
-- Stage "world": terrain + render + persistence
-- ---------------------------------------------------------------------------

-- Generate a complete world terrain (height/moisture/ridge/biomes/rivers) and
-- return everything needed to render it. Pure CPU; no file I/O, no quitting.
-- Result: { seed, targetW, targetH, sampleW, sampleH, base (ImageData),
--           overlay (ImageData: drawn mountains + trees), rivers, mountains,
--           biome, height, moisture }
local function generateWorld(seed, targetW, targetH, detail)
    detail = math.max(1, detail or CONFIG.defaultDetail)
    -- Field buffer keeps the target aspect ratio. It is a divisor of the
    -- output: the base is rendered per-pixel at FULL resolution from these
    -- smoothly interpolated fields, so the result is crisp, not blocky.
    local longest = math.max(targetW, targetH)
    local scale = clamp(longest / detail, CONFIG.minSample, CONFIG.maxSample) / longest
    local sampleW = math.max(1, math.floor(targetW * scale + 0.5))
    local sampleH = math.max(1, math.floor(targetH * scale + 0.5))

    local height, moisture, ridge, sand, patch = generateFields(seed, sampleW, sampleH)
    local biome = classifyBiomes(height, moisture, ridge, sand, patch, sampleW, sampleH)
    local rivers = generateRivers(height, sampleW, sampleH, seed)
    local lush = buildLushGrid(rivers, height, sampleW, sampleH)
    local valley = buildValleyField(height, sampleW, sampleH)
    local mountainChains = generateRanges(ridge, height, sampleW, sampleH, seed + 1,
        CONFIG.mountainRanges, {
            minRidge   = CONFIG.rangeMinRidge,
            minHeight  = CONFIG.rangeMinHeight,
            stopHeight = CONFIG.mountainLevel - 0.20,
            maxHeight  = 1,
        })
    local hillChains = generateRanges(ridge, height, sampleW, sampleH, seed + 2,
        CONFIG.hillRanges, {
            minRidge   = 0.38,
            minHeight  = CONFIG.hillsLevel - 0.05,
            stopHeight = CONFIG.hillsLevel - 0.12,
            maxHeight  = CONFIG.mountainLevel - 0.02,
        })
    local base = renderBaseFull(height, moisture, ridge, sand, lush, valley, patch,
        targetW, targetH, sampleW, sampleH)
    local overlay = makeOverlay(targetW, targetH, biome, mountainChains, hillChains, patch, seed, targetW / sampleW)

    return {
        seed      = seed,
        targetW   = targetW,
        targetH   = targetH,
        sampleW   = sampleW,
        sampleH   = sampleH,
        base      = base,      -- full-resolution ImageData (targetW x targetH)
        overlay   = overlay,   -- full-resolution glyph overlay
        rivers    = rivers,    -- polylines in sample coords
        mountains = mountainChains, -- traced peak lines (mountains/snow)
        hillChains = hillChains,    -- traced peak lines (hills)
        biome     = biome,
        height    = height,
        moisture  = moisture,
        ridge     = ridge,
        sand      = sand,
        valley    = valley,
        patch     = patch,
    }
end

local function prepareWorld()
    local seed = tonumber(getOption("seed", CONFIG.defaultSeed)) or CONFIG.defaultSeed
    local targetW, targetH = parseSize(getOption("size"))
    local detail = tonumber(getOption("detail", CONFIG.defaultDetail)) or CONFIG.defaultDetail

    local world = generateWorld(seed, targetW, targetH, detail)

    log(("[map] generating world: seed=%d size=%dx%d sample=%dx%d")
        :format(seed, world.targetW, world.targetH, world.sampleW, world.sampleH))

    local dir = seedDir(seed)
    writeTextFile(dir .. "/meta.lua",
        string.format("return { seed = %d, sizeW = %d, sizeH = %d, sampleW = %d, sampleH = %d }\n",
            seed, world.targetW, world.targetH, world.sampleW, world.sampleH))
    persistField(dir .. "/height.png", world.height, world.sampleW, world.sampleH)
    persistField(dir .. "/moisture.png", world.moisture, world.sampleW, world.sampleH)

    pending = {
        stage     = "world",
        seed      = seed,
        targetW   = world.targetW,
        targetH   = world.targetH,
        sampleW   = world.sampleW,
        sampleH   = world.sampleH,
        base      = world.base,
        overlay   = world.overlay,
        rivers    = world.rivers,
        mountains = world.mountains,
        out       = getOption("out", dir .. "/world.png"),
    }
    log("[map] world terrain ready; rendering...")
end

-- ---------------------------------------------------------------------------
-- Stage "sites": sites + roads on top of the finished world
-- ---------------------------------------------------------------------------

-- Place site markers on land. When a biome grid is supplied, cells that are
-- "ocean" or "marsh_lake" are excluded so sites never spawn on water.
local function placeSites(height, sampleW, sampleH, seed, biome, siteCount)
    siteCount = siteCount or CONFIG.siteCount
    local rng = makeRng(seed + 101)
    local sites = {}
    local candidates = {}
    for y = 1 + CONFIG.sitePadding, sampleH - CONFIG.sitePadding do
        for x = 1 + CONFIG.sitePadding, sampleW - CONFIG.sitePadding do
            local okCell = height[y][x] >= CONFIG.oceanLevel
            if okCell and biome then
                local b = biome[y][x]
                if b == "ocean" or b == "marsh_lake" then
                    okCell = false
                end
            end
            if okCell then
                table.insert(candidates, { x = x, y = y })
            end
        end
    end
    if #candidates == 0 then
        return sites
    end

    local minDistSq = CONFIG.siteMinDist * CONFIG.siteMinDist
    local attempts = siteCount * 200
    for _ = 1, attempts do
        if #sites >= siteCount then
            break
        end
        local c = candidates[math.floor(rng() * #candidates) + 1]
        local ok = true
        for _, s in ipairs(sites) do
            local dx = s.x - c.x
            local dy = s.y - c.y
            if dx * dx + dy * dy < minDistSq then
                ok = false
                break
            end
        end
        if ok then
            table.insert(sites, { id = "site_" .. (#sites + 1), x = c.x, y = c.y })
        end
    end

    -- fallback: fill remaining sites greedily
    while #sites < siteCount and #candidates > 0 do
        local c = candidates[math.floor(rng() * #candidates) + 1]
        table.insert(sites, { id = "site_" .. (#sites + 1), x = c.x, y = c.y })
    end
    return sites
end

local function computeConnections(sites)
    local n = #sites
    if n <= 1 then
        return {}
    end
    local edges = {}
    for i = 1, n do
        for j = i + 1, n do
            local dx = sites[i].px - sites[j].px
            local dy = sites[i].py - sites[j].py
            table.insert(edges, { a = i, b = j, d2 = dx * dx + dy * dy })
        end
    end
    table.sort(edges, function(l, r) return l.d2 < r.d2 end)

    local parent = {}
    for i = 1, n do
        parent[i] = i
    end
    local function find(i)
        while parent[i] ~= i do
            i = parent[i]
        end
        return i
    end

    local chosen = {}
    for _, e in ipairs(edges) do
        local pa, pb = find(e.a), find(e.b)
        if pa ~= pb then
            parent[pb] = pa
            table.insert(chosen, e)
        end
    end
    return chosen
end

-- ---------------------------------------------------------------------------
-- Road pathfinding
--
-- Real roads follow the lay of the land: they hug valleys and gentle ground,
-- avoid marshes, deserts and mountains, and never cross impassable snowy
-- peaks. A road between two sites is an A* search over the (coarse) sample
-- grid that minimises a terrain-aware cost, instead of drawing a straight
-- line and nudging around water.
-- ---------------------------------------------------------------------------

local SQRT2 = math.sqrt(2)

local ROAD_DIRS = {
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
    { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 },
}

-- Pixel coordinate -> 1-based sample cell (the same mapping the old water
-- lookup used, so roads still start/end exactly on the sites' sample cells).
local function roadCellOf(px, py, targetW, targetH, sampleW, sampleH)
    local x = math.floor((px - 0.5) / targetW * sampleW + 0.5)
    local y = math.floor((py - 0.5) / targetH * sampleH + 0.5)
    return clamp(x, 1, sampleW), clamp(y, 1, sampleH)
end

-- Movement cost of entering a cell, or nil when the cell is impassable.
-- Blocked: open water, marsh lakes and snowy peaks (all unwalkable in-game).
-- Passable but avoided: marsh, desert and mountains. Valleys (high water
-- flow) are cheaper, so roads naturally follow drainages.
local function roadCellCost(x, y, height, biome, valley, cfg)
    if height[y][x] < CONFIG.oceanLevel then
        return nil
    end
    local b = biome and biome[y] and biome[y][x]
    if not b then
        return 1.0 -- no biome grid (file-export stage): keep it plain
    end
    if cfg.blocked[b] then
        return nil
    end
    local c = cfg.cost[b] or 1.0
    local e = height[y][x]
    if e > CONFIG.hillsLevel then
        c = c + (e - CONFIG.hillsLevel) * cfg.heightCost
    end
    if valley and valley[y] then
        local v = valley[y][x] or 0
        if v > 0 then
            c = c - v * cfg.valleyBonus
        end
    end
    return math.max(0.4, c)
end

-- Octile distance (8-connected grid), scaled below the cheapest real step so
-- the heuristic stays roughly admissible and valley routes are not dismissed
-- too early.
local function roadHeuristic(dx, dy)
    local adx, ady = math.abs(dx), math.abs(dy)
    local diag = math.min(adx, ady)
    return (adx + ady - diag + diag * SQRT2) * 0.5
end

local function heapPush(heap, node)
    heap[#heap + 1] = node
    local i = #heap
    while i > 1 do
        local p = math.floor(i / 2)
        if heap[p].f <= heap[i].f then
            break
        end
        heap[p], heap[i] = heap[i], heap[p]
        i = p
    end
end

local function heapPop(heap)
    local top = heap[1]
    local last = heap[#heap]
    heap[#heap] = nil
    if #heap > 0 then
        heap[1] = last
        local i = 1
        while true do
            local l, r = i * 2, i * 2 + 1
            local m = i
            if l <= #heap and heap[l].f < heap[m].f then m = l end
            if r <= #heap and heap[r].f < heap[m].f then m = r end
            if m == i then break end
            heap[i], heap[m] = heap[m], heap[i]
            i = m
        end
    end
    return top
end

-- Snap a sample cell to the nearest non-blocked cell (expanding ring). Used
-- when a site sits on (or right against) a blocked cell after snapping.
local function snapToOpenRoad(x, y, height, biome, valley, cfg, sampleW, sampleH)
    if roadCellCost(x, y, height, biome, valley, cfg) then
        return x, y
    end
    for r = 1, 8 do
        for dy = -r, r do
            for dx = -r, r do
                if math.max(math.abs(dx), math.abs(dy)) == r then
                    local nx, ny = x + dx, y + dy
                    if nx >= 1 and nx <= sampleW and ny >= 1 and ny <= sampleH
                        and roadCellCost(nx, ny, height, biome, valley, cfg) then
                        return nx, ny
                    end
                end
            end
        end
    end
    return nil
end

-- Sample the straight pixel segment A->B at ~4px intervals; returns false if
-- any cell it crosses is impassable or costs more than the shortcut cap.
local function roadShortcutClear(ax, ay, bx, by, height, biome, valley, cfg,
                                 targetW, targetH, sampleW, sampleH)
    local dx, dy = bx - ax, by - ay
    local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / 4))
    for i = 1, steps do
        local t = i / steps
        local x, y = roadCellOf(ax + dx * t, ay + dy * t, targetW, targetH, sampleW, sampleH)
        local c = roadCellCost(x, y, height, biome, valley, cfg)
        if not c or c > cfg.shortcutMaxCost then
            return false
        end
    end
    return true
end

-- Terrain-following road between two pixel points. Returns a list of
-- { x, y } pixel points (or nil when no path exists).
local function traceRoad(ax, ay, bx, by, height, biome, valley,
                         sampleW, sampleH, targetW, targetH)
    local cfg = CONFIG.roadPath
    local sx, sy = roadCellOf(ax, ay, targetW, targetH, sampleW, sampleH)
    local gx, gy = roadCellOf(bx, by, targetW, targetH, sampleW, sampleH)
    sx, sy = snapToOpenRoad(sx, sy, height, biome, valley, cfg, sampleW, sampleH)
    gx, gy = snapToOpenRoad(gx, gy, height, biome, valley, cfg, sampleW, sampleH)
    if not sx or not gx then
        return nil
    end

    local function key(x, y) return (y - 1) * sampleW + x end

    local startK, goalK = key(sx, sy), key(gx, gy)
    if startK == goalK then
        return { { x = bx, y = by } }
    end

    local gScore, parent, closed = {}, {}, {}
    local heap = {}
    gScore[startK] = 0
    heapPush(heap, { f = roadHeuristic(gx - sx, gy - sy), g = 0, x = sx, y = sy })

    local found, expansions = false, 0
    while #heap > 0 do
        expansions = expansions + 1
        if expansions > cfg.maxExpansions then
            break
        end
        local cur = heapPop(heap)
        local ck = key(cur.x, cur.y)
        if not closed[ck] then
            closed[ck] = true
            if ck == goalK then
                found = true
                break
            end
            local ce = height[cur.y][cur.x]
            for _, d in ipairs(ROAD_DIRS) do
                local nx, ny = cur.x + d[1], cur.y + d[2]
                if nx >= 1 and nx <= sampleW and ny >= 1 and ny <= sampleH then
                    local nc = roadCellCost(nx, ny, height, biome, valley, cfg)
                    if nc then
                        local nk = key(nx, ny)
                        if not closed[nk] then
                            local step = (d[1] ~= 0 and d[2] ~= 0) and SQRT2 or 1.0
                            local climb = math.max(0, height[ny][nx] - ce) * cfg.climbCost
                            local ng = cur.g + (nc + climb) * step
                            if not gScore[nk] or ng < gScore[nk] then
                                gScore[nk] = ng
                                parent[nk] = ck
                                heapPush(heap, {
                                    f = ng + roadHeuristic(gx - nx, gy - ny),
                                    g = ng, x = nx, y = ny,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    if not found then
        return nil
    end

    -- Reconstruct the cell path (goal -> start), then reverse it.
    local cells = {}
    local ck = goalK
    while ck do
        local x = (ck - 1) % sampleW + 1
        local y = math.floor((ck - 1) / sampleW) + 1
        cells[#cells + 1] = { x = x, y = y }
        if ck == startK then
            break
        end
        ck = parent[ck]
    end
    local pts = {}
    for i = #cells, 1, -1 do
        pts[#pts + 1] = {
            x = (cells[i].x - 0.5) / sampleW * targetW,
            y = (cells[i].y - 0.5) / sampleH * targetH,
        }
    end
    if #pts < 2 then
        return pts
    end
    pts[1].x, pts[1].y = ax, ay
    pts[#pts].x, pts[#pts].y = bx, by

    -- String-pull: drop waypoints where a straight line stays on clear ground,
    -- so the road straightens out along easy terrain instead of stair-stepping.
    local pulled = { pts[1] }
    for i = 2, #pts do
        local last = pulled[#pulled]
        if i == #pts then
            if last ~= pts[i] then
                pulled[#pulled + 1] = pts[i]
            end
        elseif not roadShortcutClear(last.x, last.y, pts[i].x, pts[i].y,
                height, biome, valley, cfg, targetW, targetH, sampleW, sampleH) then
            if last ~= pts[i - 1] then
                pulled[#pulled + 1] = pts[i - 1]
            end
        end
    end

    -- Gentle 2-pass moving average so the polyline reads as a curved road.
    local smoothed = pulled
    for _ = 1, 2 do
        if #smoothed < 3 then
            break
        end
        local out = { smoothed[1] }
        for i = 2, #smoothed - 1 do
            local p0, p1, p2 = smoothed[i - 1], smoothed[i], smoothed[i + 1]
            out[#out + 1] = {
                x = (p0.x + p1.x * 2 + p2.x) / 4,
                y = (p0.y + p1.y * 2 + p2.y) / 4,
            }
        end
        out[#out + 1] = smoothed[#smoothed]
        smoothed = out
    end

    return smoothed
end

-- ---------------------------------------------------------------------------
-- In-memory sites + roads (used by the in-game painted-map loader and the
-- file-based "sites" stage). Sites come back in BOTH sample coordinates
-- (x, y) and pixel coordinates (px, py), plus their biome label.
-- ---------------------------------------------------------------------------

local function placeSitesForMap(height, biome, sampleW, sampleH, targetW, targetH, seed, siteCount)
    local sites = placeSites(height, sampleW, sampleH, seed, biome, siteCount)
    for _, s in ipairs(sites) do
        s.px = (s.x - 0.5) / sampleW * targetW
        s.py = (s.y - 0.5) / sampleH * targetH
        local by = math.max(1, math.min(sampleH, math.floor(s.y)))
        local bx = math.max(1, math.min(sampleW, math.floor(s.x)))
        s.biomeId = biome and biome[by] and biome[by][bx]
        -- Consumers (location population) use the world-space pixel position
        s.x = s.px
        s.y = s.py
    end
    return sites
end

local function traceRoadsForMap(sites, height, biome, valley, sampleW, sampleH, targetW, targetH)
    local connections = computeConnections(sites)
    local roads = {}
    for _, e in ipairs(connections) do
        local a, b = sites[e.a], sites[e.b]
        local pts = traceRoad(a.px, a.py, b.px, b.py, height, biome, valley,
            sampleW, sampleH, targetW, targetH)
        if pts and #pts >= 2 then
            table.insert(roads, { from = a.id, to = b.id, points = pts })
        end
    end
    return roads
end

-- Trace a road network connecting ONLY the given sites (each { id, px, py })
-- across a finished world. Used to rebuild roads over just the road-worthy
-- locations once their types are assigned (location_population_system.lua),
-- since the generator traces roads over every site before types exist.
local function traceRoads(sites, world)
    return traceRoadsForMap(sites, world.height, world.biome, world.valley,
        world.sampleW, world.sampleH, world.targetW, world.targetH)
end

-- Generate sites + roads from a finished generateWorld result.
local function generateSites(world, siteCount)
    local sites = placeSitesForMap(world.height, world.biome,
        world.sampleW, world.sampleH, world.targetW, world.targetH,
        world.seed, siteCount)
    local roads = traceRoadsForMap(sites, world.height, world.biome, world.valley,
        world.sampleW, world.sampleH, world.targetW, world.targetH)
    return { sites = sites, roads = roads }
end

-- Async, step-driven world generation: each call to :advance() runs one named
-- pipeline stage so a splash state can render live progress. After :advance()
-- returns true, :result holds { world, sites, roads }. :runAll() runs the
-- whole pipeline synchronously and returns :result.
local function createGeneration(seed, targetW, targetH, detail, siteCount)
    detail = math.max(1, detail or CONFIG.defaultDetail)
    local longest = math.max(targetW, targetH)
    local scale = clamp(longest / detail, CONFIG.minSample, CONFIG.maxSample) / longest
    local sampleW = math.max(1, math.floor(targetW * scale + 0.5))
    local sampleH = math.max(1, math.floor(targetH * scale + 0.5))
    local u = targetW / sampleW

    local st = {}
    local steps = {
        { name = "Sampling terrain fields", run = function()
            st.height, st.moisture, st.ridge, st.sand, st.patch = generateFields(seed, sampleW, sampleH)
        end },
        { name = "Classifying biomes", run = function()
            st.biome = classifyBiomes(st.height, st.moisture, st.ridge, st.sand, st.patch, sampleW, sampleH)
        end },
        { name = "Tracing rivers", run = function()
            st.rivers = generateRivers(st.height, sampleW, sampleH, seed)
        end },
        { name = "Greening riverbanks", run = function()
            st.lush = buildLushGrid(st.rivers, st.height, sampleW, sampleH)
        end },
        { name = "Carving valleys & drainages", run = function()
            st.valley = buildValleyField(st.height, sampleW, sampleH)
        end },
        { name = "Raising mountain & hill ranges", run = function()
            st.mountainChains = generateRanges(st.ridge, st.height, sampleW, sampleH, seed + 1,
                CONFIG.mountainRanges, {
                    minRidge   = CONFIG.rangeMinRidge,
                    minHeight  = CONFIG.rangeMinHeight,
                    stopHeight = CONFIG.mountainLevel - 0.20,
                    maxHeight  = 1,
                })
            st.hillChains = generateRanges(st.ridge, st.height, sampleW, sampleH, seed + 2,
                CONFIG.hillRanges, {
                    minRidge   = 0.38,
                    minHeight  = CONFIG.hillsLevel - 0.05,
                    stopHeight = CONFIG.hillsLevel - 0.12,
                    maxHeight  = CONFIG.mountainLevel - 0.02,
                })
        end },
        { name = "Drawing terrain", run = function()
            st.base = renderBaseFull(st.height, st.moisture, st.ridge, st.sand,
                st.lush, st.valley, st.patch, targetW, targetH, sampleW, sampleH)
        end },
        { name = "Painting trees & peaks", run = function()
            st.overlay = makeOverlay(targetW, targetH, st.biome,
                st.mountainChains, st.hillChains, st.patch, seed, u)
        end },
        { name = "Placing sites", run = function()
            st.sites = placeSitesForMap(st.height, st.biome,
                sampleW, sampleH, targetW, targetH, seed, siteCount)
        end },
        { name = "Tracing roads", run = function()
            st.roads = traceRoadsForMap(st.sites, st.height, st.biome, st.valley,
                sampleW, sampleH, targetW, targetH)
        end },
    }

    local self = {
        totalSteps = #steps,
        currentIndex = 0,
        currentName = nil,
        done = false,
        result = nil,
    }

    function self.advance()
        if self.done then
            return true
        end
        self.currentIndex = self.currentIndex + 1
        local step = steps[self.currentIndex]
        self.currentName = step.name
        step.run()
        if self.currentIndex >= #steps then
            self.done = true
            self.currentName = nil
            self.result = {
                world = {
                    seed      = seed,
                    targetW   = targetW,
                    targetH   = targetH,
                    sampleW   = sampleW,
                    sampleH   = sampleH,
                    base      = st.base,
                    overlay   = st.overlay,
                    rivers    = st.rivers,
                    mountains = st.mountainChains,
                    hillChains = st.hillChains,
                    biome     = st.biome,
                    height    = st.height,
                    moisture  = st.moisture,
                    ridge     = st.ridge,
                    sand      = st.sand,
                    valley    = st.valley,
                    patch     = st.patch,
                },
                sites = st.sites,
                roads = st.roads,
            }
        end
        return self.done
    end

    function self.progress()
        return self.currentIndex / #steps
    end

    function self.runAll()
        while not self.advance() do end
        return self.result
    end

    return self
end

local function prepareSites()
    local seed = tonumber(getOption("seed", CONFIG.defaultSeed)) or CONFIG.defaultSeed
    local dir = seedDir(seed)

    local ok, meta = pcall(dofile, absPath(dir .. "/meta.lua"))
    if not ok or not meta then
        error("map_generator: no generated world for seed " .. seed
            .. " (run `--generate-map world` first)")
    end

    local targetW, targetH = meta.sizeW, meta.sizeH
    local sampleW, sampleH = meta.sampleW, meta.sampleH
    local height = loadField(dir .. "/height.png", sampleW, sampleH)
    local moisture = loadField(dir .. "/moisture.png", sampleW, sampleH)

    -- File-based stage has no biome grid loaded, so no marsh-lake filtering
    -- happens here (matches previous behaviour).
    local sitesRoads = generateSites({
        seed = seed,
        height = height,
        sampleW = sampleW,
        sampleH = sampleH,
        targetW = targetW,
        targetH = targetH,
    }, CONFIG.siteCount)
    local sites, roads = sitesRoads.sites, sitesRoads.roads

    pending = {
        stage    = "sites",
        seed     = seed,
        dir      = dir,
        targetW  = targetW,
        targetH  = targetH,
        sites    = sites,
        roads    = roads,
        worldPath = dir .. "/world.png",
        out      = getOption("out", dir .. "/map_with_sites.png"),
    }
    log(("[map] sites=%d roads=%d on seed %d world; rendering overlay...")
        :format(#sites, #roads, seed))
end

-- ---------------------------------------------------------------------------
-- GPU rendering (called from love.draw, then the process quits)
-- ---------------------------------------------------------------------------

local function colorVec(name)
    local c = CONFIG.palette[name]
    return c[1] / 255, c[2] / 255, c[3] / 255
end

local function renderWorldAndQuit()
    local p = pending
    local canvas = love.graphics.newCanvas(p.targetW, p.targetH)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()

    -- base terrain (already full resolution)
    local baseImg = love.graphics.newImage(p.base)
    baseImg:setFilter("linear", "linear")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(baseImg, 0, 0)

    -- painted mountains + trees (full resolution)
    local overlayImg = love.graphics.newImage(p.overlay)
    overlayImg:setFilter("linear", "linear")
    love.graphics.draw(overlayImg, 0, 0)

    -- rivers
    if #p.rivers > 0 then
        love.graphics.setColor(colorVec("river"))
        love.graphics.setLineWidth(math.max(1, math.floor(p.targetW * CONFIG.riverWidth)))
        love.graphics.setLineStyle("smooth")
        for _, path in ipairs(p.rivers) do
            local pts = {}
            for _, q in ipairs(path) do
                pts[#pts + 1] = (q.x - 0.5) * (p.targetW / p.sampleW)
                pts[#pts + 1] = (q.y - 0.5) * (p.targetH / p.sampleH)
            end
            if #pts >= 4 then
                love.graphics.line(pts)
            end
        end
    end

    love.graphics.setCanvas()
    local img = canvas:newImageData()
    ensureDir(absPath(p.out))
    img:encode("png", absPath(p.out))
    log("[map] saved " .. p.out)
end

local function renderSitesAndQuit()
    local p = pending
    local worldImg = love.graphics.newImage(absPath(p.worldPath))
    local canvas = love.graphics.newCanvas(p.targetW, p.targetH)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(worldImg, 0, 0)

    -- roads
    if #p.roads > 0 then
        love.graphics.setColor(colorVec("road"))
        love.graphics.setLineWidth(math.max(1, math.floor(p.targetW * CONFIG.roadWidthFrac)))
        love.graphics.setLineStyle("smooth")
        for _, road in ipairs(p.roads) do
            local pts = {}
            for _, q in ipairs(road.points) do
                pts[#pts + 1] = q.x
                pts[#pts + 1] = q.y
            end
            if #pts >= 4 then
                love.graphics.line(pts)
            end
        end
    end

    -- site markers (simple markers now; real sprites are added separately later)
    love.graphics.setColor(colorVec("site"))
    local radius = math.max(3, math.floor(p.targetW * CONFIG.siteRadiusFrac))
    for _, s in ipairs(p.sites) do
        love.graphics.circle("line", s.px, s.py, radius)
        love.graphics.circle("fill", s.px, s.py, math.max(2, radius * 0.4))
    end

    love.graphics.setCanvas()
    local img = canvas:newImageData()
    ensureDir(absPath(p.out))
    img:encode("png", absPath(p.out))

    -- dump sites + roads so location sprites can be placed later
    local lines = {}
    lines[#lines + 1] = "return {"
    lines[#lines + 1] = string.format("  seed = %d,", p.seed)
    lines[#lines + 1] = string.format("  size = { w = %d, h = %d },", p.targetW, p.targetH)
    lines[#lines + 1] = "  sites = {"
    for _, s in ipairs(p.sites) do
        lines[#lines + 1] = string.format("    { id = %q, x = %.1f, y = %.1f },", s.id, s.px, s.py)
    end
    lines[#lines + 1] = "  },"
    lines[#lines + 1] = "  roads = {"
    for _, road in ipairs(p.roads) do
        lines[#lines + 1] = string.format("    { from = %q, to = %q, points = {", road.from, road.to)
        for _, q in ipairs(road.points) do
            lines[#lines + 1] = string.format("      { x = %.1f, y = %.1f },", q.x, q.y)
        end
        lines[#lines + 1] = "    },"
    end
    lines[#lines + 1] = "  },"
    lines[#lines + 1] = "}"
    local dataPath = p.dir .. "/sites_roads.lua"
    writeTextFile(dataPath, table.concat(lines, "\n"))
    log("[map] saved " .. p.out)
    log("[map] saved " .. dataPath)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

local pending = nil

-- Expose defaults plus the reusable in-memory generator, used by the in-game
-- debug world map view.
MapGenerator.defaultSeed      = CONFIG.defaultSeed
MapGenerator.defaultWidth     = CONFIG.defaultWidth
MapGenerator.defaultHeight    = CONFIG.defaultHeight
MapGenerator.defaultDetail    = CONFIG.defaultDetail
MapGenerator.defaultSiteCount = CONFIG.siteCount
MapGenerator.generateWorld    = generateWorld
MapGenerator.generateSites    = generateSites
MapGenerator.createGeneration = createGeneration

MapGenerator.traceRoads       = traceRoads

function MapGenerator.prepare(stage)
    stage = stage or "world"
    if stage == "sites" then
        prepareSites()
    else
        prepareWorld()
    end
end

-- Returns true when it handled the current frame (rendered + requested quit).
function MapGenerator.runFrame()
    if not pending then
        return false
    end
    if pending.stage == "sites" then
        renderSitesAndQuit()
    else
        renderWorldAndQuit()
    end
    pending = nil
    love.event.quit(0)
    return true
end

return MapGenerator
