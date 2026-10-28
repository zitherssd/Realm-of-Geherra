-- Creates an initial party around the actual generated leader. Gameplay owns it afterward.
local Catalog = require("src.data.population.catalog")
local Registry = require("src.data.definition_registry")
local Actors = require("src.systems.population.npc_factory")
local Locations = require("src.systems.locations.location_system")
local Parties = require("src.systems.parties.party_system")
local Party = require("src.ecs.assemblages.party")
local Random = require("src.core.seeded_random")
local Factory = {}

function Factory.create(map, location, leader, spec, seed, key, context)
    context = context or {}
    assert(leader.memory and not leader.player, "An NPC party needs an important NPC leader")
    local party = Party.create(location.__world, context.name or (leader.name .. " — " .. spec.nameSuffix), leader.id)
    party.templateId, party.originLocationId = context.templateId, location.id
    party.faction, party.hostile = location.faction, spec.hostile or false
    party.x, party.y = location.x, location.y
    local funds = Random.new(seed, key .. ":funds")
    party.treasury = Registry.roll(spec.treasury or 0, funds)
    party.supplies = Registry.roll(spec.supplies or 100, funds)
    assert(Locations.removeNPC(location, leader), "NPC party leader must be an independent resident")
    local function add(actor)
        assert(Parties.addActor(party, actor))
        party.treasury = party.treasury + actor.treasury
        actor.treasury = 0
    end
    add(leader)
    local faction = Catalog.factions[location.faction]
    for _, member in ipairs(spec.members) do
        if context.matches(member, location) then
            local rng = Random.new(seed, key .. ":" .. member.id)
            local archetypeId = not member.troopType and (member.archetype
                or Catalog.resolveRole(location.culture, member.role, location.faction, context.garrison))
            local culture = context.garrison and member.role and faction.garrisonRoles
                and faction.garrisonRoles[member.role] and faction.defaultCulture or location.culture
            for _ = 1, Registry.roll(member.count or 1, rng) do
                if rng() < (member.chance or 1) then
                    local actorContext = {rng = rng, culture = culture, faction = location.faction, homeLocationId = location.id}
                    local actor
                    if member.troopType then actor = Actors.createTroop(location.__world, member.troopType, actorContext)
                    else actor = Actors.create(location.__world, archetypeId, actorContext) end
                    actor.populationSlot = member.id
                    actor.x, actor.y = location.x, location.y
                    -- Member archetypes are hydrated as members, never recursively as parties.
                    add(actor)
                end
            end
        end
    end
    if spec.placement == "world" then assert(map:addParty(party))
    else assert(Locations.addStationedParty(map, location, party)) end
    location.initialPartyIds = location.initialPartyIds or {}
    location.initialPartyIds[#location.initialPartyIds + 1] = party.id
    return party
end

return Factory
