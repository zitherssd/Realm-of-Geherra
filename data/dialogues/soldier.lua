return {
    ["soldier_greeting"] = {
        id = "soldier_greeting",
        speaker = "Soldier",
        checkQuest = "hunt_dogs",
        states = {
            active = "soldier_quest_active",
            ready_to_turn_in = "soldier_quest_ready_to_turn_in",
            completed = "soldier_quest_completed"
        },
        lines = {
            {
                text = "The roads are dangerous. If you can fight, I might have patrol work for you.",
                options = {
                    { text = "Any patrol contracts available?", action = "accept_available_quest", next = "end", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "Stay vigilant.", next = "end" }
                }
            }
        }
    },

    ["soldier_quest_active"] = {
        id = "soldier_quest_active",
        speaker = "Soldier",
        lines = {
            {
                text = "Those patrols won't complete themselves. Any progress?",
                options = {
                    { text = "I'm still working on it.", next = "end" }
                }
            }
        }
    },

    ["soldier_quest_ready_to_turn_in"] = {
        id = "soldier_quest_ready_to_turn_in",
        speaker = "Soldier",
        lines = {
            {
                text = "You're back. Did you finish the patrol assignment?",
                options = {
                    { text = "The job is done.", action = "turn_in_available_quest", next = "soldier_quest_completed", requiresQuestPool = true, requiresReadyToTurnIn = true },
                    { text = "Not yet.", next = "end" }
                }
            }
        }
    },

    ["soldier_quest_completed"] = {
        id = "soldier_quest_completed",
        speaker = "Soldier",
        lines = {
            {
                text = "Good work. The roads will be safer because of you.",
                options = {
                    { text = "Glad I could help.", next = "end" }
                }
            }
        }
    }
}
