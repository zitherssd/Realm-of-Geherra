-- Melee skill definitions.

return {
    ["attack"] = {
        id = "attack",
        name = "Attack",
        type = "melee",
        description = "Basic melee attack",
        damageType = "slashing",
        baseDamage = 3,
        windup = 30,
        recovery = 5,
        cooldown = 30,
        cost = 0,
        range = 0.2,
    },

    ["bite"] = {
        id = "bite",
        name = "Bite",
        type = "melee",
        description = "Basic melee attack",
        damageType = "piercing",
        baseDamage = 4,
        windup = 15,
        cooldown = 15,
        cost = 0,
        range = 0.18,
    },

    -- This can be accomplished purely via skill modifiers
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
        range = 0.15,
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
        onHitStatuses = {
            "stun",
        },
    },
}
