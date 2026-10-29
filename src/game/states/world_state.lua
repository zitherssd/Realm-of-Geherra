-- game/states/world_state.lua
-- World exploration state

local Input = require("src.core.input")
local GameContext = require("src.game.game_context")
local EventBus = require("src.core.event_bus")
local MovementSystem = require("src.systems.actors.movement_system")
local FactionSystem = require("src.systems.social.faction_system")
local StateManager = require("src.core.state_manager")
local Camera = require("src.world.camera")
local TimeSystem = require("src.systems.campaign.time_system")
local AttributeSystem = require("src.systems.actors.attribute_system")
local CampaignRuntime = require("src.game.campaign.campaign_runtime")
local PartySystem = require("src.systems.parties.party_system")
local PlayerSystem = require("src.systems.actors.player_system")
local VisibilitySystem = require("src.systems.parties.visibility_system")
local PartyInteractionSystem = require("src.systems.parties.party_interaction_system")
local WorldEncounterSystem = require("src.systems.campaign.world_encounter_system")
local BattlefieldInteraction = require("src.systems.battlefield.battlefield_interaction")
local DebugMode = require("src.debug.mode")
local DebugOverlay = require("src.ui.screens.debug_overlay")
local EventViewer = require("src.ui.screens.world_event_viewer")
local ServiceViewer = require("src.ui.screens.service_viewer")
local EcsWorld = require("src.ecs.world")

local WorldState = {
    debugOverlay = DebugOverlay.new(),
    camera = nil,
    currentMap = nil,
    defaultZoom = 2.0,       -- world map shown 2x (zoomed in, slightly pixelated)
    nearbyParty = nil,       -- The party currently in interaction range
    nearbyLocation = nil,    -- The location currently in interaction range
    nearbyBattlefield = nil, -- Discovered remains within interaction range
    font = nil,
    interactionCooldowns = {},
    isResting = false,
    restInputLock = 0,
    restModeRequested = false,
    restStartTotalHour = nil,  -- total game-hours when rest began
    popup = nil,                -- transient floating notification (e.g. battle favor reward)
    hoveredEncounterId = nil,
    pendingRaidBattle = nil
}

local function findParty(map, partyId)
    for _, party in ipairs(map:getParties() or {}) do
        if party.id == partyId then
            return party
        end
    end
    return nil
end

local function rejectRaidContact(event, reason)
    EventBus.emit("party_encounter_rejected", {
        mapId = event.mapId,
        activityType = event.activityType,
        sourcePartyId = event.sourcePartyId,
        targetPartyId = event.targetPartyId,
        reason = reason
    })
end

function WorldState._onPartyContact(event)
    if type(event) ~= "table" or event.activityType ~= "raid" then return end
    local map = WorldState.currentMap
    local playerParty = GameContext.data and GameContext.data.playerParty
    if not map or event.mapId ~= map.id or not playerParty or
        event.targetPartyId ~= playerParty.id then
        return
    end

    local raider = findParty(map, event.sourcePartyId)
    local activity = raider and raider.world_activity
    if not raider or not activity or activity.status ~= "active" or
        activity.phase ~= "contact" or activity.targetId ~= playerParty.id then
        rejectRaidContact(event, "contact_stale")
        return
    end
    if findParty(map, playerParty.id) ~= playerParty then
        rejectRaidContact(event, "party_missing")
        return
    end
    if not raider.actors or #raider.actors == 0 or
        not playerParty.actors or #playerParty.actors == 0 then
        rejectRaidContact(event, "party_empty")
        return
    end
    if raider.activeEncounterId or playerParty.activeEncounterId then
        rejectRaidContact(event, "party_already_engaged")
        return
    end
    if (map.partyEncounterCooldowns and
        ((map.partyEncounterCooldowns[raider.id] or 0) > 0 or
        (map.partyEncounterCooldowns[playerParty.id] or 0) > 0)) then
        rejectRaidContact(event, "party_cooldown")
        return
    end
    if WorldState.pendingRaidBattle then
        rejectRaidContact(event, "player_battle_already_pending")
        return
    end

    map.nextPlayerBattleSequence = (map.nextPlayerBattleSequence or 1) + 1
    local encounterId = tostring(map.id or "map") .. ":player-battle:" ..
        tostring(map.nextPlayerBattleSequence - 1)
    WorldState.pendingRaidBattle = {
        mapId = map.id,
        encounterId = encounterId,
        sourcePartyId = raider.id,
        targetPartyId = playerParty.id
    }

    EventBus.emit("party_encounter_started", {
        mapId = map.id,
        activityType = "raid",
        sourcePartyId = raider.id,
        targetPartyId = playerParty.id,
        encounterId = encounterId
    })
    if activity.phase ~= "engaged" then
        WorldState.pendingRaidBattle = nil
        rejectRaidContact(event, "activity_transition_failed")
    end
