-- Earth spell definitions.

return {
    ["mass_stoneskin"] = {
        id = "mass_stoneskin",
        name = "Mass Stoneskin",
        type = "aoe",
        description = "Turn nearby allies' skin to stone",
        aoe = {
            shape = "circle",
            radius = 60,
            eligibility = "allies",
        },

    range = 2.0,
    windup = 80,
    cooldown = 60,
    cost = 30,

    onHitStatuses = {
        "stoneskin",
    },
},
}
