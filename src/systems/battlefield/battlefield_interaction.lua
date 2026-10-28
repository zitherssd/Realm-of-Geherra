local BattlefieldRemainsSystem = require("src.systems.battlefield.battlefield_remains_system")
local BattlefieldResourceCollection = require("src.systems.battlefield.battlefield_resource_collection")

local BattlefieldInteraction = {}

local function findSite(map, siteId)
    if not map then return nil end
    for _, site in ipairs(BattlefieldRemainsSystem.getAll(map)) do
        if site.id == siteId then
            return site
        end
    end
    return nil
end

local function getParticipants(site)
    local names = {}
    for _, participant in ipairs(site.history.participants or {}) do
        names[#names + 1] = participant.name or tostring(participant.partyId)
    end
    return names
end

local function getVictors(site)
    local victorId = site.history.victorPartyId
    if not victorId then return "No victor recorded" end

    for _, participant in ipairs(site.history.participants or {}) do
        if participant.partyId == victorId then
            return participant.name or tostring(victorId)
        end
    end
    return tostring(victorId)
end

local function describeItems(items)
    local descriptions = {}
    for _, item in ipairs(items or {}) do
        local name = item.name or item.id or "Unknown supply"
        local quantity = item.quantity or 1
        descriptions[#descriptions + 1] = tostring(name) .. " x" .. tostring(quantity)
    end
    return descriptions
end

local function formatWorldTime(worldTime)
    if type(worldTime) ~= "table" then return "unknown time" end
    return string.format("day %s, hour %.2f",
        tostring(worldTime.day or "?"), tonumber(worldTime.hour) or 0)
end

local function buildOverviewText(site)
    local history = site.history or {}
    local participants = getParticipants(site)
    local itemCount = #(site.loot and site.loot.items or {})
    local gold = site.loot and site.loot.gold or 0

    return string.format(
        "Encounter %s took place at %s at (%.0f, %.0f): %s. Victor: %s. %d corpse(s), %d cargo stack(s), and %s gold remain.",
        tostring(history.encounterId or "unknown"),
        formatWorldTime(history.worldTime),
        tonumber(history.position and history.position.x) or 0,
        tonumber(history.position and history.position.y) or 0,
        #participants > 0 and table.concat(participants, " versus ") or "the participants are unknown",
        getVictors(site),
        #(site.corpses or {}),
        itemCount,
        tostring(gold)
    )
end

local function buildUnavailableTree(message)
    return {
        speaker = "Battlefield",
        lines = {{
            text = message,
            options = {
                {text = "Return to the battlefield.", action = "battlefield_back"},
                {text = "Leave.", next = "end"}
            }
        }}
    }
end

function BattlefieldInteraction.findSite(map, siteId)
    return findSite(map, siteId)
end

function BattlefieldInteraction.buildDialogue(map, siteId)
    local site = findSite(map, siteId)
    if not site then
        return buildUnavailableTree("This battlefield site is no longer present.")
    end

    local options = {
        {text = "Inspect the battlefield.", action = "battlefield_inspect"}
    }
    local hasSupplies = site.loot and
        ((site.loot.items and #site.loot.items > 0) or (site.loot.gold or 0) > 0)
    if hasSupplies then
        options[#options + 1] = {
            text = "Search for supplies.",
            action = "battlefield_collect"
        }
    end
    if site.corpses and #site.corpses > 0 then
        options[#options + 1] = {
            text = "Loot corpses. (Unavailable)",
            action = "battlefield_unavailable",
            unavailableAction = "corpse_loot"
        }
        options[#options + 1] = {
            text = "Bury the dead. (Unavailable)",
            action = "battlefield_unavailable",
            unavailableAction = "bury"
        }
    end
    options[#options + 1] = {text = "Leave.", next = "end"}

    return {
        speaker = "Battlefield",
        lines = {{
            text = buildOverviewText(site),
            options = options
        }}
    }
end

function BattlefieldInteraction.buildInspectDialogue(map, siteId)
    local site = findSite(map, siteId)
    if not site then
        return buildUnavailableTree("This battlefield site is no longer present.")
    end

    local history = site.history or {}
    local participants = getParticipants(site)
    local corpseDescriptions = {}
    for _, corpse in ipairs(site.corpses or {}) do
        local identity = corpse.name or tostring(corpse.actorId or "Unknown")
        local details = {identity}
        if corpse.unitTypeId then details[#details + 1] = "type " .. tostring(corpse.unitTypeId) end
        if corpse.species then details[#details + 1] = "species " .. tostring(corpse.species) end
        if corpse.race then details[#details + 1] = "race " .. tostring(corpse.race) end
        if corpse.faction then details[#details + 1] = "faction " .. tostring(corpse.faction) end
        if corpse.factions and #corpse.factions > 0 then
            details[#details + 1] = "affiliations " .. table.concat(corpse.factions, ", ")
        end
        if corpse.deathTime then
            details[#details + 1] = "died " .. formatWorldTime(corpse.deathTime)
        end
        corpseDescriptions[#corpseDescriptions + 1] = table.concat(details, ", ")
    end

    local itemDescriptions = describeItems(site.loot and site.loot.items)
    local position = history.position or {}
    local lines = {
        {text = "Encounter: " .. tostring(history.encounterId or "unknown")},
        {text = "Participants: " .. (#participants > 0 and table.concat(participants, " versus ") or "unknown")},
        {text = "Victor: " .. getVictors(site)},
        {text = string.format("Position: (%.0f, %.0f); recorded %s",
            tonumber(position.x) or 0, tonumber(position.y) or 0,
            formatWorldTime(history.worldTime))}
    }
    if #corpseDescriptions > 0 then
        for _, corpseDescription in ipairs(corpseDescriptions) do
            lines[#lines + 1] = {text = "Corpse: " .. corpseDescription}
        end
    else
        lines[#lines + 1] = {text = "Corpses: none"}
    end

    local itemDescriptions = describeItems(site.loot and site.loot.items)
    if #itemDescriptions > 0 then
        for _, itemDescription in ipairs(itemDescriptions) do
            lines[#lines + 1] = {text = "Cargo: " .. itemDescription}
        end
    else
        lines[#lines + 1] = {text = "Cargo: none"}
    end
    lines[#lines + 1] = {text = "Gold: " .. tostring(site.loot and site.loot.gold or 0)}
    lines[#lines + 1] = {
        text = "The inspection is complete.",
        options = {
            {text = "Return to the battlefield.", action = "battlefield_back"},
            {text = "Leave.", next = "end"}
        }
    }

    return {
        speaker = "Battlefield",
        lines = lines
    }
end

function BattlefieldInteraction.buildUnavailableDialogue(map, siteId, action)
    local site = findSite(map, siteId)
    if not site then
        return buildUnavailableTree("This battlefield site is no longer present.")
    end

    local messages = {
        corpse_loot = "Recovering possessions from corpses is not implemented yet. Nothing has been moved or changed.",
        bury = "Burying the dead is not implemented yet. The battlefield remains unchanged."
    }
    return buildUnavailableTree(messages[action] or "That battlefield action is not available yet.")
end

function BattlefieldInteraction.collectSupplies(map, siteId, playerParty)
    return BattlefieldResourceCollection.collect(map, siteId, playerParty)
end

function BattlefieldInteraction.buildCollectionDialogue(result)
    local lines = {}
    if not result.success then
        local message = "The supplies could not be collected because the party is unavailable."
        if result.reason == "site_missing" then
            message = "This battlefield site is no longer present."
        elseif result.reason == "site_not_discovered" then
            message = "This battlefield has not been discovered."
        end
        lines[1] = {text = message}
    elseif not result.collected then
        lines[1] = {text = "No supplies remain at this battlefield."}
    else
        lines[1] = {text = "You search the battlefield and recover:"}
        for _, item in ipairs(result.items) do
            local name = item.name or item.id or "Unknown supply"
            lines[#lines + 1] = {
                text = tostring(name) .. " x" .. tostring(item.quantity or 1)
            }
        end
        if result.gold > 0 then
            lines[#lines + 1] = {text = tostring(result.gold) .. " gold"}
        end
    end
    lines[#lines + 1] = {
        text = "The battlefield remains unchanged otherwise.",
        options = {
            {text = "Return to the battlefield.", action = "battlefield_back"},
            {text = "Leave.", next = "end"}
        }
    }
    return {speaker = "Battlefield", lines = lines}
end

return BattlefieldInteraction
