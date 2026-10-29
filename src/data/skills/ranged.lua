-- Ranged skill definitions.

return {
    ["arrow"] = {
        id = "arrow",
        name = "Arrow",
        type = "ranged",
        damageType = "piercing",
        baseDamage = 10,
        range = 14,
        windup = 40,
        cooldown = 10,
        projectile = { style = "arrow", speed = 40, arc = 25, radius = 1 },
    },

    ["javelin_throw"] = {
        id = "javelin_throw",
        name = "Javelin Throw",
        type = "ranged",
        description = "Throw a javelin (Limited uses)",
        damageType = "piercing",
        baseDamage = 15,
        range = 7.5,
        windup = 20,
        cooldown = 30,
        maxCharges = 2,
        -- Only usable 2 times per battle
        projectile = {
            sprite = "src/assets/sprites/projectiles/spear.png",
            speed = 32,
            arc = 30,
        },
    },

    ["javelin_throw_single"] = {
        id = "javelin_throw_single",
        name = "Single Javelin Throw",
        type = "ranged",
        description = "Throw one javelin with limited battle supply",
        damageType = "piercing",
        baseDamage = 15,
        range = 7.5,
        windup = 20,
        cooldown = 30,
        maxCharges = 1,
        projectile = {
            sprite = "src/assets/sprites/projectiles/spear.png",
            speed = 32,
            arc = 30,
        },
    },

    ["sling_stone"] = {
        id = "sling_stone",
        name = "Sling Stone",
        type = "ranged",
        description = "Hurl a stone with a sling",
        damageType = "blunt",
        baseDamage = 9,
        range = 12.0,
        windup = 30,
        cooldown = 10,
        projectile = {
            style = "sling_stone",
            speed = 36,
            arc = 40,
        },
    },
}
