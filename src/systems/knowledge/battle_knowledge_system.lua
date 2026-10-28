-- Battle-specific acquisition hooks. Memory storage/filtering stays in Knowledge.
local Knowledge = require("src.systems.knowledge.knowledge_system")
local Events = require("src.systems.campaign.world_events")
local EcsWorld = require("src.ecs.world")
local BattleKnowledge = {}
local details = {"time", "location", "participants", "outcome"}

local function learn(owner, eventId, world)
    -- Memory is optional, including on otherwise valid participating parties.
    if owner and owner.memory then Knowledge.learn(owner, eventId, details, world) end
end

-- Call immediately after recording, using the historical roster and survival
-- snapshot captured before casualty/removal callbacks can change membership.
function BattleKnowledge.learnParticipants(world, event, survivingActorIds)
    for _, participant in ipairs(event.participants) do
        local partySurvived = false
        for _, actorId in ipairs(participant.actorIds) do
            if survivingActorIds[actorId] then
                partySurvived = true
                learn(EcsWorld.findActorById(actorId, world), event.id, world)
            end
        end
        if partySurvived then
            learn(EcsWorld.findPartyById(participant.partyId, world), event.id, world)
        end
    end
end

local function matchesSite(event, site, map)
    return event and event.type == "battle_ended" and event.battlefieldId == site.id
        and event.mapId == map.id and event.encounterId == site.history.encounterId
end

-- Called only after VisibilitySystem confirms this observer can see this site.
function BattleKnowledge.discover(party, site, map)
    local world = party.__world
    if not world or EcsWorld.findPartyById(party.id, world) ~= party then return end
    local event
    if site.history.eventId then
        event = Events.get(world, site.history.eventId)
        if not matchesSite(event, site, map) then return end
    else
        -- Older remains have only encounter/subject identity. Resolve that exact
        -- site, never all battles, and leave unrelated history unknown.
        for _, candidate in ipairs(Events.getBySubject(world, site.id)) do
            if matchesSite(candidate, site, map) then event = candidate; break end
        end
    end
    if not event then return end -- Synthetic/legacy remains may have no event.
    learn(party, event.id, world)
    for _, actor in ipairs(party.actors or {}) do
        if (actor.hp or 0) > 0 then learn(actor, event.id, world) end
    end
end

return BattleKnowledge
