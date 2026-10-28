local Text = {}

function Text.time(time)
    if not time then return "Unknown time" end
    local minutes = math.floor(time.hour * 60 + 1e-7)
    return string.format("Day %d, %02d:%02d", time.day, math.floor(minutes / 60), minutes % 60)
end

function Text.describe(event)
    if event.type == "caravan_returned" then return (event.partyName or event.partyId) .. " returned to its sponsor" end
    if event.type == "party_encounter" then
        return tostring(event.observerPartyId) .. " encountered " .. (event.partyName or event.partyId) .. " alive"
    end
    if event.type == "caravan_traded" then
        return (event.partyName or tostring(event.partyId)) .. " traded: +" .. tostring(event.profit) .. " gold"
    end
    if event.serviceId then
        return (event.employerName or tostring(event.employerId)) .. ": " .. (event.serviceType or "service")
            .. " [" .. event.serviceId .. "] " .. (event.status or event.type)
            .. (event.workerName and (" / " .. event.workerName) or "")
    end
    if event.type == "party_departed" then
        return (event.partyName or tostring(event.partyId)) .. " departed "
            .. (event.originLocationName or tostring(event.originLocationId)) .. " for "
            .. (event.destinationLocationName or tostring(event.destinationLocationId))
            .. (event.expectedReturnAt and (" / expected return " .. tostring(event.expectedReturnAt) .. " world seconds") or "")
    elseif event.type == "party_arrived" then
        return (event.partyName or tostring(event.partyId)) .. " arrived at "
            .. (event.destinationLocationName or tostring(event.destinationLocationId))
    end
    if event.type == "battle_ended" then
        local names, winner, loser = {}, nil, nil
        for _, participant in ipairs(event.participants or {}) do
            local name = participant.name or tostring(participant.partyId)
            names[#names + 1] = name
            if participant.partyId == event.winnerPartyId then winner = name else loser = name end
        end
        if winner and loser then return winner .. " defeated " .. loser end
        return table.concat(names, " fought ") .. " - " .. (event.outcome or "Unknown outcome")
    end
    return type(event.description) == "string" and event.description or event.type or "Details"
end

-- Deterministic, complete plain-data inspection, including future event fields.
function Text.details(event, currentState)
    local lines = currentState and {} or {Text.describe(event), Text.time(event.time), ""}
    local function append(value, prefix)
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b end
            return type(a) < type(b)
        end)
        for _, key in ipairs(keys) do
            local child = value[key]
            if type(child) == "table" then
                lines[#lines + 1] = prefix .. tostring(key) .. ":"
                append(child, prefix .. "  ")
            else
                lines[#lines + 1] = prefix .. tostring(key) .. ": " .. tostring(child)
            end
        end
    end
    append(event, "")
    return table.concat(lines, "\n")
end

return Text
