-- game/states/world_state.lua
-- World exploration state

local Input = require("core.input")
local GameContext = require("game.game_context")
local MovementSystem = require("systems.movement_system")
local FactionSystem = require("systems.faction_system")
local StateManager = require("core.state_manager")
local Camera = require("world.camera")
local TimeSystem = require("systems.time_system")
local AttributeSystem = require("systems.attribute_system")
local EncounterSystem = require("systems.encounter_system")

local WorldState = {
    camera = nil,
    currentMap = nil,
    defaultZoom = 2.0,       -- world map shown 2x (zoomed in, slightly pixelated)
    playerPartySpeed = 80,  -- pixels per second (halved to stay consistent at 2x zoom)
    -- Travel speed multiplier per biome on the world map.
    -- Biomes not listed here are travelled at full speed (1.0).
    biomeSpeedModifiers = {
        desert   = 0.6,
        mountain = 0.4,
        hills    = 0.7,
        forest   = 0.75,
        marsh    = 0.4,
        cliff = 0.65,
    },
    -- Distance (world px) within which the party counts as travelling "on a
    -- road". Roads halve the biome movement penalty (see onRoad below).
    roadOnDistance = 12,
    passiveHealSecondsToFull = 300,
    restHealMultiplier = 10,
    nearbyParty = nil,       -- The party currently in interaction range
    nearbyLocation = nil,    -- The location currently in interaction range
    font = nil,
    interactionCooldowns = {},
    isResting = false,
    restInputLock = 0,
    restModeRequested = false,
    restStartTotalHour = nil,  -- total game-hours when rest began
    popup = nil                -- transient floating notification (e.g. battle favor reward)
}

local function healPartyOverTime(dt, multiplier)
    local playerParty = GameContext.data.playerParty
    if not playerParty then return end

    local secondsToFull = math.max(1, WorldState.passiveHealSecondsToFull)
    local appliedMultiplier = math.max(0, multiplier or 1)

    for _, actor in ipairs(playerParty:getActors() or {}) do
        if actor and actor.stats and actor.stats.health then
            local maxHp = actor.maxHp or actor.stats.health
            local currentHp = actor.hp or maxHp
            local healPerSecond = (maxHp / secondsToFull) * appliedMultiplier
            actor.hp = math.min(maxHp, currentHp + healPerSecond * dt)
        end
    end
end

-- True when (x, y) is within WorldState.roadOnDistance of any road polyline
-- on the map (roads live in map.worldGen.roads as { points = {{x,y},...} }).
-- Uses squared distances so it's cheap enough to call every frame.
local function onRoad(map, x, y)
    local roads = map and map.worldGen and map.worldGen.roads
    if not roads then
        return false
    end
    local maxD2 = WorldState.roadOnDistance * WorldState.roadOnDistance
    for _, road in ipairs(roads) do
        local pts = road.points
        for i = 1, #pts - 1 do
            local a, b = pts[i], pts[i + 1]
            local dx, dy = b.x - a.x, b.y - a.y
            local len2 = dx * dx + dy * dy
            local t = 0
            if len2 > 0 then
                t = ((x - a.x) * dx + (y - a.y) * dy) / len2
                if t < 0 then t = 0 elseif t > 1 then t = 1 end
            end
            local cx, cy = a.x + dx * t, a.y + dy * t
            local qx, qy = x - cx, y - cy
            if qx * qx + qy * qy <= maxD2 then
                return true
            end
        end
    end
    return false
end

-- Roads halve the biome travel penalty: speed = base + (1 - base) * 0.5.
-- A 0.6x biome becomes 0.8x on a road; an unpenalised biome stays 1.0x.
local function speedWithRoad(map, biomeId, x, y)
    local speedMod = WorldState.biomeSpeedModifiers[biomeId] or 1
    if onRoad(map, x, y) then
        speedMod = 1 - (1 - speedMod) * 0.5
    end
    return speedMod
end

local function initializeWorldPresentation()
    WorldState.currentMap = GameContext.data.currentMap

    if not WorldState.currentMap then
        error("World state entered without initialized map. Call GameInitializer.initNewGame() first.")
    end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    WorldState.camera = Camera.new(screenWidth, screenHeight)
    WorldState.camera:setBounds(0, 0, WorldState.currentMap.width, WorldState.currentMap.height)
    WorldState.camera:setZoom(WorldState.defaultZoom or 1.0)

    local playerParty = GameContext.data.playerParty
    if playerParty then
        WorldState.camera.x = playerParty.x
        WorldState.camera.y = playerParty.y
    end

    WorldState.nearbyLocation = nil
    WorldState.nearbyParty = nil
