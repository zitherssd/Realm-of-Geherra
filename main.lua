-- Realm of Geherra
-- A Love2D Mount & Blade-style RPG
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end


-- Core Framework
local GameManager = require("src.core.game")
local StateManager = require("src.core.state_manager")
local EventBus = require("src.core.event_bus")
local Input = require("src.core.input")
local DebugMode = require("src.debug.mode")
local debugFont

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
    if DebugMode.enabled then
        love.graphics.push("all")
        debugFont = debugFont or love.graphics.newFont(12)
        love.graphics.setFont(debugFont)
        love.graphics.setColor(0.08, 0.07, 0.06, 0.92)
        love.graphics.rectangle("fill", 8, love.graphics.getHeight() - 58, 320, 24)
        love.graphics.setColor(1, 0.75, 0.25, 1)
        love.graphics.print("DEBUG [F1] - Right-click parties / locations", 14, love.graphics.getHeight() - 54)
        love.graphics.pop()
    end
end

function love.keypressed(key, scancode, isRepeat)
    if StateManager.keypressed(key, isRepeat) then return end
    Input.keypressed(key)
end

function love.textinput(text)
    StateManager.textinput(text)
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
