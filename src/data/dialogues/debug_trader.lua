-- data/dialogues/debug_trader.lua
-- Dialogue for the debug trader (sells every item in the game for testing)

return {
    ["debug_trader_greeting"] = {
        id = "debug_trader_greeting",
        speaker = "Merchant of Everything",
        lines = {
            {
                text = "Welcome, traveler. I carry near everything under the sun, and I pay fair coin for what leaves your hand.",
                options = {
                    -- "Show me your wares." is auto-injected by dialogue_state.lua
                    -- whenever this NPC has a non-empty inventory.
                    {
                        text = "Show me the world map (debug).",
                        action = "open_world_map",
                        next = "end",
                    },
                    {
                        text = "Another time.",
                        next = "end",
                    },
                },
            },
        },
    },
}
