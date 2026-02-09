-- systems/progression_system.lua
-- Handle leveling, experience, and character growth

local ProgressionSystem = {}

function ProgressionSystem.addExperience(actor, amount)
    if not actor.experience then
        actor.experience = 0
    end
    actor.experience = actor.experience + amount
    
    -- Check for level up
    local nextLevelExp = ProgressionSystem.getExperienceForLevel(actor.level + 1)
    if actor.experience >= nextLevelExp then
        ProgressionSystem.levelUp(actor)
    end
end

function ProgressionSystem.levelUp(actor)
    actor.level = (actor.level or 1) + 1
    -- Increase stats
    if actor.stats then
        actor.stats.health = (actor.stats.health or 100) + 10
        actor.stats.strength = (actor.stats.strength or 10) + 1
    end
end

function ProgressionSystem.getExperienceForLevel(level)
    return level * 100
end

function ProgressionSystem.getCurrentLevel(actor)
    return actor.level or 1
end

return ProgressionSystem
