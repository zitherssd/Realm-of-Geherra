-- data/skills.lua
-- Skill definitions

return {
    ["slash"] = {
        id = "slash",
        name = "Slash",
        type = "melee",
        description = "Basic melee attack",
        damageMultiplier = 1.0,
        cooldown = 0.5,
        cost = 0
    },
    
    ["fireball"] = {
        id = "fireball",
        name = "Fireball",
        type = "spell",
        description = "Launch a fireball at the enemy",
        damageMultiplier = 1.5,
        area = true,
        cooldown = 2.0,
        cost = 30
    },
    
    ["heal"] = {
        id = "heal",
        name = "Heal",
        type = "spell",
        description = "Restore health",
        healing = 50,
        cooldown = 3.0,
        cost = 20
    },
    
    ["shield_bash"] = {
        id = "shield_bash",
        name = "Shield Bash",
        type = "melee",
        description = "Bash with shield, stun enemy",
        damageMultiplier = 0.8,
        stun = true,
        cooldown = 2.0,
        cost = 0
    }
}
