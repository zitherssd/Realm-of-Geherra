local IdAllocator = {}
IdAllocator.__index = IdAllocator

local SCHEMA_VERSION = 1

local function identityKey(id)
    return type(id) .. ":" .. tostring(id)
end

local function validateId(id, label)
    local idType = type(id)
    if idType ~= "string" and idType ~= "number" then
        error((label or "ID") .. " must be a string or number", 3)
    end
    if idType == "string" and id == "" then
        error((label or "ID") .. " must not be empty", 3)
    end
    if idType == "number" and
        (id ~= id or id == math.huge or id == -math.huge) then
        error((label or "ID") .. " must be finite", 3)
    end
end

local function updateNamespaceCounter(self, id)
    if type(id) ~= "string" then return end
    local namespace, suffix = id:match("^(.*)_(%d+)$")
    if not namespace or namespace == "" then return end
    local nextId = tonumber(suffix) + 1
    self.nextByNamespace[namespace] = math.max(
        self.nextByNamespace[namespace] or 1,
        nextId
    )
end

local function listSize(list)
    if not list then return 0 end
    return list.size or #list
end

local function eachEntity(world, callback)
    local seen = {}
    local removed = {}
    for _, queueName in ipairs({"__removed", "__backRemoved"}) do
        local queue = world[queueName]
        for index = 1, listSize(queue) do
            removed[queue[index]] = true
        end
    end

    local function visit(list)
        for index = 1, listSize(list) do
            local entity = list[index]
            if entity and not seen[entity] and not removed[entity] then
                seen[entity] = true
                callback(entity)
            end
        end
    end

    if type(world.getEntities) == "function" then
        visit(world:getEntities())
    end
    visit(world.__added)
    visit(world.__backAdded)
end

function IdAllocator.new(state)
    local self = setmetatable({
        nextByNamespace = {},
        usedIds = {}
    }, IdAllocator)

    if state ~= nil then
        if type(state) ~= "table" or state.schemaVersion ~= SCHEMA_VERSION or
            type(state.nextByNamespace) ~= "table" or type(state.usedIds) ~= "table" then
            error("Invalid serialized ID allocator state", 2)
        end

        for namespace, nextId in pairs(state.nextByNamespace) do
            if type(namespace) ~= "string" or namespace == "" or
                type(nextId) ~= "number" or nextId < 1 or nextId % 1 ~= 0 then
                error("Invalid ID allocator namespace counter", 2)
            end
            self.nextByNamespace[namespace] = nextId
        end
        for _, id in ipairs(state.usedIds) do
            validateId(id, "Serialized ID")
            local key = identityKey(id)
            if self.usedIds[key] then
                error("Serialized ID allocator contains duplicate IDs", 2)
            end
            self.usedIds[key] = id
            updateNamespaceCounter(self, id)
        end
    end

    return self
end

function IdAllocator.forWorld(world)
    if type(world) ~= "table" then
        error("An ECS world is required for campaign ID allocation", 2)
    end

    if not world.idAllocator then
        world.idAllocator = IdAllocator.new(world.idAllocatorState)
        world.idAllocatorState = nil
    elseif getmetatable(world.idAllocator) ~= IdAllocator then
        world.idAllocator = IdAllocator.new(world.idAllocator)
    end

    world.idAllocator:registerWorld(world)
    return world.idAllocator
end

function IdAllocator:registerWorld(world)
    if type(world) ~= "table" then
        error("An ECS world is required to register existing IDs", 2)
    end

    local found = {}
    eachEntity(world, function(entity)
        if entity.id ~= nil then
            validateId(entity.id, "Existing entity ID")
            local key = identityKey(entity.id)
            if found[key] and found[key] ~= entity then
                error("Campaign contains duplicate entity ID " .. tostring(entity.id), 2)
            end
            found[key] = entity

            self.usedIds[key] = entity.id
            updateNamespaceCounter(self, entity.id)
        end
    end)
    return self
end

function IdAllocator:allocate(namespace)
    if type(namespace) ~= "string" or not namespace:match("^[%w_]+$") then
        error("ID namespace must contain only letters, digits, and underscores", 2)
    end

    local nextId = self.nextByNamespace[namespace] or 1
    local id
    repeat
        id = namespace .. "_" .. tostring(nextId)
        nextId = nextId + 1
    until not self.usedIds[identityKey(id)]

    self.nextByNamespace[namespace] = nextId
    self.usedIds[identityKey(id)] = id
    return id
end

function IdAllocator:claim(id)
    validateId(id, "Explicit entity ID")
    local key = identityKey(id)
    if self.usedIds[key] ~= nil then
        error("Campaign entity ID is already in use: " .. tostring(id), 2)
    end

    self.usedIds[key] = id
    updateNamespaceCounter(self, id)
    return id
end

function IdAllocator:assertAvailable(id)
    validateId(id, "Explicit entity ID")
    if self.usedIds[identityKey(id)] ~= nil then
        error("Campaign entity ID is already in use: " .. tostring(id), 2)
    end
    return true
end

function IdAllocator:serialize()
    local usedIds = {}
    for _, id in pairs(self.usedIds) do
        usedIds[#usedIds + 1] = id
    end
    table.sort(usedIds, function(left, right)
        if type(left) == type(right) then
            return tostring(left) < tostring(right)
        end
        return type(left) < type(right)
    end)

    local nextByNamespace = {}
    for namespace, nextId in pairs(self.nextByNamespace) do
        nextByNamespace[namespace] = nextId
    end

    return {
        schemaVersion = SCHEMA_VERSION,
        nextByNamespace = nextByNamespace,
        usedIds = usedIds
    }
end

return IdAllocator
