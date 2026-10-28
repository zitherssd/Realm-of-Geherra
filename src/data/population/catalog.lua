-- Types validate record shapes; this catalog validates references between records.
local Registry = require("src.data.definition_registry")
local Troops = require("src.data.troops")
local Items = require("src.data.items")
local Goals = require("src.systems.goals.goal_definitions")
local Actions = require("src.systems.locations.location_action_registry")
local Schema = require("src.core.schema")
local Types = {
    location = require("src.data.types.location_definition"),
    profile = require("src.data.types.population_profile"),
    rule = require("src.data.types.population_rule"),
    archetype = require("src.data.types.npc_archetype"),
    culture = require("src.data.types.culture"),
    faction = require("src.data.types.faction"),
    party = require("src.data.types.party_template"),
    names = require("src.data.types.name_pool"),
    partyDefinition = require("src.data.types.party_definition"),
    member = require("src.data.types.party_member"),
}
local Catalog = {
    locations = require("src.data.locations.index"),
    profiles = require("src.data.population.locations.index"),
    archetypes = require("src.data.npc_archetypes.index"),
    cultures = require("src.data.population.cultures.index"),
    factions = require("src.data.factions"),
    names = require("src.data.names.index"),
    parties = require("src.data.population.parties.index"),
}

function Catalog.resolveRole(cultureId, role, factionId, garrison)
    local culture = assert(Catalog.cultures[cultureId], "Unknown culture " .. tostring(cultureId))
    local faction = assert(Catalog.factions[factionId], "Unknown faction " .. tostring(factionId))
    return assert(
        (garrison and faction.garrisonRoles and faction.garrisonRoles[role])
            or culture.roles[role]
            or Catalog.cultures.generic.roles[role],
        "Unmapped role " .. tostring(role)
    )
end

local function importantLeader(rule, label)
    for cultureId in pairs(Catalog.cultures) do
        local id = rule.archetype or Catalog.resolveRole(cultureId, rule.role, "neutral", false)
        assert(Catalog.archetypes[id].important, label .. ": party leaders must be important NPCs")
    end
end

function Catalog.validateRule(rule, label, partial)
    if partial then
        Types.rule.Override.validate(rule, label)
    else
        Types.rule.validate(rule, label)
    end
    if not partial then
        assert(rule.role or rule.archetype, label .. ": missing role/archetype")
    end
    if rule.role then
        assert(Catalog.cultures.generic.roles[rule.role], label .. ": unknown role " .. rule.role)
    end
    if rule.archetype then
        assert(Catalog.archetypes[rule.archetype], label .. ": unknown archetype " .. rule.archetype)
    end
    if rule.party then
        if type(rule.party) == "string" then
            assert(Catalog.parties[rule.party], label .. ": unknown party template " .. rule.party)
        else
            Catalog.validatePartyDefinition(rule.party, label .. " party")
        end
        if not partial or rule.role or rule.archetype then
            importantLeader(rule, label)
        end
    end
    Catalog.validateConditions(rule.when, label)
end

function Catalog.validateConditions(conditions, label)
    local when = conditions or {}
    Types.rule.Conditions.validate(when, label .. " conditions")
    if when.culture then
        assert(Catalog.cultures[when.culture], label .. ": unknown culture")
    end
    if when.faction then
        assert(Catalog.factions[when.faction], label .. ": unknown faction")
    end
    for _, pair in ipairs({
        {
            "minProsperity",
            "maxProsperity",
        },
        {
            "minPopulation",
            "maxPopulation",
        },
    }) do
        assert(
            not when[pair[1]] or not when[pair[2]] or when[pair[1]] <= when[pair[2]],
            label .. ": inverted condition range"
        )
    end
end

