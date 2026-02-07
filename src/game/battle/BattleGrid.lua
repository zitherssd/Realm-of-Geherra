local BattleGrid = {
    GRID_SIZE = 42,
    GRID_WIDTH = 30,
    GRID_HEIGHT = 13,
    cells = {},
}

function BattleGrid:initializeGrid()
    self.cells = {}
    for x = 1, self.GRID_WIDTH do
        self.cells[x] = {}
        for y = 1, self.GRID_HEIGHT do
            self.cells[x][y] = {
                x = x,
                y = y,
                units = {},
                total_size = 0,
                max_size = 10
            }
        end
    end
end

function BattleGrid:getUnitsInCellByCoordinates(x, y)
    if not self:isValidPosition(x, y) then return {} end
    return self.cells[x][y].units
end

function BattleGrid:getUnitsInCell(cell)
    return cell.units
end

function BattleGrid:getCellPartyNumber(cell)
    if cell.units and #cell.units > 0 then
        return cell.units[1].battle_party
    end
    return nil
end

function BattleGrid:getCellAtPixel(pixelX, pixelY)
    local gridX = math.floor(pixelX / self.GRID_SIZE) + 1
    local gridY = math.floor(pixelY / self.GRID_SIZE) + 1
    
    if self:isValidPosition(gridX, gridY) then
        return gridX, gridY
    end
    return nil
end

function BattleGrid:getCellCenterPixel(cell)
    local pixelX = (cell.x - 0.5) * self.GRID_SIZE
    local pixelY = (cell.y - 0.5) * self.GRID_SIZE
    return pixelX, pixelY
end

function BattleGrid:draw()
    -- Draw grid lines
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    for x = 0, self.GRID_WIDTH do
        love.graphics.line(x * self.GRID_SIZE, 0, x * self.GRID_SIZE, self.GRID_HEIGHT * self.GRID_SIZE)
    end
    for y = 0, self.GRID_HEIGHT do
        love.graphics.line(0, y * self.GRID_SIZE, self.GRID_WIDTH * self.GRID_SIZE, y * self.GRID_SIZE)
    end
end

function BattleGrid:isValidPosition(x, y)
    return x >= 1 and x <= self.GRID_WIDTH and 
           y >= 1 and y <= self.GRID_HEIGHT
end

function BattleGrid:removeUnitFromCell(unit,cell)
    for i, u in ipairs(cell.units) do
        if u == unit then
            table.remove(cell.units, i)
            cell.total_size = cell.total_size - unit.size
            unit.currentCell = nil
            return true
        end
    end
    return false
end

function BattleGrid:addUnitToCell(unit, cell)
    table.insert(cell.units, unit)
    cell.total_size = cell.total_size + unit.size
    unit.currentCell = cell
end

function BattleGrid:getDistance(cellA, cellB)
    if not cellA or not cellB then return math.huge end
    return math.max(math.abs(cellA.x - cellB.x), math.abs(cellA.y - cellB.y))
end

return BattleGrid