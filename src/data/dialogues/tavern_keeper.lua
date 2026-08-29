return {
    ["tavern_keeper_greeting"] = {
        id = "tavern_keeper_greeting",
        speaker = "Tavern Keeper",
        showGold = true,
        lines = {
            {
                text = "Welcome to my hearth. A bed for the night is 20 gold; an ale is 5.",
                options = {
                    { text = "Pay 20 gold and take rest.", action = "pay_for_rest", cost = 20 },
                    { text = "Buy one ale for 5 gold.", action = "buy_drink", cost = 5 },
                    { text = "What news walks the roads?", next = "tavern_keeper_rumors" },
                    { text = "Not now.", next = "end" }
                }
            }
        }
    },

    ["tavern_keeper_rumors"] = {
        id = "tavern_keeper_rumors",
        speaker = "Tavern Keeper",
        lines = {
            {
                text = "Word comes slow, but it comes. The old roads are turning cruel: movement in the hills, raiders perhaps, perhaps worse. Keep measure in your steps beyond the gate.",
                options = {
                    { text = "You have my thanks.", next = "tavern_keeper_greeting" }
                }
            }
        }
    }
}
