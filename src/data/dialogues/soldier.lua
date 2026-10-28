return {
    ["soldier_greeting"] = {
        id = "soldier_greeting",
        speaker = "Soldier",
        checkQuest = "hunt_dogs",
        states = {
            active = "soldier_quest_active",
            ready_to_turn_in = "soldier_quest_ready_to_turn_in",
            completed = "soldier_quest_completed",
        },
        lines = {
            {
                text = "The roads bite hard. If you can hold a line, I have patrol work.",
                options = {
                    {
                        text = "Set the patrol terms.",
                        action = "accept_available_quest",
                        next = "end",
                        requiresQuestPool = true,
                        requiresQuestOffer = true,
                    },
                    {
                        text = "Stand fast.",
                        next = "end",
                    },
                },
            },
        },
    },

    ["soldier_quest_active"] = {
        id = "soldier_quest_active",
        speaker = "Soldier",
        lines = {
            {
                text = "Patrols do not walk themselves. What progress?",
                options = {
                    {
                        text = "Still at work.",
                        next = "end",
                    },
                },
            },
        },
    },

    ["soldier_quest_ready_to_turn_in"] = {
        id = "soldier_quest_ready_to_turn_in",
        speaker = "Soldier",
        lines = {
            {
                text = "You return. Is the patrol assignment complete?",
                options = {
                    {
                        text = "The job is done.",
                        action = "turn_in_available_quest",
                        next = "soldier_quest_completed",
                        requiresQuestPool = true,
                        requiresReadyToTurnIn = true,
                    },
                    {
                        text = "Not yet.",
                        next = "end",
                    },
                },
            },
        },
    },

    ["soldier_quest_completed"] = {
        id = "soldier_quest_completed",
        speaker = "Soldier",
        lines = {
            {
                text = "Good work. The road is steadier for your labor.",
                options = {
                    {
                        text = "Keep the watchfires lit.",
                        next = "end",
                    },
                },
            },
        },
    },
}
