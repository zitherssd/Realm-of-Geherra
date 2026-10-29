-- Command skill definitions.

return {
    ["on_me"] = {
        id = "on_me",
        name = "On Me!",
        type = "command",
        order = "hold",
        windup = 0,
        recovery = 5,
        cooldown = 60,
    },

    ["charge"] = {
        id = "charge",
        name = "Charge!",
        type = "command",
        order = "charge",
        windup = 0,
        recovery = 5,
        cooldown = 60,
    },
}
