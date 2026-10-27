-- A fixed test board for playable debug campaigns. No behavior is simulated here.
local Map = require("src.world.map")
local Config = require("src.data.world_generation")
local DebugMap = {districtSize = 512, cellSize = 16, districtsPerSide = 3}

local districts = {
    {biome = "plains", color = {0.49, 0.62, 0.35}, type = "village"},
    {biome = "forest", color = {0.23, 0.43, 0.30}, type = "town"},
    {biome = "desert", color = {0.78, 0.65, 0.39}, type = "fort", name = "Minotaur Fort",
        culture = "minotaur", faction = "minotaur_clan", populationProfile = "chieftain_court"},
    {biome = "hills", color = {0.57, 0.53, 0.36}, type = "village"},
    {biome = "marsh", color = {0.31, 0.48, 0.46}, type = "town"},
    {biome = "mountain", color = {0.50, 0.49, 0.56}, type = "fort", name = "Pelasgian Fort",
        culture = "pelasgian", faction = "pelasgian_clan"},
    {biome = "desert", color = {0.78, 0.65, 0.39}, type = "village"},
    {biome = "plains", color = {0.49, 0.62, 0.35}, type = "town"},
    {biome = "forest", color = {0.23, 0.43, 0.30}, type = "castle"},
}

function DebugMap.generate()
    local size, side, cell = DebugMap.districtSize, DebugMap.districtsPerSide, DebugMap.cellSize
    local map = Map.new("debug_campaign_grid", "Debug Campaign — Biome Grid")
    map.width, map.height = size * side, size * side
    map:setBounds(0, 0, map.width, map.height)
    local data = {seed = 73421, debugLayout = true, sites = {}, roads = {}, biomeById = {},
        navigationGrid = {cellSize = cell, cols = map.width / cell, rows = map.height / cell, cells = {}}}
    for _, biome in ipairs(Config.biomes) do data.biomeById[biome.id] = biome end
    for row = 1, side do
        for col = 1, side do
            local district = districts[(row - 1) * side + col]
            local label = string.char(64 + row) .. col
            local title = district.biome:gsub("^%l", string.upper)
            data.sites[#data.sites + 1] = {id = "debug_site_" .. label,
                x = (col - 0.5) * size + cell / 2, y = (row - 0.5) * size + cell / 2,
                biomeId = district.biome, locationType = district.type,
                culture = district.culture, faction = district.faction,
                populationProfile = district.populationProfile,
                name = label .. " " .. (district.name or (title .. " " .. (district.type == "village" and "Village"
                    or district.type == "town" and "Town" or "Keep")))}
        end
    end
    local function road(a, b)
        data.roads[#data.roads + 1] = {from = a.id, to = b.id,
            points = {{x = a.x, y = a.y}, {x = b.x, y = b.y}}}
    end
    for index, site in ipairs(data.sites) do
        if index % side ~= 0 then road(site, data.sites[index + 1]) end
        if index <= side * (side - 1) then road(site, data.sites[index + side]) end
    end
    for y = 1, data.navigationGrid.rows do
        local cells = {}
        data.navigationGrid.cells[y] = cells
        for x = 1, data.navigationGrid.cols do
            local col, row = math.floor((x - 1) * cell / size), math.floor((y - 1) * cell / size)
            cells[x] = {x = x, y = y, worldX = (x - 0.5) * cell, worldY = (y - 0.5) * cell,
                walkable = true, biomeId = districts[row * side + col + 1].biome}
        end
    end
    map:setWorldGenerationData(data)
    -- A plain background uses the same map image rendering path as the painted world.
    local canvas = love.graphics.newCanvas(map.width, map.height)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setFont(love.graphics.newFont(28))
    love.graphics.setLineWidth(4)
    for index, district in ipairs(districts) do
        local x, y = ((index - 1) % side) * size, math.floor((index - 1) / side) * size
        love.graphics.setColor(district.color)
        love.graphics.rectangle("fill", x, y, size, size)
        love.graphics.setColor(0.12, 0.15, 0.12, 1)
        love.graphics.rectangle("line", x + 2, y + 2, size - 4, size - 4)
        love.graphics.print(data.sites[index].name, x + 24, y + 24)
    end
    love.graphics.pop()
    map.visuals.image = canvas
    map.renderOptions.showWater, map.renderOptions.showBiomeOverlay = false, false
    return map
end

-- Same small splash contract as PaintedMapLoader, with one inexpensive stage.
function DebugMap.createGeneration()
    local gen = {totalSteps = 1, currentIndex = 0, currentName = "Building debug biome grid"}
    function gen:advance()
        if not self.result then
            self.result = DebugMap.generate()
            self.currentIndex = 1
        end
        return true
    end
    function gen:progress() return self.currentIndex end
    function gen:runAll() self:advance() end
    return gen
end

function DebugMap.buildMap(result) return result end

return DebugMap
