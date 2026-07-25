return {
    ["elder_greeting"] = {
        id = "elder_greeting",
        checkQuest = "hunt_dogs",
        states = {
            active = "elder_quest_active",
            ready_to_turn_in = "elder_quest_ready_to_turn_in",
            completed = "elder_quest_completed"
        },
        lines = {
            {
                text = "Welcome, traveler. I may have work, if you are willing.",
                options = {
                    { text = "What do you need?", next = "elder_request", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "I am not interested.", next = "end" }
                }
            }
        }
    },

    ["elder_request"] = {
        id = "elder_request",
        speaker = "Village Elder",
        lines = {
            {
                text = "A pack of wild dogs has been attacking our livestock. Drive them off, and the village will reward you.",
                options = {
                    { text = "I will handle it.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "Not my concern.", next = "end" }
                }
            }
        }
    },

    ["elder_quest_accepted"] = {
        id = "elder_quest_accepted",
        speaker = "Village Elder",
        lines = {
            {
                text = "Thank you. They were last seen in the woods to the east.",
                options = {
                    { text = "I will return when it is done.", next = "end" }
                }
            }
        }
    },

    ["elder_quest_active"] = {
        id = "elder_quest_active",
        speaker = "Village Elder",
        lines = {
            {
                text = "Have you driven off those dogs yet? The village is not safe while they remain.",
                options = {
                    { text = "I am still on the hunt.", next = "end" }
                }
            }
        }
    },

    ["elder_quest_ready_to_turn_in"] = {
        id = "elder_quest_ready_to_turn_in",
        speaker = "Village Elder",
        lines = {
            {
                text = "Have you dealt with the wild dogs?",
                options = {
                    { text = "Yes. The pack is gone.", action = "turn_in_available_quest", next = "elder_quest_completed", requiresQuestPool = true, requiresReadyToTurnIn = true },
                    { text = "Not yet.", next = "end" }
                }
            }
        }
    },

    ["elder_quest_completed"] = {
        id = "elder_quest_completed",
        speaker = "Village Elder",
        lines = {
            {
                text = "The village is safe again. You have our thanks.",
                options = {
                    { text = "Glad I could help.", next = "end" }
                }
            }
        }
    },

    -- Pilgrimage quest dialogue
    ["elder_pilgrimage_offer"] = {
        id = "elder_pilgrimage_offer",
        speaker = "Village Elder",
        lines = {
            {
                text = "The sacred offerings must be carried to a nearby shrine. Our legs are old, and the roads are not safe. Would you undertake this pilgrimage for the village?",
                options = {
                    { text = "I will carry the offerings.", action = "accept_available_quest", next = "elder_pilgrimage_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "I cannot take this on now.", next = "end" }
                }
            }
        }
    },

    ["elder_pilgrimage_accepted"] = {
        id = "elder_pilgrimage_accepted",
        speaker = "Village Elder",
        lines = {
            {
                text = "The gods will know your name for this. Carry the offerings with reverence, and return to me once you have reached the shrine.",
                options = {
                    { text = "It will be done.", next = "end" }
                }
            }
        }
    },

    ["elder_pilgrimage_active"] = {
        id = "elder_pilgrimage_active",
        speaker = "Village Elder",
        lines = {
            {
                text = "The offerings have not yet been delivered. The shrine awaits.",
                options = {
                    { text = "I am on my way.", next = "end" }
                }
            }
        }
    },

    ["elder_pilgrimage_ready_to_turn_in"] = {
        id = "elder_pilgrimage_ready_to_turn_in",
        speaker = "Village Elder",
        lines = {
            {
                text = "You have returned. Did you reach the shrine?",
                options = {
                    { text = "The offerings have been delivered.", action = "turn_in_available_quest", next = "elder_pilgrimage_completed", requiresQuestPool = true, requiresReadyToTurnIn = true },
                    { text = "Not yet.", next = "end" }
                }
            }
        }
    },

    ["elder_pilgrimage_completed"] = {
        id = "elder_pilgrimage_completed",
        speaker = "Village Elder",
        lines = {
            {
                text = "You have our deepest gratitude. The ancestors are honored.",
                options = {
                    { text = "It was the right thing to do.", next = "end" }
                }
            }
        }
    },

    ["village_recruit"] = {
        id = "village_recruit",
        speaker = "Village Elder",
        lines = {
            {
                text = "A few able-bodied villagers look eager to join a new cause.",
                options = {
                    { text = "Recruit them (10 favor).", action = "recruit_volunteers" },
                    { text = "Leave them be.", next = "end" }
                }
            }
        }
    }
}
