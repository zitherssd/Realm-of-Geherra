-- src/systems/party_interaction_system.lua
-- Handles collisions and interactions between parties on the map.

local StateManager = require("src.core.state_manager")

local PartyInteractionSystem = {}

PartyInteractionSystem.interactionRadius = 10

-- Checks for collisions and interactions between parties on the map.
-- Currently handles Player vs AI interactions.
-- Future: Can be expanded to handle AI vs AI interactions (e.g. bandits attacking traders) 
-- by iterating over all party pairs and resolving hostility via FactionSystem.
function PartyInteractionSystem.update(dt, map, playerParty, interactionCooldowns, playerWantsToInteract)
    local nearbyParty = nil
    
    for _, otherParty in ipairs(map.parties) do
        if otherParty.id ~= playerParty.id and otherParty.visible and
            not otherParty.activeEncounterId then
            local dx = otherParty.x - playerParty.x
            local dy = otherParty.y - playerParty.y
            local dist = math.sqrt(dx*dx + dy*dy)

            if dist < PartyInteractionSystem.interactionRadius then
                nearbyParty = otherParty
                
                -- Check faction hostility. Spawned encounter parties carry a
                -- `hostile` flag (see systems/encounter_system.lua); bandits are
                -- always hostile. In the future this could use FactionSystem.
                local isHostile = otherParty.hostile == true or otherParty.faction == "bandits"

                if isHostile then
                    -- Check cooldown to prevent immediate re-trigger
                    if not interactionCooldowns[otherParty.id] then
                        -- Set cooldown (3 seconds) so player has time to move away after leaving dialogue
                        interactionCooldowns[otherParty.id] = 2.0
                        
                        -- Force interaction immediately
                        local dialogueId = otherParty.dialogueId or "bandit_start"
                        StateManager.push("dialogue", {dialogueId = dialogueId, target = otherParty})
                        
                        -- Return true to indicate an interaction interrupted the update loop
                        return nearbyParty, true 
                    end
                elseif playerWantsToInteract then
                    -- Player initiated interaction
                    StateManager.push("dialogue", {dialogueId = otherParty.dialogueId or "elder_greeting", target = otherParty})
                end
            end
        end
    end
    
    return nearbyParty, false
end

return PartyInteractionSystem
