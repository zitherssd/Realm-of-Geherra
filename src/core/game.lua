-- core/game.lua
-- Main lifecycle coordination
-- Engine-agnostic game manager (no gameplay logic)

local Game = {}

function Game.init()
    -- Initialize core systems only
end

function Game.shutdown()
    -- Cleanup
end

function Game.update(dt)
    -- Lifecycle update
end

return Game
