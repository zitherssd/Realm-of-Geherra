-- Combines skill definitions grouped under data/skills/.

local Registry = require("src.data.definition_registry")
local categories = {
    require("src.data.skills.commands"),
    require("src.data.skills.melee"),
    require("src.data.skills.ranged"),
    require("src.data.skills.fire_spells"),
    require("src.data.skills.ice_spells"),
    require("src.data.skills.lightning_spells"),
    require("src.data.skills.healing_spells"),
    require("src.data.skills.earth_spells"),
}

local skills = {}
for _, category in ipairs(categories) do
    for id, skill in pairs(category) do
        Registry.checkId("skill", id, skill)
        if skills[id] then
            error("Duplicate skill definition: " .. id)
        end
        skills[id] = skill
    end
end

return skills
