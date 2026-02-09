-- game/states/menu_state.lua
-- Main menu state

local Input = require("core.input")
local StateManager = require("core.state_manager")
local GameInitializer = require("game.game_initializer")

local MenuState = {
    selectedOption = 1,
    options = {"New Game", "Load Game", "Quit"},
    lastInputTime = 0,
    inputCooldown = 0.25  -- 250ms between inputs
}

function MenuState.enter()
    -- Initialize menu
    MenuState.selectedOption = 1
    MenuState.lastInputTime = 0
end

function MenuState.exit()
    -- Cleanup menu
end

function MenuState.update(dt)
    MenuState.lastInputTime = MenuState.lastInputTime + dt
    
    -- Handle navigation input with cooldown to prevent rapid repeats
    local moveUp = Input.isKeyDown("up") or Input.isKeyDown("w")
    local moveDown = Input.isKeyDown("down") or Input.isKeyDown("s")
    
    if (moveUp or moveDown) and MenuState.lastInputTime >= MenuState.inputCooldown then
        if moveUp then
            MenuState.selectedOption = MenuState.selectedOption - 1
            if MenuState.selectedOption < 1 then
                MenuState.selectedOption = #MenuState.options
            end
        end
        if moveDown then
            MenuState.selectedOption = MenuState.selectedOption + 1
            if MenuState.selectedOption > #MenuState.options then
                MenuState.selectedOption = 1
            end
        end
        MenuState.lastInputTime = 0  -- Reset cooldown
    end
    
    -- Handle selection input
    local selectOption = Input.isKeyDown("return") or Input.isKeyDown("space")
    local newGame = Input.isKeyDown("n")
    local loadGame = Input.isKeyDown("l")
    local quit = Input.isKeyDown("q") or Input.isKeyDown("escape")
    
    if selectOption then
        MenuState._selectOption(MenuState.selectedOption)
    elseif newGame then
        MenuState._selectOption(1)
    elseif loadGame then
        MenuState._selectOption(2)
    elseif quit then
        MenuState._selectOption(3)
    end
end

function MenuState._selectOption(optionIndex)
    if optionIndex == 1 then
        -- New Game
        GameInitializer.initNewGame({
            playerName = "Wanderer",
            difficulty = "normal"
        })
        StateManager.swap("world")
    elseif optionIndex == 2 then
        -- Load Game (not yet implemented)
        print("Load Game not yet implemented")
    elseif optionIndex == 3 then
        -- Quit
        love.event.quit()
    end
end

function MenuState.draw()
    love.graphics.clear(0.05, 0.05, 0.05)
    
    -- Draw title
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.setFont(love.graphics.newFont(48))
    love.graphics.printf("REALM OF GEHERRA", 0, 100, 1024, "center")
    
    -- Draw menu options
    love.graphics.setFont(love.graphics.newFont(32))
    local startY = 300
    local spacing = 80
    
    for i, option in ipairs(MenuState.options) do
        if i == MenuState.selectedOption then
            love.graphics.setColor(1, 1, 0.2)  -- Yellow for selected
            love.graphics.printf("> " .. option .. " <", 0, startY + (i - 1) * spacing, 1024, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7)  -- Gray for unselected
            love.graphics.printf(option, 0, startY + (i - 1) * spacing, 1024, "center")
        end
    end
    
    -- Draw hints
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Use ↑↓ or WASD to navigate, ENTER or SPACE to select", 0, 650, 1024, "center")
    love.graphics.printf("Or press: [N] New Game, [L] Load, [Q] Quit", 0, 680, 1024, "center")
end

return MenuState
