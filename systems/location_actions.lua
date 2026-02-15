-- systems/location_actions.lua
-- Handles logic for location interactions (Rest, Recruit, Explore, etc.)

local LocationActions = {}

local GameContext = require("game.game_context")
local PartySystem = require("systems.party_system")
local StateManager = require("core.state_manager")
local Party = require("entities.party")
local Troop = require("entities.troop")
local RecruitmentSystem = require("systems.recruitment_system")

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

function LocationActions.recruitVolunteers(location)
    local playerParty = GameContext.data.playerParty
    local text, count = RecruitmentSystem.recruit(location, playerParty)
    return text
end

return LocationActions