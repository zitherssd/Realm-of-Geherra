-- game/states/world_state.lua
-- World exploration state

local Input = require("core.input")
local GameContext = require("game.game_context")
local MovementSystem = require("systems.movement_system")
local FactionSystem = require("systems.faction_system")
local StateManager = require("core.state_manager")
local Camera = require("world.camera")
local TimeSystem = require("systems.time_system")

local WorldState = {
    camera = nil,
    currentMap = nil,
    playerPartySpeed = 200,  -- pixels per second
    nearbyParty = nil,       -- The party currently in interaction range
    nearbyLocation = nil,    -- The location currently in interaction range
    font = nil,
    interactionCooldowns = {}
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
    WorldState.interactionCooldowns = {}
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
    
    -- Update interaction cooldowns
    for id, timer in pairs(WorldState.interactionCooldowns) do
        WorldState.interactionCooldowns[id] = timer - dt
        if WorldState.interactionCooldowns[id] <= 0 then
            WorldState.interactionCooldowns[id] = nil
        end
    end
    
    -- Open Inventory
    if Input.isKeyDown("i") then
        StateManager.push("inventory")
        return
    end
    
    -- Handle player movement and time progression
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
    
    -- Check if player is waiting (Spacebar)
    local isWaiting = Input.isKeyDown("space")
    local isMoving = (moveX ~= 0 or moveY ~= 0)
    
    -- Only advance time if moving or waiting
    if isMoving or isWaiting then
        TimeSystem.setPaused(false)
        TimeSystem.update(dt)
    else
        TimeSystem.setPaused(true)
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
                    -- Check cooldown to prevent immediate re-trigger
                    if not WorldState.interactionCooldowns[otherParty.id] then
                        -- Set cooldown (3 seconds) so player has time to move away after leaving dialogue
                        WorldState.interactionCooldowns[otherParty.id] = 2.0
                        -- Force interaction immediately
                        StateManager.push("dialogue", {dialogueId = "bandit_start", target = otherParty})
                        return -- Stop update to prevent multiple triggers
                    end
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
    
    -- Apply Night Tint
    local r, g, b, a = TimeSystem.getNightTint()
    if a > 0 then
        love.graphics.setColor(r, g, b, a)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end

    -- Draw UI overlay (HUD, info, etc.)
    if WorldState.font then love.graphics.setFont(WorldState.font) end
    
    -- Draw Time HUD
    love.graphics.setColor(1, 1, 1, 1)
    local day = TimeSystem.getDay()
    local period = TimeSystem.getPeriodName()
    local hour = math.floor(TimeSystem.getHour())
    local minute = math.floor((TimeSystem.getHour() - hour) * 60)
    local timeStr = string.format("Day %d | %s | %02d:%02d", day, period, hour, minute)
    local textWidth = WorldState.font:getWidth(timeStr)
    love.graphics.print(timeStr, love.graphics.getWidth() - textWidth - 20, 20)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("World View - WASD to move, [I] Inventory", 10, 10)

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
