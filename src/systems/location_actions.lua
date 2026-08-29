-- systems/location_actions.lua
-- Handles logic for location interactions (Rest, Recruit, Explore, etc.)

local LocationActions = {}

local GameContext = require("src.game.game_context")
local PartySystem = require("src.systems.party_system")
local StateManager = require("src.core.state_manager")
local Party = require("src.entities.party")
local Troop = require("src.entities.troop")
local RecruitmentSystem = require("src.systems.recruitment_system")
local TimeSystem = require("src.systems.time_system")
local AttributeSystem = require("src.systems.attribute_system")

local DEFAULT_TAVERN_REST_COST = 20

-- Costs for the two-step recruitment flow (see startRecruitmentDialogue)
LocationActions.ROLL_FAVOR_COST = 5
LocationActions.HIRE_FAVOR_COST = 30

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

-- Roll for volunteers: costs ROLL_FAVOR_COST favor and stores the result on the
-- location so the player can decide whether to hire them (HIRE_FAVOR_COST).
function LocationActions.rollRecruitment(location)
    GameContext.data.favor = (GameContext.data.favor or 0) - LocationActions.ROLL_FAVOR_COST

    local playerParty = GameContext.data.playerParty
    local text, count, unitTypes = RecruitmentSystem.roll(location)

    -- The call for volunteers starts the cooldown regardless of the outcome,
    -- so a failed roll still costs the village's goodwill for a while.
    location.lastRecruitDay = TimeSystem.getDay()

    if count > 0 then
        location.pendingRecruitment = { count = count, unitTypes = unitTypes }
    else
        location.pendingRecruitment = nil
    end

    return text, count
end

-- Hire the pending volunteers for HIRE_FAVOR_COST favor. Starts the recruit
-- cooldown. Returns (success, message).
function LocationActions.hireRecruits(location)
    local currentDay = TimeSystem.getDay()
    local currentFavor = GameContext.data.favor or 0
    if currentFavor < LocationActions.HIRE_FAVOR_COST then
        return false, string.format("You need %d favor to hire them, but only have %d.", LocationActions.HIRE_FAVOR_COST, currentFavor)
    end

    GameContext.data.favor = currentFavor - LocationActions.HIRE_FAVOR_COST

    local pending = location.pendingRecruitment
    local playerParty = GameContext.data.playerParty
    local hired = 0
    if pending and pending.unitTypes then
        RecruitmentSystem.hire(location, playerParty, pending.unitTypes)
        hired = #pending.unitTypes
    end

    location.pendingRecruitment = nil
    location.lastRecruitDay = currentDay

    return true, string.format("%d volunteers have sworn to follow you.", hired)
end

function LocationActions.clearPendingRecruitment(location)
    if location then
        location.pendingRecruitment = nil
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

    -- If a previous roll left volunteers waiting, offer to hire them first
    if location.pendingRecruitment and location.pendingRecruitment.count > 0 then
        StateManager.push("dialogue", {
            dialogueTree = {
                speaker = "Village Elder",
                lines = {
                    {
                        text = "The volunteers you called for are still waiting. Will you take them into your company?",
                        options = {
                            { text = "Hire them (" .. LocationActions.HIRE_FAVOR_COST .. " favor).", action = "hire_recruits" },
                            { text = "Let them go.", action = "decline_recruits", next = "end" }
                        }
                    }
                }
            },
            location = location,
            showFavor = true
        })
        return
    end

    local currentFavor = GameContext.data.favor or 0
    if currentFavor < LocationActions.ROLL_FAVOR_COST then
        StateManager.push("dialogue", {
            dialogueTree = {
                speaker = "System",
                lines = { { text = "You don't have enough favor to call for volunteers (requires " .. LocationActions.ROLL_FAVOR_COST .. ").", options = {{ text = "Continue", next = "end" }} } }
            },
            showFavor = true
        })
        return
    end

    StateManager.push("dialogue", {
        dialogueTree = {
            speaker = "Village Elder",
            lines = {
                {
                    text = "You could call for volunteers. Some may answer, but you'll need to win them over before they truly join.",
                    options = {
                        { text = "Call for volunteers (" .. LocationActions.ROLL_FAVOR_COST .. " favor).", action = "roll_recruitment" },
                        { text = "Leave them be.", next = "end" }
                    }
                }
            }
        },
        location = location,
        showFavor = true
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
