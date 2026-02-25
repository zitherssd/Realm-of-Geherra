-- data/dialogue.lua
-- Dialogue tree definitions

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
                text = "Welcome, traveler. I have a task for you.",
                options = {
                    {text = "What do you need?", next = "elder_request"},
                    {text = "I'm not interested.", next = "end"}
                }
            }
        }
    },
    
    ["elder_request"] = {
        id = "elder_request",
        speaker = "Village Elder",
        lines = {
            {
                text = "A pack of wild dogs has been attacking our livestock. We need someone to drive them off.",
                options = {
                    {text = "I will handle it.", action = "accept_quest", questId = "hunt_dogs", next = "elder_quest_accepted"},
                    {text = "Not my problem.", next = "end"}
                }
            }
        }
    },

    ["elder_quest_accepted"] = {
        id = "elder_quest_accepted",
        speaker = "Village Elder",
        lines = {
            {
                text = "Thank you! They were last seen in the woods to the east.",
                options = {
                    {text = "I'll return when it is done.", next = "end"}
                }
            }
        }
    },

    ["elder_quest_active"] = {
        id = "elder_quest_active",
        speaker = "Village Elder",
        lines = {
            {
                text = "Have you driven off those dogs yet? The village is not safe until they are gone.",
                options = {
                    {text = "I am working on it.", next = "end"}
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
                    {text = "Yes. The pack is gone.", action = "turn_in_quest", questId = "hunt_dogs", next = "elder_quest_completed"},
                    {text = "Not yet.", next = "end"}
                }
            }
        }
    },

    ["elder_quest_completed"] = {
        id = "elder_quest_completed",
        speaker = "Village Elder",
        lines = {
            {
                text = "The village is safe again. We are in your debt, traveler.",
                options = {
                    {text = "Glad I could help.", next = "end"}
                }
            }
        }
    },

    ["captain_mission"] = {
        id = "captain_mission",
        lines = {
            {
                text = "Bandits have been raiding our merchants. Will you stop them?",
                options = {
                    {text = "Consider it done.", next = "quest_accepted"},
                    {text = "Not my problem.", next = "end"}
                }
            }
        }
    },

    ["bandit_start"] = {
        id = "bandit_start",
        lines = {
            {
                text = "Well, well... looks like we caught ourselves a lost lamb. Hand over your coin or bleed!",
                options = {
                    {text = "I'll never surrender to scum like you! (Fight)", action = "battle"},
                    {text = "I don't want any trouble... (Leave)", next = "end"} -- Placeholder for fleeing/paying
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
                    {text = "Recruit them (10 favor).", action = "recruit_volunteers"},
                    {text = "Leave them be.", next = "end"}
                }
            }
        }
    }
}
