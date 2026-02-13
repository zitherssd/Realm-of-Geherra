-- game/states/location_state.lua
-- State for being inside a location (town, castle, etc.)

local LocationState = {}

local StateManager = require("core.state_manager")
local UIManager = require("ui.ui_manager")
local LocationScreen = require("ui.screens.location_screen")

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
    local screen = LocationScreen.new(LocationState.location, function()
        -- On Leave callback
        StateManager.pop()
    end)
    
    UIManager.registerScreen("location", screen)
    UIManager.showScreen("location")
end

function LocationState.exit()
    UIManager.hideScreen()
    LocationState.location = nil
end

function LocationState.update(dt)
    UIManager.update(dt)
end

function LocationState.draw()
    UIManager.draw()
end

function LocationState.mousepressed(x, y, button)
    UIManager.mousepressed(x, y, button)
end

return LocationState