end

function WorldState.enter()
    initializeWorldPresentation()
    
    -- Initialize UI font
    WorldState.font = love.graphics.newFont(14)
    WorldState.interactionCooldowns = {}
    EncounterSystem.reset()
    WorldState.isResting = WorldState.restModeRequested and true or false
    WorldState.restModeRequested = false
    WorldState.restInputLock = WorldState.isResting and 0.2 or 0
    if WorldState.isResting then
        WorldState.restStartTotalHour = TimeSystem.getDay() * 24 + TimeSystem.getHour()
    end
end

function WorldState.requestRestMode(enabled)
    WorldState.restModeRequested = enabled and true or false
end

function WorldState.resume()
    if not WorldState.currentMap or not WorldState.camera then
        initializeWorldPresentation()
    end

    if not WorldState.font then
        WorldState.font = love.graphics.newFont(14)
    end

    EncounterSystem.reset()
    WorldState.isResting = false
    WorldState.restInputLock = 0
end

function WorldState.exit()
    -- Cleanup world state
    WorldState.camera = nil
    WorldState.currentMap = nil
    WorldState.nearbyLocation = nil
    WorldState.nearbyParty = nil
end

-- Show a transient floating favor notification on the world map (same style as
-- the quest-completion popup in DialogueScreen). Fades in, drifts upward and
-- auto-clears; it does not block world input.
function WorldState.showFavorPopup(favor)
    if not favor or favor <= 0 then return end
    WorldState.popup = {
        lines = { string.format("+%d Favor", favor) },
        timer = 0,
        duration = 3
    }
end

