-- entities/player.lua
-- Player-controlled character

local Actor = require("entities.actor")
local Player = setmetatable({}, Actor)
Player.__index = Player

function Player.new(id, name)
    local self = Actor.new(id, "player")
    setmetatable(self, Player)
    
    self.name = name or "Player"
    self.addTag(self, "player")
    
    return self
end

function Player:togglePause()
    -- Emit pause event
end

return Player
