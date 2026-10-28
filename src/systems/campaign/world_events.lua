-- Campaign history, independent of live world resources and NPC knowledge.
local IdAllocator = require("src.core.id_allocator")
local Events = {}
local stores = setmetatable({}, {__mode = "k"})

local function copy(value, ancestors)
    local kind = type(value)
    if kind == "number" then
        assert(value == value and math.abs(value) ~= math.huge, "Event numbers must be finite")
    elseif kind == "table" then
        assert(getmetatable(value) == nil, "Events require plain tables, not ECS objects")
        ancestors = ancestors or {}
        assert(not ancestors[value], "Event data contains a cycle")
        ancestors[value] = true
        local result = {}
        for key, child in pairs(value) do
            assert(type(key) == "string" or type(key) == "number", "Invalid event key")
            result[copy(key)] = copy(child, ancestors)
        end
        ancestors[value] = nil
        return result
    else
        assert(kind == "nil" or kind == "string" or kind == "boolean", "Event data is not serializable")
    end
    return value
end

local function store(world)
    assert(world, "World events require a campaign world")
    if not stores[world] then stores[world] = {events = {}, byId = {}, sources = {}} end
    return stores[world]
end

-- sourceKey is optional, campaign-scoped idempotency for a historical occurrence.
function Events.record(world, eventType, data, sourceKey)
    assert(type(eventType) == "string" and eventType ~= "", "Event type required")
    assert(sourceKey == nil or type(sourceKey) == "string", "Invalid event source key")
    local state = store(world)
    if sourceKey and state.sources[sourceKey] then return copy(state.byId[state.sources[sourceKey]]) end
    local event = copy(data)
    assert(type(event) == "table" and event.id == nil and event.type == nil, "Reserved event fields")
    assert(type(event.time) == "table" and type(event.time.day) == "number" and
        event.time.day >= 1 and event.time.day % 1 == 0 and type(event.time.hour) == "number" and
        event.time.hour >= 0 and event.time.hour < 24, "Expected campaign day/hour timestamp")
    local allocator = IdAllocator.forWorld(world)
    repeat event.id = allocator:allocate("event") until not state.byId[event.id]
    event.type = eventType
    local index = #state.events + 1
    -- Stable insertion: equal timestamps keep recording order.
    while index > 1 do
        local previous = state.events[index - 1].time
        if previous.day < event.time.day or
            (previous.day == event.time.day and previous.hour <= event.time.hour) then break end
        index = index - 1
    end
    table.insert(state.events, index, event)
    state.byId[event.id] = event
    if sourceKey then state.sources[sourceKey] = event.id end
    return copy(event)
end

function Events.get(world, id) return copy(store(world).byId[id]) end
function Events.getAll(world) return copy(store(world).events) end
function Events.count(world) return #store(world).events end
function Events.getAt(world, index) return copy(store(world).events[index]) end
function Events.getByType(world, eventType)
    local result = {}
    for _, event in ipairs(store(world).events) do
        if event.type == eventType then result[#result + 1] = copy(event) end
    end
    return result
end

-- Integrations declare subjectIds explicitly; avoids guessing IDs from arbitrary strings.
function Events.getBySubject(world, subjectId)
    local result = {}
    for _, event in ipairs(store(world).events) do
        for _, id in ipairs(event.subjectIds or {}) do
            if id == subjectId then result[#result + 1] = copy(event); break end
        end
    end
    return result
end

function Events.serialize(world)
    local state = store(world)
    return copy({schemaVersion = 1, events = state.events, sources = state.sources})
end

return Events
