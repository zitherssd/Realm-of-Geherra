-- game/game_context.lua
-- Shared blackboard containing player party, world, quests, global flags

local GameContext = {}

GameContext.data = {
    player = nil,
    party = {},
    playerParty = nil,
    currentWorld = nil,
    currentMap = nil,
    activeQuests = {},
    completedQuests = {},
    globalFlags = {},
    difficulty = "normal",
    playtime = 0
}

function GameContext.init()
    GameContext.data = {
        player = nil,
        party = {},
        playerParty = nil,
        currentWorld = nil,
        currentMap = nil,
        activeQuests = {},
        completedQuests = {},
        globalFlags = {},
        difficulty = "normal",
        playtime = 0
    }
end

function GameContext.setPlayer(player)
    GameContext.data.player = player
end

function GameContext.getPlayer()
    return GameContext.data.player
end

function GameContext.addToParty(actor)
    table.insert(GameContext.data.party, actor)
end

function GameContext.removeFromParty(actorId)
    for i, actor in ipairs(GameContext.data.party) do
        if actor.id == actorId then
            table.remove(GameContext.data.party, i)
            break
        end
    end
end

function GameContext.getParty()
    return GameContext.data.party
end

function GameContext.setGlobalFlag(flagName, value)
    GameContext.data.globalFlags[flagName] = value
end

function GameContext.getGlobalFlag(flagName)
    return GameContext.data.globalFlags[flagName]
end

return GameContext
