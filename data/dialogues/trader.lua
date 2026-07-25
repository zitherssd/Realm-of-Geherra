return {
    ["trader_greeting"] = {
        id = "trader_greeting",
        speaker = "Trader",
        checkQuest = "hunt_dogs",
        states = {
            active = "trader_quest_active",
            ready_to_turn_in = "trader_quest_ready_to_turn_in",
            completed = "trader_quest_completed"
        },
        lines = {
            {
                text = "Good coin to you, traveler. I may have a contract if you are available.",
                options = {
                    { text = "Show me your contract.", action = "accept_available_quest", next = "end", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "Maybe later.", next = "end" }
                }
            }
        }
    },

    ["trader_quest_active"] = {
        id = "trader_quest_active",
        speaker = "Trader",
        lines = {
            {
                text = "I trust you're making progress on that contract?",
                options = {
                    { text = "Working on it.", next = "end" }
                }
            }
        }
    },

    ["trader_quest_ready_to_turn_in"] = {
        id = "trader_quest_ready_to_turn_in",
        speaker = "Trader",
        lines = {
            {
                text = "Have you completed the contract? My goods are waiting.",
                options = {
                    { text = "Delivered and done.", action = "turn_in_available_quest", next = "trader_quest_completed", requiresQuestPool = true, requiresReadyToTurnIn = true },
                    { text = "Almost there.", next = "end" }
                }
            }
        }
    },

    ["trader_quest_completed"] = {
        id = "trader_quest_completed",
        speaker = "Trader",
        lines = {
            {
                text = "Business well handled. I'll remember your name.",
                options = {
                    { text = "Pleasure doing business.", next = "end" }
                }
            }
        }
    }
}
