-- Authoritative goal definitions shared by runtime construction and debug forms.
-- Register new goals/capabilities here; the editor requires no type-specific changes.
local Importance = require("src.systems.goals.goal_importance")
local Registry = {goals = {}, capabilities = {}}

local function finiteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Registry.registerGoal(id, spec)
    assert(type(id) == "string" and not Registry.goals[id], "Duplicate goal definition")
    spec.id = id
    Registry.goals[id] = spec
end

function Registry.registerCapability(id, label)
    Registry.capabilities[id] = {id = id, label = label}
end

function Registry.list(entries)
    local result = {}
    for _, spec in pairs(entries) do result[#result + 1] = spec end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

function Registry.create(definition)
    assert(type(definition) == "table", "Goal definition must be a table")
    local spec = assert(Registry.goals[definition.type], "Unknown goal type: " .. tostring(definition.type))
    local goal = {type = definition.type, priority = definition.importance or definition.priority or spec.priority or 0,
        status = "pending", attempts = 0, retrySeconds = 0}
    assert(finiteNumber(goal.priority), "Goal priority must be finite")
    for _, field in ipairs(spec.fields or {}) do
        if not field.uiOnly and definition[field.key] ~= nil then goal[field.key] = definition[field.key] end
    end
    if spec.validate then spec.validate(goal, definition) end
    if definition.accumulatedImportance ~= nil then
        assert(finiteNumber(definition.accumulatedImportance), "Accumulated importance must be finite")
        goal.accumulatedImportance = Importance.clamp(definition.accumulatedImportance)
    end
    return goal
end

Registry.registerCapability("raid", "Raid")
Registry.registerCapability("travel", "Travel")
Registry.registerCapability("roam", "Roam")
Registry.registerCapability("heal", "Heal")
Registry.registerCapability("caravanFormation", "Caravan Formation")
Registry.registerCapability("leadCaravan", "Lead Caravan")
Registry.registerCapability("investigate", "Investigate")

Registry.registerGoal("acquire_gold", {
    label = "Acquire Gold", priority = 50, importance = Importance.wealth,
    description = "Raid requires a hostile traveling party and visible targets. Roam can seek targets within an area.",
    fields = {
        {key = "amount", label = "Party treasury target", kind = "number", default = function(party) return party.treasury + 100 end},
        {key = "roam", label = "Configure roaming area", kind = "boolean", uiOnly = true},
        {key = "originX", label = "Roam origin X", kind = "number", uiOnly = true, when = "roam", default = function(party) return party.x end},
        {key = "originY", label = "Roam origin Y", kind = "number", uiOnly = true, when = "roam", default = function(party) return party.y end},
        {key = "radius", label = "Roam radius", kind = "number", uiOnly = true, when = "roam", default = 300},
        {key = "durationSeconds", label = "Roam duration in world seconds (blank: unlimited)", kind = "number", optional = true, uiOnly = true, when = "roam"}
    },
    validate = function(goal, definition)
        goal.amount = definition.amount or 10000
        assert(finiteNumber(goal.amount) and goal.amount >= 0, "Gold target must be finite and non-negative")
        if definition.roam then
            local roam = definition.roam
            assert(type(roam) == "table" and finiteNumber(roam.radius) and roam.radius > 0,
                "Roaming requires a positive radius")
            assert((roam.originLocationId ~= nil and roam.originX == nil and roam.originY == nil
                and (type(roam.originLocationId) == "string" or finiteNumber(roam.originLocationId)))
                or (roam.originLocationId == nil and finiteNumber(roam.originX) and finiteNumber(roam.originY)),
                "Roaming requires coordinates or a location ID")
            assert(roam.durationSeconds == nil or (finiteNumber(roam.durationSeconds) and roam.durationSeconds > 0),
                "Roaming duration must be positive")
            goal.roam = {originX = roam.originX, originY = roam.originY,
                originLocationId = roam.originLocationId, radius = roam.radius, durationSeconds = roam.durationSeconds}
        end
    end,
    readForm = function(form, goal, party, resolve)
        local roam = goal.roam or {}
        local origin = roam.originLocationId and resolve(roam.originLocationId)
        form.roam = goal.roam ~= nil
        form.originX = tostring(roam.originX or (origin and origin.x) or party.x)
        form.originY = tostring(roam.originY or (origin and origin.y) or party.y)
        form.radius = tostring(roam.radius or 300)
        form.durationSeconds = tostring(roam.durationSeconds or "")
    end,
    writeForm = function(definition, form)
        if form.roam then
            definition.roam = {originX = tonumber(form.originX), originY = tonumber(form.originY),
                radius = tonumber(form.radius), durationSeconds = tonumber(form.durationSeconds)}
            assert(form.durationSeconds == nil or form.durationSeconds == "" or definition.roam.durationSeconds,
                "Roam duration must be a number, or blank")
        end
    end
})
Registry.registerGoal("reach_location", {
    label = "Reach Location", priority = 40,
    description = "Travel requires a reachable walkable route and the Travel capability.",
    fields = {{key = "destinationLocationId", label = "Destination", kind = "location"}},
    validate = function(goal, definition)
        local id = definition.destinationLocationId
        assert(type(id) == "string" or finiteNumber(id), "Location goal requires a stable ID")
    end
})
local knowledgeCategories = {"time", "location", "participants", "outcome", "party", "destination",
    "sponsorship", "trade", "employer", "service"}
local knowledgeFields = {
    {key = "caravanFate", label = "Require confirmed caravan fate", kind = "boolean"},
    {key = "caravanDepartureAt", label = "Caravan departure (world seconds, optional)", kind = "number", optional = true},
    {key = "subjectType", label = "Subject type (party/actor/location/battlefield/service)", kind = "string", uiOnly = true},
    {key = "subjectId", label = "Historical subject ID (blank for event only)", kind = "string", uiOnly = true},
    {key = "eventId", label = "Known event ID (optional)", kind = "string"},
    {key = "eventType", label = "Event type (optional)", kind = "string"}
}
for _, category in ipairs(knowledgeCategories) do
    knowledgeFields[#knowledgeFields + 1] = {key = category, label = "Require " .. category,
        kind = "boolean", uiOnly = true}
end
Registry.registerGoal("acquire_knowledge", {
    label = "Acquire Knowledge", priority = 90, importance = Importance.knowledge, fields = knowledgeFields,
    description = "Wait for learned historical information. Location means historical position, not current whereabouts.",
    validate = function(goal, definition)
        assert(goal.caravanFate == nil or type(goal.caravanFate) == "boolean", "Invalid caravan fate flag")
        assert(goal.caravanDepartureAt == nil or (finiteNumber(goal.caravanDepartureAt) and goal.caravanDepartureAt >= 0),
            "Invalid caravan departure time")
        for _, key in ipairs({"eventId", "eventType"}) do
            if goal[key] == "" then goal[key] = nil end
            assert(goal[key] == nil or type(goal[key]) == "string", "Knowledge event IDs/types must be strings")
        end
        local subject = definition.subject
        assert(subject or goal.eventId, "Knowledge requires a subject or known event ID")
        if subject then
            assert(type(subject) == "table" and ({party = true, actor = true, location = true,
                battlefield = true, service = true})[subject.type], "Invalid knowledge subject type")
            assert((type(subject.id) == "string" and subject.id ~= "") or finiteNumber(subject.id),
                "Knowledge requires a historical subject ID")
            goal.subject = {type = subject.type, id = subject.id}
        end
        assert(not goal.caravanFate or (goal.subject and goal.subject.type == "party"), "Caravan fate requires a party subject")
        assert(type(definition.requiredDetails) == "table" and next(definition.requiredDetails),
            "Knowledge requires explicit detail categories")
        goal.requiredDetails = {}
        for category, required in pairs(definition.requiredDetails) do
            local allowed = false
            for _, known in ipairs(knowledgeCategories) do if known == category then allowed = true end end
            assert(allowed and required == true, "Invalid required knowledge category: " .. tostring(category))
            goal.requiredDetails[category] = true
        end
    end,
    readForm = function(form, goal)
        form.subjectType = goal.subject and goal.subject.type or "party"
        form.subjectId = goal.subject and tostring(goal.subject.id) or ""
        for _, category in ipairs(knowledgeCategories) do
            form[category] = goal.requiredDetails and goal.requiredDetails[category] == true or false
        end
    end,
    writeForm = function(definition, form)
        if form.subjectId and form.subjectId ~= "" then
            definition.subject = {type = form.subjectType, id = form.subjectId}
        end
        definition.requiredDetails = {}
        for _, category in ipairs(knowledgeCategories) do
            if form[category] then definition.requiredDetails[category] = true end
        end
    end
})
Registry.registerGoal("rest_and_recover", {
    label = "Rest and Recover", priority = 0, importance = Importance.recovery, fields = {},
    description = "Important actors rest and seek healing when needed; party leaders may travel to a settlement."
})
Registry.registerGoal("provide_service", {
    label = "Provide Service", priority = 20, fields = {},
    description = "Important actors offer enabled capabilities (such as Heal) and pursue known service requests."
})
Registry.registerGoal("fulfill_obligation", {
    label = "Fulfill Obligation", priority = 70, importance = Importance.obligation, managed = true,
    description = "Created by accepting a service request. Complete or cancel the service through the service system.",
    fields = {{key = "serviceId", label = "Accepted service ID", kind = "string"}},
    validate = function(goal, definition)
        assert(type(definition.serviceId) == "string", "Obligation requires a service ID")
    end
})

function Registry.form(goal, party, resolve)
    local spec = assert(Registry.goals[goal.type], "Unknown goal type")
    local form = {type = goal.type, priority = tostring(goal.priority or spec.priority or 0)}
    for _, field in ipairs(spec.fields or {}) do
        local value = goal[field.key]
        if value == nil then
            if type(field.default) == "function" then value = field.default(party)
            else value = field.default end
        end
        if field.kind == "boolean" then form[field.key] = value == true
        elseif field.kind == "location" then form[field.key] = value
        else form[field.key] = value ~= nil and tostring(value) or "" end
    end
    if spec.readForm then spec.readForm(form, goal, party, resolve) end
    return form
end

function Registry.definition(form, resolve)
    local spec = assert(Registry.goals[form.type], "Choose a registered goal")
    assert(not spec.managed, spec.label .. " is managed by the service system")
    local definition = {type = form.type, priority = tonumber(form.priority)}
    assert(finiteNumber(definition.priority), "Priority must be a finite number")
    for _, field in ipairs(spec.fields or {}) do
        if not field.uiOnly and (not field.when or form[field.when]) then
            local value = form[field.key]
            if field.kind == "number" then
                value = tonumber(value)
                assert((field.optional and (form[field.key] == "" or form[field.key] == nil)) or finiteNumber(value),
                    field.label .. " must be a finite number")
            elseif field.kind == "location" then
                assert(resolve(value), "Choose an existing destination on this map")
            end
            definition[field.key] = value
        end
    end
    if spec.writeForm then spec.writeForm(definition, form) end
    Registry.create(definition) -- Validate before cancelling activities.
    return definition
end

return Registry
