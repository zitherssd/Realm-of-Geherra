-- systems/encounter_system.lua
--
-- Detects encounters between parties and locations on the world map.

local Math = require("util.math")

local EncounterSystem = {}

function EncounterSystem.detect(player_party, parties, locations, world)
    local player = player_party

    for _, party in ipairs(parties) do
        if party ~= player then
            local distance = Math.distance(player.position.x, player.position.y, party.position.x, party.position.y)
            if distance <= player.radius + party.radius + 8 then
                return {
                    type = "party",
                    initiator = player,
                    target = party,
                    world_context = {
                        region = world:sample(player.position.x, player.position.y).region,
                    },
                }
            end
        end
    end

    for _, location in ipairs(locations) do
        local distance = Math.distance(player.position.x, player.position.y, location.position.x, location.position.y)
        if distance <= player.radius + location.radius then
            return {
                type = "location",
                initiator = player,
                target = location,
                world_context = {
                    region = world:sample(player.position.x, player.position.y).region,
                },
            }
        end
    end

    return nil
end

return EncounterSystem
