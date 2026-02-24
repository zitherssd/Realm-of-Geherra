-- data/dialogue.lua
-- Dialogue tree definitions

return {
    ["elder_greeting"] = {
        id = "elder_greeting",
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
    }
}
