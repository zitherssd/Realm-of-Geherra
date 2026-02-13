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
end

function StateManager.swap(stateName, ...)
    StateManager.pop()
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

return StateManager
