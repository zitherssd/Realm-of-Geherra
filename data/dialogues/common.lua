return {
    ["npc_greeting"] = {
        id = "npc_greeting",
        speaker = "Local",
        lines = {
            {
                text = "No work for you right now.",
                options = {
                    { text = "Understood.", next = "end" }
                }
            }
        }
    },

    ["captain_mission"] = {
        id = "captain_mission",
        lines = {
            {
                text = "Bandits have been raiding our merchants. Will you stop them?",
                options = {
                    { text = "Consider it done.", next = "quest_accepted" },
                    { text = "Not my problem.", next = "end" }
                }
            }
        }
    },

    ["bandit_start"] = {
        id = "bandit_start",
        lines = {
            {
                text = "Well, well... looks like we caught ourselves a lost lamb. Hand over your coin or bleed!",
                options = {
                    { text = "I will never surrender to scum like you! (Fight)", action = "battle" },
                    { text = "I do not want any trouble... (Leave)", next = "end" }
                }
            }
        }
    }
}