function WorldState.update(dt)
    local playerParty = GameContext.data.playerParty
    if not playerParty or not WorldState.currentMap then return end

    -- Advance the floating favor notification timer (non-blocking)
    if WorldState.popup then
        WorldState.popup.timer = WorldState.popup.timer + dt
        if WorldState.popup.timer >= WorldState.popup.duration then
            WorldState.popup = nil
        end
    end

    if WorldState.restInputLock > 0 then
        WorldState.restInputLock = math.max(0, WorldState.restInputLock - dt)
    end

    if WorldState.isResting and WorldState.restInputLock <= 0 then
        -- Auto-return after 1 full day (24 game-hours)
        local totalHourNow = TimeSystem.getDay() * 24 + TimeSystem.getHour()
        if WorldState.restStartTotalHour and totalHourNow >= WorldState.restStartTotalHour + 24 then
            WorldState.restStartTotalHour = nil
            StateManager.pop()
            return
        end
        -- Manual cancel
        if Input.isKeyDown("escape") then
            WorldState.restStartTotalHour = nil
            StateManager.pop()
            return
        end
    end
    
    -- Update interaction cooldowns
    for id, timer in pairs(WorldState.interactionCooldowns) do
        WorldState.interactionCooldowns[id] = timer - dt
        if WorldState.interactionCooldowns[id] <= 0 then
            WorldState.interactionCooldowns[id] = nil
        end
    end
    
    -- Open Inventory
    if not WorldState.isResting and Input.isKeyDown("i") then
        StateManager.push("inventory")
        return
    end
    
    -- Open Quest Log
    if not WorldState.isResting and Input.isKeyDown("l") then
        StateManager.push("quest_log")
        return
    end

    -- Handle player movement and time progression
    local moveX, moveY = 0, 0
    
    if not WorldState.isResting and (Input.isKeyDown("up") or Input.isKeyDown("w")) then
        moveY = moveY - 1
    end
    if not WorldState.isResting and (Input.isKeyDown("down") or Input.isKeyDown("s")) then
        moveY = moveY + 1
    end
    if not WorldState.isResting and (Input.isKeyDown("left") or Input.isKeyDown("a")) then
        moveX = moveX - 1
    end
    if not WorldState.isResting and (Input.isKeyDown("right") or Input.isKeyDown("d")) then
        moveX = moveX + 1
    end
    
    -- Check if player is waiting (Spacebar)
    local isWaiting = (not WorldState.isResting) and Input.isKeyDown("space")
    local isMoving = (moveX ~= 0 or moveY ~= 0)
    local shouldAdvanceTime = WorldState.isResting or isMoving or isWaiting
    
    -- Only advance time if moving or waiting
    if shouldAdvanceTime then
        TimeSystem.setPaused(false)
        TimeSystem.update(dt)
    else
        TimeSystem.setPaused(true)
    end

    if shouldAdvanceTime then
        local healMultiplier = WorldState.isResting and WorldState.restHealMultiplier or 1
        healPartyOverTime(dt, healMultiplier)
    end
    
    -- Normalize diagonal movement
    local magnitude = math.sqrt(moveX * moveX + moveY * moveY)
    if magnitude > 0 then
        moveX = moveX / magnitude
        moveY = moveY / magnitude
    end
    
    -- Update party position based on input (biome modifies travel speed,
    -- and roads halve that biome penalty)
    local currentX, currentY = playerParty:getPosition()
    local biomeId = WorldState.currentMap:getBiomeAt(currentX, currentY)
    local speedMod = speedWithRoad(WorldState.currentMap, biomeId, currentX, currentY)
    local newX = currentX + moveX * WorldState.playerPartySpeed * speedMod * dt
    local newY = currentY + moveY * WorldState.playerPartySpeed * speedMod * dt
    
    -- Clamp party position to map bounds
    newX = math.max(0, math.min(newX, WorldState.currentMap.width))
    newY = math.max(0, math.min(newY, WorldState.currentMap.height))

    if WorldState.currentMap.isWalkable then
        if not WorldState.currentMap:isWalkable(newX, newY) then
            local canMoveXOnly = WorldState.currentMap:isWalkable(newX, currentY)
            local canMoveYOnly = WorldState.currentMap:isWalkable(currentX, newY)

            if canMoveXOnly then
                newY = currentY
            elseif canMoveYOnly then
                newX = currentX
            else
                newX = currentX
                newY = currentY
            end
        end
    end
    
    playerParty:setPosition(newX, newY)
    
    -- Update camera to follow party
    WorldState.camera:update(dt, playerParty)

    -- Random encounter rolls while traveling: accumulate the distance walked
    -- and let the encounter system decide when to spawn a hostile party nearby.
    if isMoving and not WorldState.isResting then
        local ddx = newX - currentX
        local ddy = newY - currentY
        local distanceTraveled = math.sqrt(ddx * ddx + ddy * ddy)
        EncounterSystem.update(dt, distanceTraveled)
    end

    local interactionRadius = 30

    if WorldState.isResting then
        return
    end

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
                
                -- Check faction hostility. Spawned encounter parties carry a
                -- `hostile` flag (see systems/encounter_system.lua); bandits are
                -- always hostile. In the future this could use FactionSystem.
                local isHostile = otherParty.hostile == true or otherParty.faction == "bandits"

                if isHostile then
                    -- Check cooldown to prevent immediate re-trigger
                    if not WorldState.interactionCooldowns[otherParty.id] then
                        -- Set cooldown (3 seconds) so player has time to move away after leaving dialogue
                        WorldState.interactionCooldowns[otherParty.id] = 2.0
                        -- Force interaction immediately
                        local dialogueId = otherParty.dialogueId or "bandit_start"
                        StateManager.push("dialogue", {dialogueId = dialogueId, target = otherParty})
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
    
    -- Draw map (scaled 2x by the camera zoom; nearest filter gives the
    -- requested slightly-pixelated zoomed-in look)
    WorldState.currentMap:drawMap()
    
    -- Markers are counter-scaled so they keep a constant on-screen size
    local markerScale = 1 / WorldState.camera:getZoom()
    
    -- Draw locations
    WorldState.currentMap:drawLocations(markerScale)
    
    -- Draw parties
    WorldState.currentMap:drawParties(markerScale)
    
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
    local timeStr
    
    if AttributeSystem.partyHasLevel("navigation", 1) then
        local hour = math.floor(TimeSystem.getHour())
        local minute = math.floor((TimeSystem.getHour() - hour) * 60)
        timeStr = string.format("Day %d | %s | %02d:%02d", day, period, hour, minute)
    else
        timeStr = string.format("Day %d, %s", day, period)
    end
    
    local textWidth = WorldState.font:getWidth(timeStr)
    love.graphics.print(timeStr, love.graphics.getWidth() - textWidth - 20, 20)

    -- Draw current biome (debug)
    local playerParty = GameContext.data.playerParty
    if playerParty and WorldState.currentMap then
        local biomeId = WorldState.currentMap:getBiomeAt(playerParty.x, playerParty.y)
        local isOnRoad = onRoad(WorldState.currentMap, playerParty.x, playerParty.y)
        local speedMod = speedWithRoad(WorldState.currentMap, biomeId, playerParty.x, playerParty.y)
        local biomeStr = "Biome: " .. (biomeId or "unknown")
            .. " (" .. string.format("%.2g", speedMod) .. "x speed)"
            .. (isOnRoad and " [road]" or "")
        local biomeWidth = WorldState.font:getWidth(biomeStr)
        love.graphics.setColor(0.7, 0.9, 0.7, 1)
        love.graphics.print(biomeStr, love.graphics.getWidth() - biomeWidth - 20, 40)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Draw HUD Bars (HP and Favor)
    if playerParty then
        local barX, barY = 20, 35
        local barW, barH = 200, 15
        
        -- 1. Party HP Bar
        local partyHpPct = playerParty:getAveragePartyHp()
        
        -- Background
        love.graphics.setColor(0.2, 0, 0, 1)
        love.graphics.rectangle("fill", barX, barY, barW, barH)
        
        -- Foreground
        love.graphics.setColor(0.8, 0.1, 0.1, 1)
        love.graphics.rectangle("fill", barX, barY, barW * partyHpPct, barH)
        
        -- Border
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", barX, barY, barW, barH)
        
        -- Player Marker
        local player = GameContext.data.player
        if player then
            local max = player.maxHp or (player.stats and player.stats.health) or 100
            local current = player.hp or max
            local playerPct = math.max(0, math.min(1, current / max))
            
            local markerX = barX + (barW * playerPct)
            love.graphics.setColor(1, 1, 0, 1) -- Yellow marker
            love.graphics.setLineWidth(2)
            love.graphics.line(markerX, barY - 2, markerX, barY + barH + 2)
            love.graphics.setLineWidth(1)
        end
        
        -- Label
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Party HP", barX, barY - 18)
        
        -- 2. Favor Bar (Right of HP bar)
        local favorX = barX + barW + 20
        local favor = GameContext.data.favor or 0
        local favorPct = math.min(1, math.max(0, favor / 100))
        
        -- Background
        love.graphics.setColor(0.2, 0.2, 0, 1)
        love.graphics.rectangle("fill", favorX, barY, barW, barH)
        
        -- Foreground
        love.graphics.setColor(0.8, 0.8, 0.2, 1)
        love.graphics.rectangle("fill", favorX, barY, barW * favorPct, barH)
        
        -- Border
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", favorX, barY, barW, barH)
        
        -- Label
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Favor: " .. math.floor(favor), favorX, barY - 18)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("World View - WASD to move, [I] Inventory, [L] Quests", 0, love.graphics.getHeight() - 30, love.graphics.getWidth() - 20, "right")

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

    -- Draw floating favor notification (fades in/out, drifts upward) on top
    local popupFont = WorldState.font or love.graphics.getFont()
    if WorldState.popup then
        local screenW = love.graphics.getWidth()
        local screenH = love.graphics.getHeight()

        local alpha = 1
        local fadeDuration = 0.25
        local remaining = WorldState.popup.duration - WorldState.popup.timer
        if WorldState.popup.timer < fadeDuration then
            alpha = WorldState.popup.timer / fadeDuration
        elseif remaining < fadeDuration then
            alpha = remaining / fadeDuration
        end

        local drift = math.min(WorldState.popup.timer * 24, 36)
        local baseY = screenH - 120 - drift

        love.graphics.setFont(popupFont)
        for i, line in ipairs(WorldState.popup.lines) do
            local lineY = baseY + ((i - 1) * 22)
            local shadowOffset = 2

            love.graphics.setColor(0, 0, 0, 0.8 * alpha)
            love.graphics.printf(line, shadowOffset, lineY + shadowOffset, screenW, "center")

            love.graphics.setColor(1, 0.9, 0.4, alpha)
            love.graphics.printf(line, 0, lineY, screenW, "center")
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return WorldState
