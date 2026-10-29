-- Earth spell definitions.

return {
    ["mass_stoneskin"] = {
        id = "mass_stoneskin",
        name = "Mass Stoneskin",
        type = "aoe",
        description = "Turn nearby allies' skin to stone",
        aoe = {
            shape = "circle",
            radius = 350,
            eligibility = "allies",
        },

    range = 5.0,
    windup = 10,
    recovery = 10,
    cooldown = 10,
    
    cost = 30,

    onHitStatuses = {
        "stoneskin",
    },
},
}
