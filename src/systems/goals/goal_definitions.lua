-- Authoritative goal definitions shared by runtime construction and debug forms.
-- Register new goals/capabilities here; the editor requires no type-specific changes.
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
    local goal = {type = definition.type, priority = definition.priority or spec.priority or 0,
        status = "pending", attempts = 0, retrySeconds = 0}
    assert(finiteNumber(goal.priority), "Goal priority must be finite")
    for _, field in ipairs(spec.fields or {}) do
        if not field.uiOnly and definition[field.key] ~= nil then goal[field.key] = definition[field.key] end
    end
    if spec.validate then spec.validate(goal, definition) end
    return goal
end

Registry.registerCapability("raid", "Raid")
Registry.registerCapability("travel", "Travel")
Registry.registerCapability("roam", "Roam")
Registry.registerCapability("heal", "Heal")
Registry.registerCapability("caravanFormation", "Caravan Formation")
Registry.registerCapability("leadCaravan", "Lead Caravan")

Registry.registerGoal("acquire_gold", {
    label = "Acquire Gold", priority = 0,
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
        assert(finiteNumber(definition.amount) and definition.amount >= 0, "Gold target must be finite and non-negative")
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
    label = "Reach Location", priority = 0,
    description = "Travel requires a reachable walkable route and the Travel capability.",
    fields = {{key = "destinationLocationId", label = "Destination", kind = "location"}},
    validate = function(goal, definition)
        local id = definition.destinationLocationId
        assert(type(id) == "string" or finiteNumber(id), "Location goal requires a stable ID")
    end
})
Registry.registerGoal("rest_and_recover", {
    label = "Rest and Recover", priority = 1000, fields = {},
    description = "Important actors rest and seek healing when needed; party leaders may travel to a settlement."
})
Registry.registerGoal("provide_service", {
    label = "Provide Service", priority = 20, fields = {},
    description = "Important actors offer enabled capabilities (such as Heal) and pursue known service requests."
})
Registry.registerGoal("fulfill_obligation", {
    label = "Fulfill Obligation", priority = 80, managed = true,
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
