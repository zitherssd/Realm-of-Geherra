-- data/progression.lua
-- Character progression and leveling

return {
    experienceTable = {
        100,    -- Level 1 -> 2
        200,    -- Level 2 -> 3
        300,    -- Level 3 -> 4
        450,    -- Level 4 -> 5
        600,    -- Level 5 -> 6
    },
    
    levelUpBonuses = {
        health = 10,
        strength = 1,
        defense = 1,
        speed = 0.5
    },
    
    skillProgression = {
        ["slash"] = {
            unlockLevel = 1,
            scalingFactor = 0.5
        },
        ["fireball"] = {
            unlockLevel = 3,
            scalingFactor = 1.0
        }
    }
}
