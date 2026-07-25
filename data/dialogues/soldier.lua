return {
    ["soldier_greeting"] = {
        id = "soldier_greeting",
        speaker = "Soldier",
        lines = {
            {
                text = "The roads are dangerous. If you can fight, I might have patrol work for you.",
                options = {
                    { text = "Any patrol contracts available?", action = "accept_available_quest", next = "end", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "I finished that patrol assignment.", action = "turn_in_available_quest", next = "end", requiresQuestPool = true, requiresReadyToTurnIn = true },
                    { text = "Stay vigilant.", next = "end" }
                }
            }
        }
    }
}
