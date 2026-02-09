-- ui/screens/quest_log_screen.lua
-- Quest log and objectives screen

local QuestLogScreen = {}

function QuestLogScreen.show()
    -- Initialize quest log
end

function QuestLogScreen.hide()
    -- Cleanup
end

function QuestLogScreen.update(dt)
    -- Update quest log
end

function QuestLogScreen.draw()
    love.graphics.clear(0.1, 0.1, 0.1)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Quest Log", 20, 20)
    love.graphics.print("[ESC] Close", 20, height - 40)
end

return QuestLogScreen
