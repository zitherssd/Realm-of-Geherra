-- ui/screens/character_screen.lua
-- Character stats and details screen

local CharacterScreen = {}

function CharacterScreen.show()
    -- Initialize character screen
end

function CharacterScreen.hide()
    -- Cleanup
end

function CharacterScreen.update(dt)
    -- Update character screen
end

function CharacterScreen.draw()
    love.graphics.clear(0.1, 0.1, 0.1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Character", 20, 20)
    love.graphics.print("[ESC] Close", 20, height - 40)
end

return CharacterScreen