end

local function startPendingRaidBattle()
    local pending = WorldState.pendingRaidBattle
    if not pending then return false end
    WorldState.pendingRaidBattle = nil
    local raider = WorldState.currentMap and findParty(
        WorldState.currentMap,
        pending.sourcePartyId
    )
    if not raider then return false end

    StateManager.swap("battle", {
        enemyParty = raider,
        onComplete = function(result)
            EventBus.emit("party_encounter_finished", {
                mapId = pending.mapId,
                activityType = "raid",
                sourcePartyId = pending.sourcePartyId,
                targetPartyId = pending.targetPartyId,
                encounterId = pending.encounterId,
                outcome = result.outcome,
                winnerPartyId = result.winnerPartyId
            })
        end
    })
    return true
end

WorldState._startPendingRaidBattle = startPendingRaidBattle

local function updateHoveredEncounter()
    WorldState.hoveredEncounterId = nil
    if not WorldState.currentMap or not WorldState.camera then return end

    local mouseX, mouseY = love.mouse.getPosition()
    local worldX, worldY = WorldState.camera:screenToWorld(mouseX, mouseY)
    local hitRadius = 18 / WorldState.camera:getZoom()

    for encounterId, encounter in pairs(WorldState.currentMap.activeEncounters or {}) do
        if encounter.state == "active" then
            local partyA = findParty(WorldState.currentMap, encounter.partyAId)
            local partyB = findParty(WorldState.currentMap, encounter.partyBId)
            if partyA and partyB then
                local x = (partyA.x + partyB.x) / 2
                local y = (partyA.y + partyB.y) / 2
                local dx, dy = worldX - x, worldY - y
                if dx * dx + dy * dy <= hitRadius * hitRadius then
                    WorldState.hoveredEncounterId = encounterId
                    return
                end
            end
        end
    end
end

local function initializeWorldPresentation()
    WorldState.serviceViewer = nil
    WorldState.eventViewer = nil
    WorldState.debugOverlay:close()
    WorldState.currentMap = GameContext.data.currentMap

    if not WorldState.currentMap then
        error("World state entered without initialized map. Call GameInitializer.initNewGame() first.")
    end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    WorldState.camera = Camera.new(screenWidth, screenHeight)
    WorldState.camera:setBounds(0, 0, WorldState.currentMap.width, WorldState.currentMap.height)
    WorldState.camera:setZoom(WorldState.defaultZoom or 1.0)
    if WorldState.currentMap.worldGen and WorldState.currentMap.worldGen.debugLayout then
        WorldState.camera:setZoom(math.min((screenWidth - 64) / WorldState.currentMap.width,
            (screenHeight - 120) / WorldState.currentMap.height))
    end

    local playerParty = GameContext.data.playerParty
    if playerParty then
        WorldState.camera.x = playerParty.x
        WorldState.camera.y = playerParty.y
    end

    WorldState.nearbyLocation = nil
    WorldState.nearbyBattlefield = nil
    WorldState.nearbyParty = nil
    WorldState.hoveredEncounterId = nil
    WorldState.pendingRaidBattle = nil
    local fixture = GameContext.data.debugCampaign
    if fixture and DebugMode.enabled then
        WorldState.debugOverlay:inspect("location", fixture.homeId)
    end
