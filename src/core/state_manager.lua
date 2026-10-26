-- core/state_manager.lua
-- Push/pop/swap game states

local StateManager = {}
local DebugMode = require("src.debug.mode")

local stateStack = {}
local states = {}

function StateManager.init()
    -- Register available states
    states.menu = require("src.game.states.menu_state")
    states.world = require("src.game.states.world_state")
    states.battle = require("src.game.states.battle_state")
    states.dialogue = require("src.game.states.dialogue_state")
    states.pause = require("src.game.states.pause_state")
    states.battle_end = require("src.game.states.battle_end_state")
    states.location = require("src.game.states.location_state")
    states.inventory = require("src.game.states.inventory_state")
    states.quest_log = require("src.game.states.quest_log_state")
    states.shop = require("src.game.states.shop_state")
    states.world_map = require("src.game.states.world_map_state")
    states.world_generation = require("src.game.states.world_generation_state")

    -- Initialize systems that subscribe to events
    require("src.systems.quest_system").init()
    require("src.systems.encounter_system").init()
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

function StateManager.keypressed(key, isRepeat)
    if key == "f1" then
        if not isRepeat then
            DebugMode.toggle()
            while not DebugMode.enabled and #stateStack > 0 and stateStack[#stateStack].state.debugOnly do
                StateManager.pop()
            end
            local current = StateManager.getCurrentState()
            if current and current.debugModeChanged then current.debugModeChanged() end
        end
        return true
    end
    if #stateStack > 0 then
        local current = stateStack[#stateStack]
        if current.state.keypressed then
            return current.state.keypressed(key)
        end
    end
end

function StateManager.textinput(text)
    local current = StateManager.getCurrentState()
    if current and current.textinput then current.textinput(text) end
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
