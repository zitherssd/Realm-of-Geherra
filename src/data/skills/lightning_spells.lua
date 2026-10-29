-- Lightning spell definitions.

return {
    ["lightning"] = {
        id = "lightning",
        name = "Lightning",
        type = "ranged",
        description = "Strike a foe with a bolt of lightning, paralyzing it",
        damageType = "shock",
        baseDamage = 14,
        range = 6.0,
        windup = 20,
        cooldown = 50,
        cost = 25,
        onHitStatuses = {
            "paralyze",
        },
        projectile = {
            style = "lightning",
            speed = 36,
            arc = 0,
        },
    },
}
