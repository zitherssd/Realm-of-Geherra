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



function LocationActions.visitTavern(location)

    StateManager.push("dialogue", {

        dialogueTree = {

            speaker = "System",

            lines = { { text = "The tavern is bustling, but there's nothing to do yet.", options = {{ text = "Leave", next = "end" }} } }

        }

    })

end



function LocationActions.tradeGoods(location)

    StateManager.push("dialogue", {

        dialogueTree = {

            speaker = "System",

            lines = { { text = "The market is empty for now.", options = {{ text = "Leave", next = "end" }} } }

        }

    })

end



function LocationActions.requestAudience(location)

    StateManager.push("dialogue", {

        dialogueTree = {

            speaker = "System",

            lines = { { text = "The lord of the castle is not seeing visitors.", options = {{ text = "Leave", next = "end" }} } }

        }

    })

end



function LocationActions.trainTroops(location)

    StateManager.push("dialogue", {

        dialogueTree = {

            speaker = "System",

            lines = { { text = "The training grounds are not yet implemented.", options = {{ text = "Leave", next = "end" }} } }

        }

    })

end



function LocationActions.buySupplies(location)

    StateManager.push("dialogue", {

        dialogueTree = {

            speaker = "System",

            lines = { { text = "There are no supplies to buy at the moment.", options = {{ text = "Leave", next = "end" }} } }

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



    local favorCost = 10

    local currentFavor = GameContext.data.favor or 0

    if currentFavor < favorCost then

        return "You don't have enough favor to attract new recruits (requires 10)."

    end



    GameContext.data.favor = currentFavor - favorCost

    location.lastRecruitDay = currentDay

    

    local playerParty = GameContext.data.playerParty

    local text, count = RecruitmentSystem.recruit(location, playerParty)

    

    return text

end



return LocationActions
