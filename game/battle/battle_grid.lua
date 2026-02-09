-- game/battle/battle_grid.lua
-- Data structure for the battle map
-- Handles coordinates, terrain, and occupancy

local BattleGrid = {}
BattleGrid.__index = BattleGrid

function BattleGrid.new(width, height, cellSize)
    width = width or 30
    height = height or 13
    cellSize = cellSize or 42

    local self = {
        width = width,
        height = height,
        cellSize = cellSize,
        cells = {},      -- Static terrain data (e.g., isWall)
        occupants = {}   -- Dynamic unit lookup [x][y] = unitId
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
            self.occupants[x][y] = nil
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

-- Check if a cell is free (walkable + no unit)
function BattleGrid:isFree(x, y)
    return self:isWalkable(x, y) and self.occupants[x][y] == nil
end

-- Get the unit ID at a specific location
function BattleGrid:getOccupant(x, y)
    if not self:inBounds(x, y) then return nil end
    return self.occupants[x][y]
end

-- Set the unit ID at a specific location
function BattleGrid:setOccupant(x, y, unitId)
    if not self:inBounds(x, y) then return end
    self.occupants[x][y] = unitId
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