function Catalog.validateArchetype(archetype)
    Types.archetype.validate(archetype)
    assert(Troops[archetype.troopType], "Unknown troop template: " .. archetype.troopType)
    if archetype.party then
        if type(archetype.party) == "string" then
            assert(Catalog.parties[archetype.party], "Unknown archetype party template " .. archetype.party)
        else
            Catalog.validatePartyDefinition(archetype.party, archetype.id .. " party")
        end
        assert(archetype.important, "Party leaders must be important NPCs")
    end
    for _, goal in ipairs(archetype.goals or {}) do
        assert(goal.type ~= "fulfill_obligation", "Cannot initialize a fabricated obligation")
        Goals.create(goal)
    end
    for name in pairs(archetype.capabilities or {}) do
        assert(Goals.capabilities[name], "Unknown capability " .. name)
    end
    assert(
        archetype.important or (#(archetype.goals or {}) == 0 and next(archetype.capabilities or {}) == nil),
        "Ordinary troop archetypes cannot own NPC goals or capabilities"
    )
    local groupKeys = {
        stats = {
            health = true,
            attack = true,
            defense = true,
            speed = true,
            battle_speed = true,
            strength = true,
        },
        attributes = {
            tracking = true,
            shadowcraft = true,
            divination = true,
            engineering = true,
            oratory = true,
            command = true,
            navigation = true,
        },
    }
    for _, group in ipairs({
        "stats",
        "attributes",
    }) do
        Registry.fields(archetype[group] or {}, groupKeys[group], archetype.id .. " " .. group)
    end
    if archetype.stats and archetype.stats.health then
        assert(Registry.range(archetype.stats.health, archetype.id .. " health") > 0, "NPC health must be positive")
    end
    Registry.fields(archetype.equipment or {}, {
        mainHand = true,
        offHand = true,
        rangedWeapon = true,
        head = true,
        body = true,
        hands = true,
        feet = true,
    }, archetype.id .. " equipment")
    for _, item in pairs(archetype.equipment or {}) do
        local choices = type(item) == "table" and item or {
            item,
        }
        assert(#choices > 0, "Empty equipment choice")
        for _, id in ipairs(choices) do
            assert(Items[id], "Unknown equipment item " .. id)
        end
    end
    if archetype.namePool then
        assert(Catalog.names[archetype.namePool], "Unknown archetype name pool")
    end
end

function Catalog.validatePartyDefinition(definition, label, named)
    label = label or "PartyDefinition"
    if named then
        Types.party.validate(definition, label)
    else
        Types.partyDefinition.validate(definition, label)
    end
    local slots = {}
    for _, member in ipairs(definition.members) do
        if member.troopType then
            assert(Troops[member.troopType], label .. ": unknown troop template " .. member.troopType)
            Catalog.validateConditions(member.when, label .. "/" .. member.id)
        else
            Catalog.validateRule(member, label .. "/" .. member.id)
        end
        assert(not slots[member.id], "Duplicate party member slot " .. label .. "/" .. member.id)
        slots[member.id] = true
    end
    return true
end

function Catalog.resolveParty(value)
    if type(value) == "string" then
        return assert(Catalog.parties[value], "Unknown party template " .. value), value
    end
    return value
end

local function guaranteedCommander(rule)
    local low, high = Registry.range(rule.count or 1, "Commander count")
    assert(
        low == 1 and high == 1 and (rule.chance or 1) == 1 and rule.enabled ~= false and not rule.when,
        "Garrison leader must be guaranteed and unique"
    )
    assert(not rule.party, "Garrison commander cannot also request a personal party")
    importantLeader(rule, "Garrison commander")
end

function Catalog.validate()
    for id, template in pairs(Catalog.parties) do
        assert(template.placement == "stationed" or template.placement == "world", "Unknown party placement")
        Catalog.validatePartyDefinition(template, id, true)
    end
    for id, pool in pairs(Catalog.names) do
        Types.names.validate(pool)
        assert(pool.pools.default and #pool.pools.default > 0, "Name pool needs default: " .. id)
        for _, names in pairs(pool.pools) do
            assert(#names > 0, "Empty name pool: " .. id)
        end
    end
    for _, archetype in pairs(Catalog.archetypes) do
        Catalog.validateArchetype(archetype)
    end
    for id, culture in pairs(Catalog.cultures) do
        Types.culture.validate(culture)
        assert(Catalog.names[culture.namePool], "Unknown cultural name pool: " .. id)
        for role, archetype in pairs(culture.roles) do
            assert(
                Catalog.cultures.generic.roles[role] and Catalog.archetypes[archetype],
                "Invalid cultural role: " .. id .. "/" .. role
            )
        end
    end
    for id, profile in pairs(Catalog.profiles) do
        Types.profile.validate(profile)
        local slots = {}
        for _, rule in ipairs(profile.residents) do
            Catalog.validateRule(rule, id)
            assert(not slots[rule.id], "Duplicate population slot " .. id .. "/" .. rule.id)
            slots[rule.id] = rule
        end
        if profile.garrison then
            local g = profile.garrison
            assert(Catalog.cultures.generic.roles[g.role], "Unknown garrison role")
            guaranteedCommander(assert(slots[g.leaderSlot], "Missing garrison leader slot"))
        end
    end
    local Recruitment = require("src.data.recruitment")
    Schema.map(Schema.map(Schema.array(Schema.string)))(Recruitment, "Recruitment")
    assert(Recruitment.neutral and Recruitment.neutral.default, "Missing neutral recruitment fallback")
    for factionId, pools in pairs(Recruitment) do
        assert(Catalog.factions[factionId], "Unknown recruitment faction " .. factionId)
        assert(pools.default, "Missing default recruitment pool: " .. factionId)
        for poolId, troops in pairs(pools) do
            assert(#troops > 0, "Empty recruitment pool: " .. factionId .. "/" .. poolId)
            for _, troopId in ipairs(troops) do
                assert(Troops[troopId], "Unknown recruitment troop " .. troopId)
            end
        end
    end
    for _, factionId in ipairs(require("src.data.population.settings").defaultFactions) do
        assert(Catalog.factions[factionId], "Unknown default faction " .. tostring(factionId))
    end
    for _, band in ipairs(require("src.data.encounters").bands) do
        for _, pool in ipairs(band.pools) do
            assert(Catalog.factions[pool.faction or "neutral"], "Unknown encounter faction " .. tostring(pool.faction))
        end
    end
    for id, quest in pairs(require("src.data.quests")) do
        if quest.onStart and quest.onStart.type == "spawn_party" then
            assert(Catalog.factions[quest.onStart.faction or "bandits"], "Unknown quest party faction: " .. id)
        end
    end
    for id, definition in pairs(Catalog.locations) do
        Types.location.validate(definition)
        assert(Catalog.profiles[definition.populationProfile], "Unknown location population profile: " .. id)
        assert(#definition.names > 0 and #definition.placement.siteSizes > 0, "Location needs names/site sizes")
        if definition.rules.recruitmentPool then
            local found
            for _, pools in pairs(Recruitment) do
                if pools[definition.rules.recruitmentPool] then
                    found = true
                end
            end
            assert(found, "Unknown recruitment pool: " .. definition.rules.recruitmentPool)
        end
        for _, action in ipairs(definition.actions) do
            assert(Actions.has(action.action), "Unknown location action: " .. action.action)
            if action.cooldown then
                assert(action.cooldown.days > 0, "Action cooldown must be positive")
            end
        end
    end
    for id, faction in pairs(Catalog.factions) do
        Registry.checkId("faction", id, faction)
        Types.faction.validate(faction)
        assert(Catalog.cultures[faction.defaultCulture], "Unknown faction culture: " .. id)
        for role, archetype in pairs(faction.garrisonRoles or {}) do
            assert(
                Catalog.cultures.generic.roles[role] and Catalog.archetypes[archetype],
                "Invalid faction garrison role"
            )
        end
        for profileId, overrides in pairs(faction.residentOverrides or {}) do
            local profile = assert(Catalog.profiles[profileId], "Unknown override profile")
            for slot, override in pairs(overrides) do
                local found
                for _, rule in ipairs(profile.residents) do
                    if rule.id == slot then
                        found = rule
                    end
                end
                assert(found, "Unknown override slot: " .. profileId .. "/" .. slot)
                assert(override.id == nil, "Overrides cannot rename a slot")
                Catalog.validateRule(override, id .. "/" .. slot, true)
                local merged = {}
                for key, value in pairs(found) do
                    merged[key] = value
                end
                for key, value in pairs(override) do
                    merged[key] = value
                end
                Catalog.validateRule(merged, id .. "/" .. slot)
                if profile.garrison and profile.garrison.leaderSlot == slot then
                    guaranteedCommander(merged)
                end
            end
        end
    end
    return true
end

Catalog.validate()
return Catalog
