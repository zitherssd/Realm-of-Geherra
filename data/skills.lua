-- data/skills.lua
-- Skill definitions

return {
    ["slash"] = {
        id = "slash",
        name = "Slash",
        type = "melee",
        description = "Basic melee attack",
        damageMultiplier = 1.0,
        windup = 40,
        cooldown = 10,
        cost = 0,
        range = 1.5,
    },
    
    ["bite"] = {
        id = "bite",
        name = "Bite",
        type = "melee",
        description = "Basic melee attack",
        damageMultiplier = 1.0,
        windup = 15,
        cooldown = 22,
        cost = 0,
        range = 1.5,
    },

    ["dagger"] = {
        id = "dagger",
        name = "Dagger",
        type = "melee",
        description = "Fast close-range stab",
        damageMultiplier = 1.0,
        windup = 0,
        cooldown = 40,
        cost = 0,
        range = 1.5,
    },

    ["fireball"] = {
        id = "fireball",
        name = "Fireball",
        type = "aoe",
        description = "Launch a fireball at a target cell",
        damageMultiplier = 1.5,
        targeted = true,
        aoe = 1,
        range = 8.0,
        windup = 40,
        cooldown = 60,
        cost = 30,
        onHitStatuses = {
            burn = {
                duration = 120,
                damagePerTick = 1,
                tickEvery = 20
            }
        },
        projectile = {
            speed = 24,
            arc = 0,
            style = "fireball"
        }
    },
    
    ["heal"] = {
        id = "heal",
        name = "Heal",
        type = "spell",
        description = "Restore health",
        healing = 50,
        windup = 60,
        cooldown = 60,
        cost = 20
    },
    
    ["shield_bash"] = {
        id = "shield_bash",
        name = "Shield Bash",
        type = "melee",
        description = "Bash with shield, stun enemy",
        damageMultiplier = 0.8,
        stun = true,
        cooldown = 40,
        cost = 0
    },

    ["javelin_throw"] = {
        id = "javelin_throw",
        name = "Javelin Throw",
        type = "ranged",
        description = "Throw a javelin (Limited uses)",
        damageMultiplier = 2.0,
        range = 8.5,
        windup = 30,
        cooldown = 35,
        maxCharges = 2, -- Only usable 2 times per battle
        projectile = {
            sprite = "assets/sprites/projectiles/spear.png",
            speed = 32,
            arc = 30
        }
    }
}
