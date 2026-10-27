-- Accepts ONLY filtered KnowledgeSystem views; never resolves live identities.
local Text = {}

function Text.describe(event)
    local labels = {battle_ended = "Battle occurred", party_departed = "Party departed", party_arrived = "Party arrived"}
    local parts = {labels[event.type] or ("Event: " .. event.type)}
    if event.partyId then parts[#parts + 1] = "party: " .. (event.partyName or tostring(event.partyId)) end
    if event.originLocationId then
        parts[#parts + 1] = "origin: " .. (event.originLocationName or tostring(event.originLocationId))
    end
    if event.destinationLocationId then
        parts[#parts + 1] = "destination: " .. (event.destinationLocationName or tostring(event.destinationLocationId))
    end
    if event.serviceId then parts[#parts + 1] = "service: " .. event.serviceId .. " / " .. (event.serviceType or "unknown") end
    if event.requiredCapability then parts[#parts + 1] = "requires: " .. event.requiredCapability end
    if event.employerId then parts[#parts + 1] = "employer: " .. (event.employerName or tostring(event.employerId)) end
    if event.locationId then parts[#parts + 1] = "location: " .. (event.locationName or tostring(event.locationId)) end
    if event.status then parts[#parts + 1] = "status: " .. event.status end
    if event.sponsorId then parts[#parts + 1] = "sponsor: " .. (event.sponsorName or tostring(event.sponsorId)) end
    if event.expectedReturnAt then parts[#parts + 1] = "expected return: " .. tostring(event.expectedReturnAt) .. " world seconds" end
    if event.profit then parts[#parts + 1] = "trading gain: " .. event.profit .. " gold" end
    if event.time then parts[#parts + 1] = string.format("day %d, %.2fh", event.time.day, event.time.hour) end
    if event.x and event.y then parts[#parts + 1] = string.format("at %.1f, %.1f", event.x, event.y) end
    if event.battlefieldId then parts[#parts + 1] = "historical battlefield " .. event.battlefieldId end
    if event.participants then
        local names = {}
        for _, participant in ipairs(event.participants) do
            names[#names + 1] = participant.name or tostring(participant.partyId)
        end
        parts[#parts + 1] = "participants: " .. table.concat(names, ", ")
    end
    if event.outcome then parts[#parts + 1] = "outcome: " .. event.outcome end
    if event.winnerPartyId then parts[#parts + 1] = "winner: " .. event.winnerPartyId end
    if event.defeatedPartyIds and #event.defeatedPartyIds > 0 then
        parts[#parts + 1] = "defeated: " .. table.concat(event.defeatedPartyIds, ", ")
    end
    if event.eliminatedPartyIds and #event.eliminatedPartyIds > 0 then
        parts[#parts + 1] = "eliminated: " .. table.concat(event.eliminatedPartyIds, ", ")
    end
    local losses = {}
    for id, count in pairs(event.casualties or {}) do losses[#losses + 1] = id .. ": " .. count end
    table.sort(losses)
    if #losses > 0 then parts[#parts + 1] = "casualties: " .. table.concat(losses, ", ") end
    return table.concat(parts, " | ")
end

return Text
