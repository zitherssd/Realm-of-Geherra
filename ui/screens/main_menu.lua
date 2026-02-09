-- ui/screens/main_menu.lua
-- Main menu screen

local MainMenu = {}

function MainMenu.show()
    -- Initialize main menu
end

function MainMenu.hide()
    -- Cleanup menu
end

function MainMenu.update(dt)
    -- Update menu
end

function MainMenu.draw()
    love.graphics.clear(0.05, 0.05, 0.05)
    love.graphics.setColor(1, 1, 1)
    
    love.graphics.printf("REALM OF GEHERRA", 0, 200, 1024, "center")
    
    love.graphics.printf("[N] New Game", 0, 350, 1024, "center")
    love.graphics.printf("[L] Load Game", 0, 380, 1024, "center")
    love.graphics.printf("[Q] Quit", 0, 410, 1024, "center")
end

return MainMenu
