-- Reuse the same actor when independent residents take traveling work.
local Party = require("src.ecs.assemblages.party")
local Parties = require("src.systems.parties.party_system")
local Locations = require("src.systems.locations.location_system")
local Transition = {}

function Transition.create(actor, location, name, context)
    local party = Party.create(context.world, name, actor.id)
    party.x, party.y, party.faction = location.x, location.y, actor.faction
    Locations.removeNPC(location, actor)
    Parties.addActor(party, actor)
    if not Locations.addStationedParty(context.map, location, party) then
        Parties.removeActor(party, actor)
        Locations.addNPC(location, actor)
        context.world:removeEntity(party)
        return nil, "stationing_failed"
    end
    return party
end

function Transition.restore(actor, party, location, context)
    -- Unexpected cargo, money or companions must retain their real party.
    if #party.inventory > 0 or party.treasury > 0 or #party.actors ~= 1 then return false end
    context.map:removeParty(party.id)
    Parties.removeActor(party, actor)
    Locations.addNPC(location, actor)
    context.world:removeEntity(party)
    return true
end

return Transition
