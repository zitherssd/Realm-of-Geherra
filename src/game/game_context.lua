-- game/game_context.lua
-- Shared blackboard containing player party, world, quests, global flags

local GameContext = {}
local EcsWorld = require("src.ecs.world")

local function newData()
    local data = {
        playerId = nil,
        party = {},
        playerPartyId = nil,
        currentWorld = nil,
        currentMap = nil,
        npcRelations = {},
        globalFlags = {},
        difficulty = "normal",
        playtime = 0
    }

    return setmetatable(data, {
        __index = function(state, key)
            if key == "player" then
                return EcsWorld.findActorById(state.playerId)
            elseif key == "playerParty" then
                return EcsWorld.findPartyById(state.playerPartyId)
            end
            return nil
        end,
        __newindex = function(state, key, value)
            if key == "player" then
                rawset(state, "playerId", value and value.id or nil)
            elseif key == "playerParty" then
                rawset(state, "playerPartyId", value and value.id or nil)
            else
                rawset(state, key, value)
            end
        end
    })
end

GameContext.data = newData()

function GameContext.init()
    GameContext.data = newData()
end

function GameContext.setPlayer(player)
    GameContext.data.playerId = player and player.id or nil
end

function GameContext.getPlayer()
    return GameContext.data.player
end

function GameContext.setPlayerParty(party)
    GameContext.data.playerPartyId = party and party.id or nil
end

function GameContext.getPlayerParty()
    return GameContext.data.playerParty
end

function GameContext.addToParty(actor)
    table.insert(GameContext.data.party, actor.id)
end

function GameContext.removeFromParty(actorId)
    for i, id in ipairs(GameContext.data.party) do
        if id == actorId then
            table.remove(GameContext.data.party, i)
            break
        end
    end
end

function GameContext.getParty()
    local actors = {}
    for _, actorId in ipairs(GameContext.data.party) do
        local actor = EcsWorld.findActorById(actorId)
        if actor then
            actors[#actors + 1] = actor
        end
    end
    return actors
end

function GameContext.setGlobalFlag(flagName, value)
    GameContext.data.globalFlags[flagName] = value
end

function GameContext.getGlobalFlag(flagName)
    return GameContext.data.globalFlags[flagName]
end

return GameContext
