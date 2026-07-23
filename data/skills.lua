-- data/skills.lua
-- Skill definitions

return {
    ["attack"] = {
        id = "attack",
        name = "Attack",
        type = "melee",
        description = "Basic melee attack",
        damageType = "slashing",
        baseDamage = 5,
        windup = 30,
        cooldown = 10,
        cost = 0,
        range = 0.3,
    },

    
    ["bite"] = {
        id = "bite",
        name = "Bite",
        type = "melee",
        description = "Basic melee attack",
        damageType = "piercing",
        baseDamage = 5,
        windup = 10,
        cooldown = 15,
        cost = 0,
        range = 0.2,
    },

    ["dagger"] = {
        id = "dagger",
        name = "Dagger",
        type = "melee",
        description = "Fast close-range stab",
        damageType = "piercing",
        baseDamage = 6,
        windup = 0,
        cooldown = 40,
        cost = 0,
        range = 0.2,
    },

    ["fireball"] = {
        id = "fireball",
        name = "Fireball",
        type = "aoe",
        description = "Launch a fireball at a target cell",
        damageType = "fire",
        baseDamage = 15,
        targeted = true,
        aoe = 1,
        range = 8.0,
        windup = 40,
        cooldown = 60,
        cost = 30,
        onHitStatuses = { "burn" },
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
        damageType = "blunt",
        baseDamage = 4,
        windup = 16,
        cooldown = 40,
        cost = 0,
        onHitStatuses = { "stun" }
    },

    ["javelin_throw"] = {
        id = "javelin_throw",
        name = "Javelin Throw",
        type = "ranged",
        description = "Throw a javelin (Limited uses)",
        damageType = "piercing",
        baseDamage = 17,
        range = 8.5,
        windup = 20,
        cooldown = 30,
        maxCharges = 2, -- Only usable 2 times per battle
        projectile = {
            sprite = "assets/sprites/projectiles/spear.png",
            speed = 32,
            arc = 30
        }
    },

    ["javelin_throw_single"] = {
        id = "javelin_throw_single",
        name = "Single Javelin Throw",
        type = "ranged",
        description = "Throw one javelin with limited battle supply",
        damageType = "piercing",
        baseDamage = 16,
        range = 8.5,
        windup = 20,
        cooldown = 30,
        maxCharges = 1,
        projectile = {
            sprite = "assets/sprites/projectiles/spear.png",
            speed = 32,
            arc = 30
        }
    }
}
