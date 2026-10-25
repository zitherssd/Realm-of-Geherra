-- Serializable value returned by LootResolver. Item records are plain copies
-- so the result never retains references to campaign entities or item data.

local LootResult = {}

function LootResult.new(outcome, winnerPartyId, loserPartyId, partyAId, partyBId)
    return {
        schemaVersion = 1,
        outcome = outcome,
        winnerPartyId = winnerPartyId,
        loserPartyId = loserPartyId,
        partyAId = partyAId,
        partyBId = partyBId,
        partyStates = {},
        combatLoot = {},
        plunder = {
            eligible = false,
            sourcePartyId = nil,
            recipientPartyId = nil,
            sourcePartyEliminated = false,
            itemAllocations = {},
            goldAllocations = {}
        },
        destroyedResources = {
            items = {},
            gold = 0
        },
        retainedResources = {
            items = {},
            gold = {}
        }
    }
end

return LootResult
