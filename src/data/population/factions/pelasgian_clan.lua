local Definition = require("src.data.types.faction")
-- Example authored faction: its trained garrison differs from the culture default.
return Definition.new {
    id = "pelasgian_clan", defaultCulture = "pelasgian",
    garrisonRoles = {fort_guard = "pelasgian_veteran"},
    residentOverrides = {fort = {healer = {chance = 1}}},
}
