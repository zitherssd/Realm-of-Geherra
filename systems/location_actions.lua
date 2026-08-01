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
local AttributeSystem = require("systems.attribute_system")

local DEFAULT_TAVERN_REST_COST = 20

function LocationActions.exploreRuin(location)
    local enemyParty = Party.new("Ruin Guardians", nil)
    enemyParty.faction = "undead"

    local swordCount = math.random(1, 4)
    local spearCount = math.random(1, 4)
    for _ = 1, swordCount do
        enemyParty:addActor(Troop.new("skeleton_sword"))
    end
    for _ = 1, spearCount do
        enemyParty:addActor(Troop.new("skeleton_spear"))
    end

    StateManager.swap("battle", {
        enemyParty = enemyParty,
        onVictory = function()
            location.lastExploreDay = TimeSystem.getDay()
        end
    })
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

function LocationActions.attackBanditCamp(location)
    local enemyParty = Party.new("Bandit Defenders", nil)
    enemyParty.faction = "bandits"

    local count = math.random(3, 6)
    local types = {"bandit", "bandit", "bandit", "bandit", "peasant"}
    for _ = 1, count do
        enemyParty:addActor(Troop.new(types[math.random(#types)]))
    end

    StateManager.swap("battle", {
        enemyParty = enemyParty,
        location = location
    })
end

function LocationActions.pray(location)
    local divinationLevel = AttributeSystem.getPartyMaxLevel("divination")
    StateManager.push("dialogue", {
        dialogueTree = {
            speaker = "The Shrine",
            lines = {
                { text = "You kneel before the altar and offer your prayers to the old gods. (Effects based on divination level coming soon.)",
                  options = {{ text = "Rise", next = "end" }} }
            }
        },
        divinationLevel = divinationLevel,
        location = location
    })
    location.lastPrayDay = TimeSystem.getDay()
end



function LocationActions.buySupplies(location)

    StateManager.push("dialogue", {

        dialogueTree = {

            speaker = "System",

            lines = { { text = "There are no supplies to buy at the moment.", options = {{ text = "Leave", next = "end" }} } }

        }

    })

end



function LocationActions.getCooldownRemaining(location, key, days)
    local currentDay = TimeSystem.getDay()
    local lastUsed = location[key] or -100
    return math.max(0, (lastUsed + days) - currentDay)
end

function LocationActions.getRecruitmentCost()
    local oratoryLevel = AttributeSystem.getPartyMaxLevel("oratory")
    if oratoryLevel >= 2 then
        return 0
    elseif oratoryLevel >= 1 then
        return 5
    else
        return 10
    end
end

function LocationActions.performRecruitment(location, favorCost)
    local currentDay = TimeSystem.getDay()
    GameContext.data.favor = (GameContext.data.favor or 0) - favorCost
    location.lastRecruitDay = currentDay
    
    local playerParty = GameContext.data.playerParty
    local text, count = RecruitmentSystem.recruit(location, playerParty)
    
    return text
end

function LocationActions.startRecruitmentDialogue(location)
    if LocationActions.getCooldownRemaining(location, "lastRecruitDay", 5) > 0 then
        StateManager.push("dialogue", {
            dialogueTree = {
                speaker = "System",
                lines = { { text = "The village has no more volunteers for now. Come back later.", options = {{ text = "Continue", next = "end" }} } }
            },
            showFavor = true
        })
        return
    end

    local favorCost = LocationActions.getRecruitmentCost()
    local currentFavor = GameContext.data.favor or 0
    if currentFavor < favorCost then
        StateManager.push("dialogue", {
            dialogueTree = {
                speaker = "System",
                lines = { { text = "You don't have enough favor to attract new recruits (requires " .. favorCost .. ").", options = {{ text = "Continue", next = "end" }} } }
            },
            showFavor = true
        })
        return
    end

    local optionText = "Recruit them"
    if favorCost > 0 then
        optionText = optionText .. " (" .. favorCost .. " favor)."
    else
        optionText = optionText .. " (free)."
    end

    StateManager.push("dialogue", {
        dialogueTree = {
            speaker = "Village Elder",
            lines = {
                {
                    text = "A few able-bodied villagers look eager to join a new cause.",
                    options = {
                        {text = optionText, action = "recruit_volunteers"},
                        {text = "Leave them be.", next = "end"}
                    }
                }
            }
        },
        location = location,
        showFavor = true,
        favorCost = favorCost
    })
end

function LocationActions.payForTavernRest(location, cost)
    local playerParty = GameContext.data.playerParty
    if not playerParty then
        return false, "You have no active party to charge."
    end

    local restCost = math.max(0, tonumber(cost) or DEFAULT_TAVERN_REST_COST)
    local currentGold = playerParty:getTreasury()

    if currentGold < restCost then
        return false, string.format("You need %d gold to rest, but only have %d.", restCost, currentGold)
    end

    playerParty:withdrawTreasury(restCost)

    local locationName = (location and location.name) or "the tavern"
    return true, string.format("You pay %d gold and rest at %s.", restCost, locationName)
end

return LocationActions
