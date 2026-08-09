-- verify_roads.lua — headless check for type-limited roads.
-- Run with: love verify_roads.lua  (love.exe is a GUI app; results are written
-- to verify_roads_result.txt, not stdout).
local RESULTS = "C:\\Users\\phil\\Documents\\Repos\\Geherra-Realms\\verify_roads_result.txt"

local function writeFile(path, text)
    local f = io.open(path, "w")
    f:write(text)
    f:close()
end

-- Fail loudly if any require fails at boot (love's error screen is invisible
-- here), and confirm file I/O works before anything else runs.
writeFile(RESULTS, "pre-require\n")
local okP, PaintedMapLoader = pcall(require, "systems.painted_map_loader")
local okL, LocationPopulationSystem
if okP then
    okL, LocationPopulationSystem = pcall(require, "systems.location_population_system")
end
if not (okP and okL) then
    writeFile(RESULTS, "REQUIRE ERROR: " .. tostring(okP and LocationPopulationSystem or PaintedMapLoader) .. "\n")
    love.event.quit(1)
    return
end

-- Small config: same code path as the default game map, but fast to generate.
local TEST_OPTIONS = { sizeW = 1200, sizeH = 700, detail = 2, siteCount = 14 }

local function runOnce(options)
    local map = PaintedMapLoader.generate(options)
    local locations = LocationPopulationSystem.populate(map, map.worldGen)
    local typeById = {}
    for _, loc in ipairs(locations) do
        typeById[loc.siteId] = loc.type
    end
    return map, locations, typeById
end

local function roadKey(road)
    local a, b = road.from, road.to
    if a > b then a, b = b, a end
    return a .. "|" .. b
end

local ROAD = { village = true, town = true, castle = true }

local function verify(map, locations, typeById, out)
    local roads = map.worldGen.roads or {}
    local bad = {}
    local incident = {}
    local nonRoadWithRoad = {}
    for _, r in ipairs(roads) do
        local ta, tb = typeById[r.from], typeById[r.to]
        if not ROAD[ta] or not ROAD[tb] then
            bad[#bad + 1] = string.format("%s(%s)-%s(%s)", r.from, ta, r.to, tb)
        end
        if not ROAD[ta] then nonRoadWithRoad[r.from] = true end
        if not ROAD[tb] then nonRoadWithRoad[r.to] = true end
        incident[r.from] = true
        incident[r.to] = true
    end
    local isolated = {}
    local nonRoad = {}
    for _, loc in ipairs(locations) do
        if ROAD[loc.type] and not incident[loc.siteId] then
            isolated[#isolated + 1] = string.format("%s(%s)", loc.siteId, loc.type)
        end
        if not ROAD[loc.type] and nonRoadWithRoad[loc.siteId] then
            nonRoad[#nonRoad + 1] = string.format("%s(%s)", loc.siteId, loc.type)
        end
    end
    local countByType = {}
    for _, loc in ipairs(locations) do
        countByType[loc.type] = (countByType[loc.type] or 0) + 1
    end
    local parts = {}
    for t, c in pairs(countByType) do
        parts[#parts + 1] = t .. "=" .. c
    end
    table.sort(parts)
    out[#out + 1] = string.format("sites=%d roads=%d  byType: %s", #locations, #roads, table.concat(parts, ", "))
    out[#out + 1] = "badEndpoints(" .. #bad .. "): " .. table.concat(bad, " ")
    out[#out + 1] = "isolatedRoadWorthy(" .. #isolated .. "): " .. table.concat(isolated, " ")
    out[#out + 1] = "nonRoadWithRoad(" .. #nonRoad .. "): " .. table.concat(nonRoad, " ")
    return #bad, #isolated, #nonRoad
end

function love.load()
    writeFile(RESULTS, "started...\n")
    local out = {}
    local ok, err = pcall(function()
        local m1, loc1, t1 = runOnce(TEST_OPTIONS)
        out[#out + 1] = "== run 1 (small config) =="
        local b1, i1, n1 = verify(m1, loc1, t1, out)

        local m2, loc2, t2 = runOnce(TEST_OPTIONS)
        out[#out + 1] = "== run 2 (small config, determinism) =="
        local b2, i2, n2 = verify(m2, loc2, t2, out)

        local keys1, keys2 = {}, {}
        for _, r in ipairs(m1.worldGen.roads or {}) do keys1[roadKey(r)] = true end
        for _, r in ipairs(m2.worldGen.roads or {}) do keys2[roadKey(r)] = true end
        local same = #m1.worldGen.roads == #m2.worldGen.roads
        for k in pairs(keys1) do if not keys2[k] then same = false break end end
        for k in pairs(keys2) do if not keys1[k] then same = false break end end
        out[#out + 1] = "deterministic=" .. tostring(same)
        out[#out + 1] = "RESULT=" .. (same and b1 == 0 and i1 == 0 and n1 == 0 and b2 == 0 and i2 == 0 and n2 == 0 and "PASS" or "FAIL")
    end)
    if not ok then
        out[#out + 1] = "ERROR: " .. tostring(err)
        out[#out + 1] = "RESULT=FAIL"
    end
    writeFile(RESULTS, table.concat(out, "\n"))
    love.event.quit(0)
end
