return {
    ["trader_greeting"] = {
        id = "trader_greeting",
        speaker = "Trader",
        lines = {
            {
                text = "Good coin to you, traveler. I may have a contract if you are available.",
                options = {
                    { text = "Show me your contract.", action = "accept_available_quest", next = "end", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "I completed your contract.", action = "turn_in_available_quest", next = "end", requiresQuestPool = true, requiresReadyToTurnIn = true },
                    { text = "Maybe later.", next = "end" }
                }
            }
        }
    }
}
