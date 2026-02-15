-- systems/location_actions.lua
-- Handles logic for location interactions (Rest, Recruit, Explore, etc.)

local LocationActions = {}

local GameContext = require("game.game_context")
local PartySystem = require("systems.party_system")
local StateManager = require("core.state_manager")
local Party = require("entities.party")
local Troop = require("entities.troop")
local RecruitmentSystem = require("systems.recruitment_system")
local TimeSystem = require("systems.time_system")

function LocationActions.exploreRuin(location)
    local enemyParty = Party.new("Ruin Guardians", nil)
    enemyParty.faction = "bandits"
    
    -- Add random enemies
    local count = math.random(2, 4)
    for i = 1, count do
        enemyParty:addActor(Troop.new("bandit"))
    end
    
    StateManager.swap("battle", { enemyParty = enemyParty })
end

function LocationActions.rest(location)
    -- In a full implementation, this might heal the party or pass time
    StateManager.push("dialogue", {
        dialogueTree = {
            speaker = "System",
            lines = {
                { text = "You rest for a while. Your party feels refreshed.", options = {{ text = "Continue", next = "end" }} }
            }
        }
    })
end

function LocationActions.getRecruitCooldown(location)
    local currentDay = TimeSystem.getDay()
    local lastRecruit = location.lastRecruitDay or -100
    return math.max(0, (lastRecruit + 5) - currentDay)
end

function LocationActions.recruitVolunteers(location)
    local currentDay = TimeSystem.getDay()
    
    if LocationActions.getRecruitCooldown(location) > 0 then
        return "The village has no more volunteers for now. Come back later."
    end

    local playerParty = GameContext.data.playerParty
    local text, count = RecruitmentSystem.recruit(location, playerParty)
    location.lastRecruitDay = currentDay
    return text
end

return LocationActions