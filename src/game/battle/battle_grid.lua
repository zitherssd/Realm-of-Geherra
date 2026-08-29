-- game/battle/battle_grid.lua
-- Data structure for the battle map
-- Handles coordinates, terrain, and occupancy

local BattleGrid = {}
BattleGrid.__index = BattleGrid

local CELL_CAPACITY = 10

function BattleGrid.new(width, height, cellSize)
    width = width or 30
    height = height or 13
    cellSize = cellSize or 42

    local self = {
        width = width,
        height = height,
        cellSize = cellSize,
        cells = {},      -- Static terrain data (e.g., isWall)
        occupants = {}   -- Dynamic unit lookup [x][y] = {unitId1, unitId2, ...}
    }
    
    -- Initialize grid
    for x = 1, width do
        self.cells[x] = {}
        self.occupants[x] = {}
        for y = 1, height do
            self.cells[x][y] = {
                walkable = true,
                cost = 1
            }
            self.occupants[x][y] = {}
        end
    end
    
    setmetatable(self, BattleGrid)
    return self
end

-- Check if coordinates are within map bounds
function BattleGrid:inBounds(x, y)
    return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

-- Check if a cell is walkable (terrain only)
function BattleGrid:isWalkable(x, y)
    if not self:inBounds(x, y) then return false end
    return self.cells[x][y].walkable
end

function BattleGrid:getOccupants(x, y)
    if not self:inBounds(x, y) then return {} end
    return self.occupants[x][y]
end

function BattleGrid:addUnit(x, y, unitId)
    if not self:inBounds(x, y) then return end
    table.insert(self.occupants[x][y], unitId)
end

function BattleGrid:removeUnit(x, y, unitId)
    if not self:inBounds(x, y) then return end
    for i, occupantId in ipairs(self.occupants[x][y]) do
        if occupantId == unitId then
            table.remove(self.occupants[x][y], i)
            return
        end
    end
end

function BattleGrid:getCellTotalSize(x, y, battleContext)
    if not self:inBounds(x, y) then return 0 end
    
    local totalSize = 0
    for _, unitId in ipairs(self.occupants[x][y]) do
        local unit = battleContext.data.units[unitId]
        if unit then
            totalSize = totalSize + (unit.size or 3) -- Default to 3 if size is missing
        end
    end
    return totalSize
end

-- Check if a cell has enough capacity for a given unit
function BattleGrid:hasCapacity(x, y, unit, battleContext)
    if not self:isWalkable(x, y) then
        return false
    end

    local occupants = self:getOccupants(x, y)
    if #occupants > 0 then
        local firstOccupant = battleContext.data.units[occupants[1]]
        if firstOccupant and firstOccupant.team ~= unit.team then
            return false -- Cannot stack with enemies
        end
    end
    
    local currentSize = self:getCellTotalSize(x, y, battleContext)
    local unitSize = unit.size or 3 -- Default to 3 if size is missing
    
    return currentSize + unitSize <= CELL_CAPACITY
end

-- Get valid 4-directional neighbors for pathfinding
function BattleGrid:getNeighbors(x, y)
    local neighbors = {}
    local directions = {
        {x = 0, y = -1}, -- Up
        {x = 0, y = 1},  -- Down
        {x = -1, y = 0}, -- Left
        {x = 1, y = 0}   -- Right
    }
    
    for _, dir in ipairs(directions) do
        local nx, ny = x + dir.x, y + dir.y
        if self:inBounds(nx, ny) then
            table.insert(neighbors, {x = nx, y = ny})
        end
    end
    
    return neighbors
end

-- Convert Grid coordinates to World (Pixel) coordinates
-- Returns center of the tile
function BattleGrid:gridToWorld(gx, gy)
    return (gx - 1) * self.cellSize + (self.cellSize / 2),
           (gy - 1) * self.cellSize + (self.cellSize / 2)
end

-- Convert World (Pixel) coordinates to Grid coordinates
function BattleGrid:worldToGrid(wx, wy)
    return math.floor(wx / self.cellSize) + 1,
           math.floor(wy / self.cellSize) + 1
end

return BattleGrid