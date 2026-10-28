-- systems/actors/player_system.lua
-- Player-only resources that aren't shared with the rest of the party (favor).

local GameContext = require("src.game.game_context")

local PlayerSystem = {}

function PlayerSystem.getFavor()
    local player = GameContext.getPlayer()
    return player and player.favor or 0
end

function PlayerSystem.addFavor(amount)
    local player = GameContext.getPlayer()
    if not player then return end
    player.favor = (player.favor or 0) + amount
end

return PlayerSystem
