return {
    ["tavern_keeper_greeting"] = {
        id = "tavern_keeper_greeting",
        speaker = "Tavern Keeper",
        showGold = true,
        lines = {
            {
                text = "Welcome to the tavern! A warm bed is 20 gold for the night, and a mug of ale is 5.",
                options = {
                    { text = "Pay 20 gold and rest.", action = "pay_for_rest", cost = 20 },
                    { text = "Buy a mug of ale — 5 gold.", action = "buy_drink", cost = 5 },
                    { text = "Heard any news?", next = "tavern_keeper_rumors" },
                    { text = "Maybe later.", next = "end" }
                }
            }
        }
    },

    ["tavern_keeper_rumors"] = {
        id = "tavern_keeper_rumors",
        speaker = "Tavern Keeper",
        lines = {
            {
                text = "Word travels slow these days, but I heard the old roads are getting more dangerous. Folk say there's movement in the hills — bandits, maybe worse. Keep your wits about you out there.",
                options = {
                    { text = "Good to know. Thanks.", next = "tavern_keeper_greeting" }
                }
            }
        }
    }
}
