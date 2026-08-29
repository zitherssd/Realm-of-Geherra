-- game/states/world_generation_state.lua
-- Splash shown while the painted world map is generated step-by-step.
--
-- The heavy generation work is broken into named pipeline stages by
-- systems/map_generator.lua; this state advances one stage per frame and draws
-- a progress bar + current step so the player sees it working, then hands off
-- to the world state.

local StateManager = require("src.core.state_manager")
local GameInitializer = require("src.game.game_initializer")
local LocationPopulationSystem = require("src.systems.location_population_system")
local PaintedMapLoader = require("src.systems.painted_map_loader")

local WorldGenerationState = {
    options = {},
    generator = nil,
    started = false,
    finished = false,
    progress = 0,
    stepIndex = 0,
    totalSteps = 0,
    stepName = nil,
    elapsed = 0,
    fonts = nil,
}

function WorldGenerationState.enter(params)
    params = params or {}
    WorldGenerationState.options = params.options or {}
    WorldGenerationState.generator = PaintedMapLoader.createGeneration(WorldGenerationState.options)
    WorldGenerationState.totalSteps = WorldGenerationState.generator.totalSteps
    WorldGenerationState.started = false
    WorldGenerationState.finished = false
    WorldGenerationState.progress = 0
    WorldGenerationState.stepIndex = 0
    WorldGenerationState.stepName = nil
    WorldGenerationState.elapsed = 0
    WorldGenerationState.fonts = {
        title = love.graphics.newFont(36),
        subtitle = love.graphics.newFont(18),
        step = love.graphics.newFont(16),
    }
end

function WorldGenerationState.update(dt)
    WorldGenerationState.elapsed = WorldGenerationState.elapsed + dt

    if not WorldGenerationState.started then
        GameInitializer.beginNewGame(WorldGenerationState.options)
        WorldGenerationState.started = true
    end

    if WorldGenerationState.finished then
        return
    end

    -- Run one named pipeline stage per frame so the splash can animate.
    local gen = WorldGenerationState.generator
    local done = gen:advance()

    WorldGenerationState.stepIndex = gen.currentIndex
    WorldGenerationState.stepName = gen.currentName
    WorldGenerationState.progress = gen:progress()

    if done then
        WorldGenerationState.finished = true
        local map = PaintedMapLoader.buildMap(gen.result, WorldGenerationState.options)
        local locations = LocationPopulationSystem.populate(map, map.worldGen)
        GameInitializer.finalizeNewGame(map, locations)
        StateManager.swap("world")
    end
end

function WorldGenerationState.draw()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.clear(0.05, 0.06, 0.10)

    local fonts = WorldGenerationState.fonts
    local cx, cy = sw / 2, sh / 2

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.printf("REALM OF GEHERRA", 0, cy - 150, sw, "center")

    love.graphics.setFont(fonts.subtitle)
    love.graphics.setColor(0.85, 0.85, 0.9, 1)
    love.graphics.printf("Forging the realm...", 0, cy - 90, sw, "center")

    -- Progress bar
    local barW, barH = 440, 20
    local barX, barY = cx - barW / 2, cy - 20
    local progress = WorldGenerationState.progress or 0

    love.graphics.setColor(0.16, 0.16, 0.22, 1)
    love.graphics.rectangle("fill", barX, barY, barW, barH)
    love.graphics.setColor(0.85, 0.72, 0.2, 1)
    love.graphics.rectangle("fill", barX, barY, barW * progress, barH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", barX, barY, barW, barH)

    -- Step label
    love.graphics.setFont(fonts.step)
    love.graphics.setColor(0.75, 0.75, 0.82, 1)
    local stepText = string.format("Step %d of %d: %s",
        WorldGenerationState.stepIndex, WorldGenerationState.totalSteps,
        WorldGenerationState.stepName or "Finalizing")
    love.graphics.printf(stepText, 0, barY + barH + 14, sw, "center")

    -- Animated dots
    local dots = string.rep(".", (math.floor(WorldGenerationState.elapsed * 2) % 4))
    love.graphics.setColor(0.6, 0.6, 0.7, 1)
    love.graphics.printf("Preparing the realm" .. dots, 0, cy + 70, sw, "center")
end

return WorldGenerationState
