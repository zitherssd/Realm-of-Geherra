-- core/state_manager.lua
-- Push/pop/swap game states

local StateManager = {}

local stateStack = {}
local states = {}

function StateManager.init()
    -- Register available states
    states.menu = require("game.states.menu_state")
    states.world = require("game.states.world_state")
    states.battle = require("game.states.battle_state")
    states.dialogue = require("game.states.dialogue_state")
    states.pause = require("game.states.pause_state")
    states.battle_end = require("game.states.battle_end_state")
    states.location = require("game.states.location_state")
    states.inventory = require("game.states.inventory_state")
    states.quest_log = require("game.states.quest_log_state")

    -- Initialize systems that subscribe to events
    require("systems.quest_system").init()
end

function StateManager.push(stateName, ...)
    if not states[stateName] then
        error("State " .. stateName .. " not found")
    end
    
    local state = states[stateName]
    if state.enter then
        state.enter(...)
    end
    
    table.insert(stateStack, {name = stateName, state = state})
end

function StateManager.pop()
    if #stateStack == 0 then return end
    
    local current = stateStack[#stateStack]
    if current.state.exit then
        current.state.exit()
    end
    
    table.remove(stateStack)

    -- Resume the previous state if it exists
    if #stateStack > 0 then
        local previous = stateStack[#stateStack]
        if previous.state.resume then
            previous.state.resume()
        end
    end
end

function StateManager.swap(stateName, ...)
    -- Manually remove current state without triggering resume on the previous state
    if #stateStack > 0 then
        local current = stateStack[#stateStack]
        if current.state.exit then
            current.state.exit()
        end
        table.remove(stateStack)
    end
    StateManager.push(stateName, ...)
end

function StateManager.update(dt)
    if #stateStack > 0 then
        local current = stateStack[#stateStack]
        if current.state.update then
            current.state.update(dt)
        end
    end
end

function StateManager.draw()
    if #stateStack > 0 then
        local current = stateStack[#stateStack]
        if current.state.draw then
            current.state.draw()
        end
    end
end

function StateManager.getCurrentState()
    if #stateStack > 0 then
        return stateStack[#stateStack].state
    end
    return nil
end

function StateManager.keypressed(key)
    if #stateStack > 0 then
        local current = stateStack[#stateStack]
        if current.state.keypressed then
            current.state.keypressed(key)
        end
    end
end

function StateManager.keyreleased(key)
    if #stateStack > 0 then
        local current = stateStack[#stateStack]
        if current.state.keyreleased then
            current.state.keyreleased(key)
        end
    end
end

function StateManager.mousepressed(x, y, button)
    if #stateStack > 0 then
        local current = stateStack[#stateStack]
        if current.state.mousepressed then
            current.state.mousepressed(x, y, button)
        end
    end
end

function StateManager.mousereleased(x, y, button)
    if #stateStack > 0 then
        local current = stateStack[#stateStack]
        if current.state.mousereleased then
            current.state.mousereleased(x, y, button)
        end
    end
end

function StateManager.wheelmoved(x, y)
    if #stateStack > 0 then
        local current = stateStack[#stateStack]
        if current.state.wheelmoved then
            current.state.wheelmoved(x, y)
        end
    end
end

return StateManager
