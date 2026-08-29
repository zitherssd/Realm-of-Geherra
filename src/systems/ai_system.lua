-- systems/ai_system.lua
-- Handle NPC and troop AI behavior

local AISystem = {}

function AISystem.updateAI(actor, dt)
    if not actor.ai or not actor.ai.state then return end
    
    local aiState = actor.ai.state
    
    if aiState == "idle" then
        -- Idle behavior
    elseif aiState == "patrol" then
        -- Patrol behavior
    elseif aiState == "combat" then
        -- Combat AI
    elseif aiState == "flee" then
        -- Flee behavior
    end
end

function AISystem.setAIState(actor, state)
    if not actor.ai then
        actor.ai = {}
    end
    actor.ai.state = state
end

return AISystem
