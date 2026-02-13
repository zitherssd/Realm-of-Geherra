-- game/states/world_state.lua
-- World exploration state

local Input = require("core.input")
local GameContext = require("game.game_context")
local MovementSystem = require("systems.movement_system")
local FactionSystem = require("systems.faction_system")
local StateManager = require("core.state_manager")
local Camera = require("world.camera")

local WorldState = {
    camera = nil,
    currentMap = nil,
    playerPartySpeed = 200,  -- pixels per second
    nearbyParty = nil,       -- The party currently in interaction range
    nearbyLocation = nil,    -- The location currently in interaction range
    font = nil
}

function WorldState.enter()
    -- Get the current map from game context (should be initialized by GameInitializer)
    WorldState.currentMap = GameContext.data.currentMap
    
    if not WorldState.currentMap then
        error("World state entered without initialized map. Call GameInitializer.initNewGame() first.")
    end
    
    -- Initialize camera
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    WorldState.camera = Camera.new(screenWidth, screenHeight)
    
    -- Set camera bounds based on map size
    WorldState.camera:setBounds(0, 0, WorldState.currentMap.width, WorldState.currentMap.height)
    
    -- Initialize camera position to follow player party
    local playerParty = GameContext.data.playerParty
    if playerParty then
        WorldState.camera.x = playerParty.x
        WorldState.camera.y = playerParty.y
        WorldState.nearbyLocation = nil
        WorldState.nearbyParty = nil
    end
    
    -- Initialize UI font
    WorldState.font = love.graphics.newFont(14)
end

function WorldState.exit()
    -- Cleanup world state
    WorldState.camera = nil
    WorldState.currentMap = nil
    WorldState.nearbyLocation = nil
    WorldState.nearbyParty = nil
end

function WorldState.update(dt)
    local playerParty = GameContext.data.playerParty
    if not playerParty or not WorldState.currentMap then return end
    
    -- Handle player movement input
    local moveX, moveY = 0, 0
    
    if Input.isKeyDown("up") or Input.isKeyDown("w") then
        moveY = moveY - 1
    end
    if Input.isKeyDown("down") or Input.isKeyDown("s") then
        moveY = moveY + 1
    end
    if Input.isKeyDown("left") or Input.isKeyDown("a") then
        moveX = moveX - 1
    end
    if Input.isKeyDown("right") or Input.isKeyDown("d") then
        moveX = moveX + 1
    end
    
    -- Normalize diagonal movement
    local magnitude = math.sqrt(moveX * moveX + moveY * moveY)
    if magnitude > 0 then
        moveX = moveX / magnitude
        moveY = moveY / magnitude
    end
    
    -- Update party position based on input
    local currentX, currentY = playerParty:getPosition()
    local newX = currentX + moveX * WorldState.playerPartySpeed * dt
    local newY = currentY + moveY * WorldState.playerPartySpeed * dt
    
    -- Clamp party position to map bounds
    newX = math.max(0, math.min(newX, WorldState.currentMap.width))
    newY = math.max(0, math.min(newY, WorldState.currentMap.height))
    
    playerParty:setPosition(newX, newY)
    
    -- Update camera to follow party
    WorldState.camera:update(dt, playerParty)

    local interactionRadius = 30

    -- Check for locations
    WorldState.nearbyLocation = nil
    for _, location in ipairs(WorldState.currentMap.locations) do
        local dx = location.x - playerParty.x
        local dy = location.y - playerParty.y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist < interactionRadius then
            WorldState.nearbyLocation = location
            if Input.isKeyDown("return") or Input.isKeyDown("kpenter") then
                StateManager.push("location", { location = location })
                return -- Stop update
            end
        end
    end

    -- Check for collisions/interactions with other parties
    WorldState.nearbyParty = nil

    for _, otherParty in ipairs(WorldState.currentMap.parties) do
        if otherParty.id ~= playerParty.id then
            local dx = otherParty.x - playerParty.x
            local dy = otherParty.y - playerParty.y
            local dist = math.sqrt(dx*dx + dy*dy)

            if dist < interactionRadius then
                WorldState.nearbyParty = otherParty
                
                -- Check faction hostility
                -- For now, we assume "bandits" faction is always hostile
                -- In the future, use FactionSystem.getFactionStanding(player, otherParty.faction)
                local isHostile = (otherParty.faction == "bandits")

                if isHostile then
                    -- Force interaction immediately
                    StateManager.push("dialogue", {dialogueId = "bandit_start", target = otherParty})
                    return -- Stop update to prevent multiple triggers
                elseif Input.isKeyDown("return") or Input.isKeyDown("kpenter") then
                    -- Player initiated interaction
                    StateManager.push("dialogue", {dialogueId = "elder_greeting", target = otherParty}) -- Default to elder for now
                end
            end
        end
    end
end

function WorldState.draw()
    if not WorldState.currentMap or not WorldState.camera then
        love.graphics.clear(0.2, 0.3, 0.2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("World State - Loading...", 10, 10)
        return
    end
    
    -- Clear background
    love.graphics.clear(0.2, 0.3, 0.2)
    
    -- Apply camera transformation
    WorldState.camera:apply()
    
    -- Draw map
    WorldState.currentMap:drawMap()
    
    -- Draw locations
    WorldState.currentMap:drawLocations()
    
    -- Draw parties
    WorldState.currentMap:drawParties()
    
    -- Unapply camera transformation
    WorldState.camera:unapply()
    
    -- Draw UI overlay (HUD, info, etc.)
    if WorldState.font then love.graphics.setFont(WorldState.font) end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("World View - WASD to move", 10, 10)

    -- Draw location interaction hint
    if WorldState.nearbyLocation then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.printf("Press ENTER to enter " .. WorldState.nearbyLocation.name, 
            0, love.graphics.getHeight() - 130, love.graphics.getWidth(), "center")
    end

    -- Draw interaction hint
    if WorldState.nearbyParty and WorldState.nearbyParty.faction ~= "bandits" then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.printf("Press ENTER to talk to " .. (WorldState.nearbyParty.name or "Party"), 
            0, love.graphics.getHeight() - 100, love.graphics.getWidth(), "center")
    end
    
    local playerParty = GameContext.data.playerParty
    if playerParty then
        love.graphics.printf(
            string.format("Party: %.0f, %.0f (%d members)", playerParty.x, playerParty.y, playerParty:getActorCount()),
            10, 30, love.graphics.getWidth() - 20, "left"
        )
    end
end

return WorldState
