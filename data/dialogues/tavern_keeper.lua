return {
    ["tavern_keeper_greeting"] = {
        id = "tavern_keeper_greeting",
        speaker = "Tavern Keeper",
        showGold = true,
        lines = {
            {
                text = "Welcome to the tavern. A warm bed is 20 gold for the night.",
                options = {
                    { text = "Pay 20 gold and rest.", action = "pay_for_rest", cost = 20 },
                    { text = "Maybe later.", next = "end" }
                }
            }
        }
    }
}
