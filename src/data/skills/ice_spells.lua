-- Ice spell definitions.

return {
    ["frostbolt"] = {
        id = "frostbolt",
        name = "Frostbolt",
        type = "ranged",
        description = "Hurl a shard of ice that chills the target",
        damageType = "ice",
        baseDamage = 12,
        range = 7.0,
        windup = 30,
        cooldown = 45,
        cost = 20,
        onHitStatuses = {
            "freeze",
        },
        projectile = {
            style = "frostbolt",
            speed = 26,
            arc = 0,
        },
    },
}
