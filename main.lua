-- Realm of Geherra
-- A Love2D Mount & Blade-style RPG
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end


-- Core Framework
local GameManager = require("core.game")
local StateManager = require("core.state_manager")
local EventBus = require("core.event_bus")
local Input = require("core.input")

-- Initialize
function love.load()
    -- Initialize core systems
    EventBus.init()
    GameManager.init()
    StateManager.init()
    Input.init()
    
    -- Start in menu state
    StateManager.push("menu")
end

function love.update(dt)
    Input.update(dt)
    StateManager.update(dt)
end

function love.draw()
    StateManager.draw()
end

function love.keypressed(key)
    Input.keypressed(key)
    StateManager.keypressed(key)
end

function love.keyreleased(key)
    Input.keyreleased(key)
    StateManager.keyreleased(key)
end

function love.mousepressed(x, y, button)
    Input.mousepressed(x, y, button)
    StateManager.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    Input.mousereleased(x, y, button)
    StateManager.mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    Input.mousemoved(x, y, dx, dy)
end

function love.wheelmoved(x, y)
    Input.wheelmoved(x, y)
    StateManager.wheelmoved(x, y)
end
