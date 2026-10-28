-- data/recruitment.lua
-- Pools are keyed by canonical faction ID, then the location's recruitmentPool.
-- Known factions without authored pools use neutral pools, independently of culture.

return {
    -- The Menari (Common Stock)
    ["menari"] = {
        ["village"] = {"soldier"},
        ["town"]    = {"soldier", "knight"},
        ["castle"]  = {"knight"},
        ["default"] = {"soldier"}
    },

    -- The Dacians (Rivals)
    ["dacians"] = {
        ["village"] = {"soldier"},
        ["town"]    = {"soldier", "knight"},
        ["castle"]  = {"knight"},
        ["default"] = {"soldier"}
    },

    -- Fallback for locations with no faction (Neutral)
    ["neutral"] = {
        ["village"] = {"soldier"}, 
        ["town"]    = {"soldier"},
        ["castle"]  = {"knight"},
        ["default"] = {"soldier"}
    },

    -- The Hyperboreans (Elite/Mythic)
    ["hyperboreans"] = {
        ["village"] = {"soldier"},
        ["town"]    = {"knight"},
        ["castle"]  = {"knight"},
        ["default"] = {"knight"}
    },

    -- The Pelasgian Clan (Tribal)
    ["pelasgian_clan"] = {
        ["village"] = {"pelas_youth", "pelas_tribesman"},
        ["town"]    = {"pelas_tribesman", "pelas_skirmisher"},
        ["castle"]  = {"pelas_skirmisher"},
        ["default"] = {"pelas_youth"}
    }
}
