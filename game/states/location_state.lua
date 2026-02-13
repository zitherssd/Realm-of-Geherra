-- game/states/location_state.lua
-- State for being inside a location (town, castle, etc.)

local LocationState = {}

local StateManager = require("core.state_manager")
local LocationScreen = require("ui.screens.location_screen")

LocationState.screen = nil
LocationState.location = nil

function LocationState.enter(params)
    params = params or {}
    LocationState.location = params.location
    
    if not LocationState.location then
        print("Error: LocationState entered without a location.")
        StateManager.pop()
        return
    end
    
    -- Initialize the UI Screen
    LocationState.screen = LocationScreen.new(LocationState.location, function()
        -- On Leave callback
        StateManager.pop()
    end)
end

function LocationState.exit()
    LocationState.screen = nil
    LocationState.location = nil
end

function LocationState.update(dt)
    if LocationState.screen then
        LocationState.screen:update(dt)
    end
end

function LocationState.draw()
    if LocationState.screen then
        LocationState.screen:draw()
    end
end

return LocationState