end

function WorldState.enter()
    initializeWorldPresentation()
    
    -- Initialize UI font
    WorldState.font = love.graphics.newFont(14)
    WorldState.interactionCooldowns = {}
    CampaignRuntime.enterWorld()
    EventBus.unsubscribe("party_contact", WorldState._onPartyContact)
    EventBus.subscribe("party_contact", WorldState._onPartyContact)
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
    WorldState.serviceViewer = nil
    WorldState.eventViewer = nil
    WorldState.debugOverlay:close()
    if not WorldState.currentMap or not WorldState.camera then
        initializeWorldPresentation()
    end

    if not WorldState.font then
        WorldState.font = love.graphics.newFont(14)
    end

    CampaignRuntime.resumeWorld()
    WorldState.isResting = false
    WorldState.restInputLock = 0
end

function WorldState.exit()
    WorldState.serviceViewer = nil
    WorldState.eventViewer = nil
    WorldState.debugOverlay:close()
    -- Cleanup world state
    WorldState.camera = nil
    WorldState.currentMap = nil
    WorldState.nearbyLocation = nil
    WorldState.nearbyBattlefield = nil
    WorldState.nearbyParty = nil
    WorldState.hoveredEncounterId = nil
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
    if not DebugMode.enabled then WorldState.debugOverlay:close() end
    if WorldState.serviceViewer or WorldState.eventViewer or WorldState.debugOverlay:blocksWorldInput() then
        TimeSystem.setPaused(true)
        return
    end

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
    local playerActivity = playerParty.world_activity
    local playerMovementActivityActive = playerActivity and (playerActivity.type == "travel" or playerActivity.type == "roam" or playerActivity.type == "search")
        and playerActivity.status == "active"
    
    if not WorldState.isResting and not playerMovementActivityActive
        and (Input.isKeyDown("up") or Input.isKeyDown("w")) then
        moveY = moveY - 1
    end
    if not WorldState.isResting and not playerMovementActivityActive
        and (Input.isKeyDown("down") or Input.isKeyDown("s")) then
        moveY = moveY + 1
    end
    if not WorldState.isResting and not playerMovementActivityActive
        and (Input.isKeyDown("left") or Input.isKeyDown("a")) then
        moveX = moveX - 1
    end
    if not WorldState.isResting and not playerMovementActivityActive
        and (Input.isKeyDown("right") or Input.isKeyDown("d")) then
        moveX = moveX + 1
    end
    
    -- Check if player is waiting (Spacebar)
    local isWaiting = (not WorldState.isResting) and Input.isKeyDown("space")
    local isMoving = (moveX ~= 0 or moveY ~= 0)
    local shouldAdvanceTime = WorldState.isResting or isMoving or isWaiting
        or playerMovementActivityActive
    local elapsedWorldHours = 0
    local elapsedWorldSeconds = 0
    
    -- Only advance time if moving or waiting
    if shouldAdvanceTime then
        TimeSystem.setPaused(false)
        elapsedWorldHours, elapsedWorldSeconds = CampaignRuntime.advanceTime(dt)
    else
        TimeSystem.setPaused(true)
    end

    
    -- Normalize diagonal movement
    local magnitude = math.sqrt(moveX * moveX + moveY * moveY)
    if magnitude > 0 then
        moveX = moveX / magnitude
        moveY = moveY / magnitude
    end
    
    -- Update party position based on input (biome modifies travel speed,
    -- and roads halve that biome penalty)
    local currentX, currentY = PartySystem.getPosition(playerParty)
    local speed = PartySystem.getPartySpeed(playerParty, nil, WorldState.currentMap)
    local newX = currentX + moveX * speed * dt
    local newY = currentY + moveY * speed * dt
    
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
    
    -- Travel arrivals station the existing player party. Manual movement must
    -- release that membership before moving, just as another Travel would.
    if newX ~= currentX or newY ~= currentY then
        for _, location in ipairs(WorldState.currentMap:getLocations()) do
            for _, stationed in ipairs(location.stationedParties or {}) do
                if stationed == playerParty then WorldState.currentMap:addParty(playerParty); break end
            end
        end
    end
    PartySystem.setPosition(playerParty, newX, newY)
    
    -- Update camera to follow party
    WorldState.camera:update(dt, playerParty)

    -- Random encounter rolls while traveling: accumulate the distance walked
    -- and let the encounter system decide when to spawn a hostile party nearby.
    local distanceTraveled
    if isMoving and not WorldState.isResting and elapsedWorldSeconds > 0 then
        local ddx = newX - currentX
        local ddy = newY - currentY
        distanceTraveled = math.sqrt(ddx * ddx + ddy * ddy)
    end

    local recoveryReservations = CampaignRuntime.updateEncounters(
        elapsedWorldHours, elapsedWorldSeconds, WorldState.currentMap, playerParty, distanceTraveled)
    updateHoveredEncounter()

    CampaignRuntime.update(elapsedWorldSeconds, WorldState.currentMap, playerParty,
        WorldState.isResting, recoveryReservations, elapsedWorldHours)
    if startPendingRaidBattle() then
        return
    end

    VisibilitySystem.update(playerParty, WorldState.currentMap)

    if WorldState.isResting then
        return
    end

    -- Check for locations
    WorldState.nearbyLocation = nil
    WorldState.nearbyBattlefield = nil
    for _, location in ipairs(WorldState.currentMap.locations) do
        if location.discovered then
            local dx = location.x - playerParty.x
            local dy = location.y - playerParty.y
            local dist = math.sqrt(dx*dx + dy*dy)

            if dist < PartyInteractionSystem.interactionRadius then
                WorldState.nearbyLocation = location
                if Input.isKeyDown("return") or Input.isKeyDown("kpenter") then
                    StateManager.push("location", { location = location })
                    return -- Stop update
                end
            end

            for _, site in ipairs(WorldState.currentMap:getBattlefieldRemains() or {}) do
                if site.discovered and site.history and site.history.position then
                    local dx = site.history.position.x - playerParty.x
                    local dy = site.history.position.y - playerParty.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < PartyInteractionSystem.interactionRadius then
                        WorldState.nearbyBattlefield = site
                        if Input.isKeyDown("return") or Input.isKeyDown("kpenter") then
                            StateManager.push("dialogue", {
                                battlefieldSiteId = site.id
                            })
                            return
                        end
                    end
                end
            end
        end
    end

    -- Check for collisions/interactions with other parties
    local playerWantsToInteract = Input.isKeyDown("return") or Input.isKeyDown("kpenter")
    local nearbyParty, interrupted = PartyInteractionSystem.update(
        dt, 
        WorldState.currentMap, 
        playerParty, 
        WorldState.interactionCooldowns, 
        playerWantsToInteract
    )
    
    WorldState.nearbyParty = nearbyParty
    
    if interrupted then
        return -- Stop update to prevent multiple triggers
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
    WorldState.currentMap:drawBattlefieldRemains(markerScale)
    
    -- Draw parties
    WorldState.currentMap:drawParties(markerScale)

    -- Keep active encounter participants visually distinct and mark the
    -- battle's current position without scaling the icon with camera zoom.
    for _, encounter in pairs(WorldState.currentMap.activeEncounters or {}) do
        if encounter.state == "active" then
            local partyA = findParty(WorldState.currentMap, encounter.partyAId)
            local partyB = findParty(WorldState.currentMap, encounter.partyBId)
            if partyA and partyB then
                for _, party in ipairs({partyA, partyB}) do
                    love.graphics.setColor(1, 0.35, 0.12, 0.95)
                    love.graphics.setLineWidth(2 / WorldState.camera:getZoom())
                    love.graphics.circle("line", party.x, party.y, 20 / WorldState.camera:getZoom())
                end

                local x = (partyA.x + partyB.x) / 2
                local y = (partyA.y + partyB.y) / 2
                local inverseZoom = 1 / WorldState.camera:getZoom()
                love.graphics.push()
                love.graphics.translate(x, y)
                love.graphics.scale(inverseZoom)
                love.graphics.setColor(0.12, 0.04, 0.03, 0.9)
                love.graphics.circle("fill", 0, 0, 18)
                love.graphics.setColor(1, 0.25, 0.12, 1)
                love.graphics.setLineWidth(3)
                love.graphics.line(-9, -9, 9, 9)
                love.graphics.line(-9, 9, 9, -9)
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf("BATTLE", -34, 20, 68, "center")
                love.graphics.pop()
            end
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- DEBUG: Draw interaction radius
    local playerParty = GameContext.data.playerParty
    if DebugMode.enabled and playerParty then
        local VisibilityConfig = require("src.data.visibility")
        local divisor = VisibilityConfig.radiusDivisor or 1

        -- Draw radius for all visible parties (and player)
        for _, party in ipairs(WorldState.currentMap.parties) do
            if party.visible or party.id == playerParty.id then
                love.graphics.setColor(1, 1, 0, 0.5) -- semi-transparent yellow
                love.graphics.circle("line", party.x, party.y, PartyInteractionSystem.interactionRadius)
                
                -- Visibility debug circles
                local profile = PartySystem.getPartyProfile(party)
                local sight = PartySystem.getPartySight(party)
                
                love.graphics.setColor(1, 0, 1, 0.4) -- magenta for profile
                love.graphics.circle("line", party.x, party.y, profile / divisor)
                
                love.graphics.setColor(0, 1, 1, 0.4) -- cyan for sight
                love.graphics.circle("line", party.x, party.y, sight / divisor)
            end
        end
        
        love.graphics.setColor(1, 0.5, 0, 0.5) -- semi-transparent orange for locations
        for _, location in ipairs(WorldState.currentMap.locations) do
            if location.discovered then
                love.graphics.circle("line", location.x, location.y, PartyInteractionSystem.interactionRadius)
            end
        end
        
        love.graphics.setColor(1, 1, 1, 1) -- reset color
    end
    
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

    local encounterInfo = WorldEncounterSystem.getInspectionData(
        WorldState.currentMap,
        WorldState.hoveredEncounterId
    )
    if encounterInfo then
        local panelX, panelY, panelW, panelH = 20, 90, 300, 112
        love.graphics.setColor(0.12, 0.08, 0.06, 0.92)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
        love.graphics.setColor(0.9, 0.55, 0.2, 1)
        love.graphics.rectangle("line", panelX, panelY, panelW, panelH)
        love.graphics.setColor(1, 0.85, 0.65, 1)
        love.graphics.print("NPC ENCOUNTER", panelX + 10, panelY + 8)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(encounterInfo.partyAName .. " vs " .. encounterInfo.partyBName, panelX + 10, panelY + 29)
        love.graphics.print("Status: " .. encounterInfo.status, panelX + 10, panelY + 49)
        love.graphics.print(string.format("Elapsed: %.2f world-hours", encounterInfo.elapsedWorldHours), panelX + 10, panelY + 69)
        love.graphics.print(string.format("Survivors: %d vs %d", encounterInfo.survivingPartyA, encounterInfo.survivingPartyB), panelX + 10, panelY + 89)
    end

    -- Draw current biome (debug)
    local playerParty = GameContext.data.playerParty
    if DebugMode.enabled and playerParty and WorldState.currentMap then
        local biomeId = WorldState.currentMap:getBiomeAt(playerParty.x, playerParty.y)
        local isOnRoad = WorldState.currentMap:isOnRoad(playerParty.x, playerParty.y)
        local speedMod = WorldState.currentMap:getTravelSpeedMod(playerParty.x, playerParty.y)
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
        local partyHpPct = PartySystem.getAveragePartyHpPercent(playerParty)
        
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
        local favor = PlayerSystem.getFavor()
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
    love.graphics.printf("WASD: move | I: inventory | P: deployment | L: quests | F1: debug | F2: events | F3: services", 0, love.graphics.getHeight() - 30, love.graphics.getWidth() - 20, "right")

    -- Draw location interaction hint
    if WorldState.nearbyLocation then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.printf("Press ENTER to enter " .. WorldState.nearbyLocation.name, 
            0, love.graphics.getHeight() - 130, love.graphics.getWidth(), "center")
    end

    if WorldState.nearbyBattlefield then
        love.graphics.setColor(1, 0.8, 0.45, 1)
        love.graphics.printf("Press ENTER to inspect the battlefield",
            0, love.graphics.getHeight() - 160, love.graphics.getWidth(), "center")
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
    WorldState.debugOverlay:draw(WorldState.currentMap)
    if WorldState.eventViewer then WorldState.eventViewer:draw() end
    if WorldState.serviceViewer then WorldState.serviceViewer:draw() end
