-- Shared policy lookup. Location identity is independent of what the place supports.
local Definitions = require("src.data.locations.index")
local Rules = {}

function Rules.definition(location)
    return location and Definitions[location.definitionId or location.type]
end

function Rules.canHostCaravan(location)
    local definition = Rules.definition(location)
    return definition ~= nil and definition.rules.caravanStop
end

function Rules.canRecover(location)
    local definition = Rules.definition(location)
    return definition ~= nil and definition.rules.recoveryStop
end

function Rules.recruitmentPool(location)
    local definition = Rules.definition(location)
    return definition and definition.rules.recruitmentPool or "default"
end

return Rules
