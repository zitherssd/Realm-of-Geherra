-- systems/attribute_system.lua
-- Handles checking actor and party attributes

local AttributeSystem = {}
local GameContext = require("game.game_context")

-- Checks if a single actor has the required attribute level
function AttributeSystem.actorHasLevel(actor, attribute, level)
    if not actor or not actor.attributes or not actor.attributes[attribute] then
        return false
    end
    return actor.attributes[attribute] >= level
end

-- Checks if the player character has the required attribute level
function AttributeSystem.playerHasLevel(attribute, level)
    local playerParty = GameContext.data.playerParty
    if not playerParty then return false end

    local player = playerParty:getLeader() -- Assuming leader is the player character
    return AttributeSystem.actorHasLevel(player, attribute, level)
end

-- Checks if anyone in the player's party has the required attribute level
-- This includes the player and any companions.
function AttributeSystem.partyHasLevel(attribute, level)
    local playerParty = GameContext.data.playerParty
    if not playerParty then return false end

    for _, actor in ipairs(playerParty.actors) do
        if AttributeSystem.actorHasLevel(actor, attribute, level) then
            return true
        end
    end
    return false
end

-- Gets the highest level for a given attribute across the entire party
function AttributeSystem.getPartyMaxLevel(attribute)
    local playerParty = GameContext.data.playerParty
    if not playerParty then return 0 end

    local maxLevel = 0
    for _, actor in ipairs(playerParty.actors) do
        if actor and actor.attributes and actor.attributes[attribute] then
            if actor.attributes[attribute] > maxLevel then
                maxLevel = actor.attributes[attribute]
            end
        end
    end
    return maxLevel
end


return AttributeSystem
