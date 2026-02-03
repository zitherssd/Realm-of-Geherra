local grid = require("src.game.battle.BattleGrid")

local BattleCamera = {
    x = 0,
    y = 0,
    scale = 1,
    lerp = 1
}

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

function BattleCamera:update(dt, playerUnit)
    if not playerUnit then return end
    local targetX = playerUnit.battle_x
    local targetY = playerUnit.battle_y

    -- Smooth follow
    local t = clamp(dt * self.lerp, 0, 1)
    self.x = self.x + (targetX - self.x) * t
    self.y = self.y + (targetY - self.y) * t

    -- Clamp to battlefield bounds taking zoom into account
    local screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()
    local halfW = (screen_w / 2) / self.scale
    local halfH = (screen_h / 2) / self.scale
    local worldW = grid.GRID_WIDTH * grid.GRID_SIZE
    local worldH = grid.GRID_HEIGHT * grid.GRID_SIZE

    self.x = clamp(self.x, halfW, worldW - halfW)
    self.y = clamp(self.y, halfH, worldH - halfH)
end

function BattleCamera:apply()
    local screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.push()
    -- Scale around screen center, then translate world so camera.x/y land at center
    love.graphics.translate(screen_w / 2, screen_h / 2)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.translate(-self.x, -self.y)
end

function BattleCamera:unapply()
    love.graphics.pop()
end

return BattleCamera

