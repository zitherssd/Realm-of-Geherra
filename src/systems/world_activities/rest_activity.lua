local EcsWorld = require("src.ecs.world")
local PartySystem = require("src.systems.parties.party_system")
local Recovery = require("src.systems.actors.recovery")
local Rest = {initialPhase = "rest"}

function Rest.prepare(party, params)
    if EcsWorld.findPartyById(party.id, party.__world) ~= party then return nil, "party_missing" end
    local actor = PartySystem.getLeader(party)
    if not Recovery.isLiving(actor) or not actor.memory or actor.player then return nil, "invalid_rest_actor" end
    if params.actorId ~= actor.id then return nil, "rest_requires_leader" end
    return {}
end

function Rest.onStart(party, activity)
    activity.previousPartyState = party.state
    party.state = "rest"
    return true
end

function Rest.update(party, activity, dt)
    if EcsWorld.findPartyById(party.id, party.__world) ~= party then return "failed", "party_removed" end
    local actor = EcsWorld.findActorById(activity.params.actorId, party.__world)
    if not Recovery.isLiving(actor) or PartySystem.getLeader(party) ~= actor then
        return "failed", "rest_actor_unavailable"
    end
    if actor.activeEncounterId then return end
    if not Recovery.needsRest(actor, true) then return "completed", "recovered" end
    -- Recovery.update heals the entire party once, using the shared rest bonus.
end

function Rest.onTerminal(party, activity)
    party.state = activity.previousPartyState or "idle"
    activity.previousPartyState = nil
end

return Rest
