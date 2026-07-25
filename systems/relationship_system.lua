local GameContext = require("game.game_context")

local RelationshipSystem = {}

local function ensureStore()
    GameContext.data.npcRelations = GameContext.data.npcRelations or {}
    return GameContext.data.npcRelations
end

local function getNpcKey(npc)
    if not npc then return nil end
    return npc.id
end

function RelationshipSystem.getOrCreate(npc)
    local key = getNpcKey(npc)
    if not key then return nil end

    local store = ensureStore()
    if not store[key] then
        store[key] = {
            met = false,
            introduced = false,
            relation = 0
        }
    end

    return store[key]
end

function RelationshipSystem.markMet(npc)
    local rel = RelationshipSystem.getOrCreate(npc)
    if not rel then return false end

    local wasFirst = not rel.met
    rel.met = true
    return wasFirst
end

function RelationshipSystem.introduceToNpc(npc)
    local rel = RelationshipSystem.getOrCreate(npc)
    if not rel then return false end

    local wasFirst = not rel.introduced
    rel.met = true
    rel.introduced = true
    return wasFirst
end

function RelationshipSystem.hasIntroduced(npc)
    local rel = RelationshipSystem.getOrCreate(npc)
    return rel and rel.introduced or false
end

function RelationshipSystem.getRelation(npc)
    local rel = RelationshipSystem.getOrCreate(npc)
    return rel and rel.relation or 0
end

function RelationshipSystem.addRelation(npc, amount)
    local rel = RelationshipSystem.getOrCreate(npc)
    if not rel then return 0 end

    rel.relation = (rel.relation or 0) + (amount or 0)
    return rel.relation
end

return RelationshipSystem