-- systems/recruitment_system.lua
-- Handles logic for recruiting units based on location and faction

local RecruitmentSystem = {}

local RecruitmentData = require("src.data.recruitment")
local Troop = require("src.entities.troop")
local PartySystem = require("src.systems.party_system")

function RecruitmentSystem.roll(location)
    -- Determine faction and location type to select the correct pool
    local faction = location.faction or "neutral"
    local locType = location.type or "default"

    -- Lookup recruitment pool from data/recruitment.lua
    local factionData = RecruitmentData[faction] or RecruitmentData["neutral"]
    local pool = factionData[locType] or factionData["default"] or {"soldier"}

    local roll = math.random()
    local count = 0
    local text = ""

    -- Determine success and count
    if roll < 0.4 then
        count = 0
        text = "You boast and try to impress the villagers, but they seem uninterested in your tales."
    elseif roll < 0.9 then
        count = 2
        text = "You boast and try to impress. Your words strike a chord! 2 volunteers step forward."
    else
        count = 3
        text = "You boast and try to impress. The crowd cheers! 3 eager volunteers pledge their swords."
    end

    -- Pick the units that would join (not added to the party until hired)
    local unitTypes = {}
    for i = 1, count do
        unitTypes[i] = pool[math.random(#pool)]
    end

    return text, count, unitTypes
end

function RecruitmentSystem.hire(location, party, unitTypes)
    for i = 1, #unitTypes do
        PartySystem.addActor(party, Troop.new(unitTypes[i]))
    end
end

function RecruitmentSystem.recruit(location, party)
    local text, count, unitTypes = RecruitmentSystem.roll(location)
    RecruitmentSystem.hire(location, party, unitTypes)
    return text, count
end

return RecruitmentSystem