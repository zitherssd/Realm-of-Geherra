local PartySystem = require("src.systems.parties.party_system")
local Movement = require("src.systems.parties.party_ai_system")

local Scenario = {}
function Scenario.run()
    local party = {x = 0, y = 0, actors = {{stats = {speed = 8}}, {stats = {speed = 12}}}}
    local map = {getTravelSpeedMod = function() return 0.4 end,
        isWalkable = function(_, x) return x <= 100 end}
    assert(PartySystem.getPartySpeed(party) == 80)
    for _, name in ipairs({"travel", "roam", "raid"}) do
        local activity = require("src.systems.world_activities." .. name .. "_activity")
        assert(PartySystem.getPartySpeed(party, activity.speed, map)
            == PartySystem.getPartySpeed(party, nil, map), name .. " must use normal movement speed")
    end
    assert(PartySystem.getPartySpeed(party, Movement.wanderSpeed, map)
        == PartySystem.getPartySpeed(party, nil, map) / 2)
    Movement.moveToward(party, 200, 0, Movement.wanderSpeed, 1, map)
    assert(party.x == 16, "idle wandering must move at half normal speed")
    party.x = 0
    assert(PartySystem.getPartySpeed(party, 70, map) == 28)
    party.speedModifier = 0.5
    assert(PartySystem.getPartySpeed(party, 70, map) == 14)
    party.actors[2].stats.speed = 32
    assert(PartySystem.getPartySpeed(party, 70, map) == 28)
    Movement.moveToward(party, 200, 0, 70, 1, map)
    assert(party.x == 28)
    party.x = 0
    Movement.followWaypoints(party, {{x = 200, y = 0}}, 1, 70, 1, map)
    assert(math.abs(party.x - 28) < 1e-6)
    Movement.moveToward(party, 200, 0, 70, 10, map)
    assert(math.abs(party.x - 28) < 1e-6, "blocked terrain must stop movement")
    party.actors = {}
    assert(PartySystem.getPartySpeed(party) == 40)
    assert(PartySystem.getPartySpeed(nil) == 80)
end
return Scenario
