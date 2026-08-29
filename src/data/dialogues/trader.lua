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
                text = "Fair measure to you, traveler. I hold a contract, if your hands are free.",
                options = {
                    { text = "Speak the contract.", action = "accept_available_quest", next = "end", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "Another hour, perhaps.", next = "end" }
                }
            }
        }
    },

    ["trader_quest_active"] = {
        id = "trader_quest_active",
        speaker = "Trader",
        lines = {
            {
                text = "Does that contract move, or stand still?",
                options = {
                    { text = "It is in motion.", next = "end" }
                }
            }
        }
    },

    ["trader_quest_ready_to_turn_in"] = {
        id = "trader_quest_ready_to_turn_in",
        speaker = "Trader",
        lines = {
            {
                text = "Is the contract complete? My goods wait on your word.",
                options = {
                    { text = "Delivered and complete.", action = "turn_in_available_quest", next = "trader_quest_completed", requiresQuestPool = true, requiresReadyToTurnIn = true },
                    { text = "Not yet.", next = "end" }
                }
            }
        }
    },

    ["trader_quest_completed"] = {
        id = "trader_quest_completed",
        speaker = "Trader",
        lines = {
            {
                text = "Well weighed and well done. Your name holds value with me.",
                options = {
                    { text = "May our bargains stay honest.", next = "end" }
                }
            }
        }
    }
}