end

function WorldState.debugModeChanged()
    WorldState.debugOverlay:close()
end

function WorldState.mousepressed(x, y, button)
    if WorldState.serviceViewer then
        if WorldState.serviceViewer:mousepressed(x, y, button) == "close" then WorldState.serviceViewer = nil; Input.init() end
        return true
    end
    if WorldState.eventViewer then
        if WorldState.eventViewer:mousepressed(x, y, button) == "close" then WorldState.eventViewer = nil end
        return true
    end
    return WorldState.debugOverlay:mousepressed(WorldState.currentMap, WorldState.camera, x, y, button)
end

function WorldState.keypressed(key, isRepeat)
    if key == "p" and not isRepeat and not WorldState.isResting then
        StateManager.push("party_deployment")
        return true
    end
    if key == "f3" then
        if not isRepeat then
            WorldState.serviceViewer = not WorldState.serviceViewer and ServiceViewer.new(EcsWorld.campaign, WorldState.currentMap) or nil
            WorldState.eventViewer = nil
            WorldState.debugOverlay:close()
            Input.init()
        end
        return true
    end
    if key == "f2" then
        if not isRepeat then
            WorldState.eventViewer = not WorldState.eventViewer and EventViewer.new(EcsWorld.campaign) or nil
            WorldState.serviceViewer = nil
            WorldState.debugOverlay:close()
            Input.init()
        end
        return true
    end
    if WorldState.serviceViewer then
        if key == "escape" then WorldState.serviceViewer = nil; Input.init()
        else WorldState.serviceViewer:keypressed(key) end
        return true
    end
    if WorldState.eventViewer then
        if key == "escape" then WorldState.eventViewer = nil end
        return true
    end
    return WorldState.debugOverlay:keypressed(key)
end

function WorldState.textinput(text)
    if WorldState.serviceViewer or WorldState.eventViewer then return end
    WorldState.debugOverlay:textinput(text)
end

function WorldState.wheelmoved(_, y)
    if WorldState.serviceViewer then WorldState.serviceViewer:wheelmoved(y); return true end
    if WorldState.eventViewer then WorldState.eventViewer:wheelmoved(y); return true end
    return WorldState.debugOverlay:wheelmoved(WorldState.currentMap, y)
end

function WorldState.blocksPointerInput()
    return WorldState.eventViewer ~= nil or WorldState.serviceViewer ~= nil
end

return WorldState
