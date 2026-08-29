return {
    ["npc_greeting"] = {
        id = "npc_greeting",
        speaker = "Local",
        lines = {
            {
                text = "No task waits for you now.",
                options = {
                    { text = "I understand.", next = "end" }
                }
            }
        }
    },

    ["captain_mission"] = {
        id = "captain_mission",
        lines = {
            {
                text = "Raiders have taken our roads. Will you break them?",
                options = {
                    { text = "I will do it.", next = "quest_accepted" },
                    { text = "I will not take this burden.", next = "end" }
                }
            }
        }
    },

    ["bandit_start"] = {
        id = "bandit_start",
        lines = {
            {
                text = "A stray lamb on an empty road. Lay down your coin, or feed the dust with blood.",
                options = {
                    { text = "I yield nothing to raiders. (Fight)", action = "battle" },
                    { text = "Keep your road. I withdraw. (Leave)", next = "end" }
                }
            }
        }
    },

    ["encounter_ambush"] = {
        id = "encounter_ambush",
        lines = {
            {
                text = "The wild closes around you; armed foes bar the way.",
                options = {
                    { text = "Stand and answer steel with steel. (Fight)", action = "battle" },
                    { text = "Break away and live. (Leave)", next = "end" }
                }
            }
        }
    }
}
