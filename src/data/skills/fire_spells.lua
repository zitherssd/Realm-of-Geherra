-- Fire spell definitions.

return {
    ["fireball"] = {
        id = "fireball",
        name = "Fireball",
        type = "aoe",
        description = "Launch a fireball at a battlefield position",
        damageType = "fire",
        baseDamage = 15,
        targeted = true,
        aoe = { shape = "circle", radius = 33.6, eligibility = "all" },
        range = 8.0,
        windup = 40,
        cooldown = 60,
        cost = 30,
        onHitStatuses = {
            "burn",
        },
        projectile = {
            speed = 24,
            arc = 35,
            style = "fireball",
            defenseMode = "none",
        },
    },

    ["flame_breath"] = {
        id = "flame_breath",
        name = "Flame Breath",
        type = "aoe",
        description = "Breathe fire in a cone in front of you",
        damageType = "fire",
        baseDamage = 13,
        aoe = { shape = "cone", angle = math.rad(60), length = 210, eligibility = "all" },
        range = 5.0,
        windup = 90,
        recovery = 80,
        cooldown = 150,
        cost = 25,
        onHitStatuses = {
            "burn",
        },
    },
}
