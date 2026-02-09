-- ui/screens/party_screen.lua
-- Party management screen

local PartyScreen = {}

function PartyScreen.show()
    -- Initialize party screen
end

function PartyScreen.hide()
    -- Cleanup
end

function PartyScreen.update(dt)
    -- Update party screen
end

function PartyScreen.draw()
    love.graphics.clear(0.1, 0.1, 0.1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Party", 20, 20)
    love.graphics.print("[ESC] Close", 20, height - 40)
end

return PartyScreen
