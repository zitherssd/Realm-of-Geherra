-- data/recruitment.lua
-- Defines which units are available for recruitment based on Faction and Location Type

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

    -- The Pelasgians (Tribal)
    ["pelasgians"] = {
        ["village"] = {"pelas_youth", "pelas_tribesman"},
        ["town"]    = {"pelas_tribesman", "pelas_skirmisher"},
        ["castle"]  = {"pelas_skirmisher"},
        ["default"] = {"pelas_youth"}
    }
}