-- core/location.lua
--
-- Defines the location data structure.

local Location = {}

local REQUIRED_FIELDS = {
    "id",
    "name",
    "type",
    "position",
    "persistent",
}

local function is_non_empty_string(value)
    return type(value) == "string" and value ~= ""
end

local function is_number(value)
    return type(value) == "number"
end

local function validate_position(position, errors)
    if type(position) ~= "table" then
        table.insert(errors, "position must be a table")
        return
    end

    if not is_number(position.x) then
        table.insert(errors, "position.x must be a number")
    end
    if not is_number(position.y) then
        table.insert(errors, "position.y must be a number")
    end
end

local function validate_string_list(field_name, list, errors)
    if list == nil then
        return
    end

    if type(list) ~= "table" then
        table.insert(errors, field_name .. " must be a table when provided")
        return
    end

    for index, value in ipairs(list) do
        if not is_non_empty_string(value) then
            table.insert(errors, field_name .. "[" .. index .. "] must be a non-empty string")
        end
    end
end

local function validate_cooldowns(cooldowns, errors)
    if cooldowns == nil then
        return
    end

    if type(cooldowns) ~= "table" then
        table.insert(errors, "cooldowns must be a table when provided")
        return
    end

    for key, value in pairs(cooldowns) do
        if not is_number(value) then
            table.insert(errors, "cooldowns." .. tostring(key) .. " must be a number")
        end
    end
end

function Location.validate(definition)
    local errors = {}

    if type(definition) ~= "table" then
        return false, { "location definition must be a table" }
    end

    for _, field in ipairs(REQUIRED_FIELDS) do
        if definition[field] == nil then
            table.insert(errors, field .. " is required")
        end
    end

    if not is_non_empty_string(definition.id) then
        table.insert(errors, "id must be a non-empty string")
    end
    if not is_non_empty_string(definition.name) then
        table.insert(errors, "name must be a non-empty string")
    end
    if not is_non_empty_string(definition.type) then
        table.insert(errors, "type must be a non-empty string")
    end

    validate_position(definition.position, errors)

    if type(definition.persistent) ~= "boolean" then
        table.insert(errors, "persistent must be a boolean")
    end

    if definition.faction ~= nil and type(definition.faction) ~= "string" then
        table.insert(errors, "faction must be a string or nil")
    end

    if definition.region ~= nil and type(definition.region) ~= "string" then
        table.insert(errors, "region must be a string when provided")
    end

    if definition.battle_stage ~= nil and type(definition.battle_stage) ~= "string" then
        table.insert(errors, "battle_stage must be a string when provided")
    end

    validate_string_list("recruitment_pool", definition.recruitment_pool, errors)
    validate_string_list("trade_inventory", definition.trade_inventory, errors)
    validate_string_list("interaction_modules", definition.interaction_modules, errors)
    validate_cooldowns(definition.cooldowns, errors)

    return #errors == 0, errors
end

function Location.normalize(definition)
    return {
        id = definition.id,
        name = definition.name,
        type = definition.type,
        faction = definition.faction or nil,
        position = {
            x = definition.position.x,
            y = definition.position.y,
        },
        persistent = definition.persistent,
        recruitment_pool = definition.recruitment_pool or {},
        trade_inventory = definition.trade_inventory or {},
        interaction_modules = definition.interaction_modules or {},
        battle_stage = definition.battle_stage or "",
        region = definition.region or "",
        cooldowns = definition.cooldowns or {},
    }
end

function Location.new(definition)
    local ok, errors = Location.validate(definition)
    if not ok then
        return nil, errors
    end

    return Location.normalize(definition)
end

function Location.build_index(definitions)
    local index = {}
    local errors = {}

    if type(definitions) ~= "table" then
        return nil, { "definitions must be a table" }
    end

    for _, definition in ipairs(definitions) do
        local location, location_errors = Location.new(definition)
        if not location then
            for _, err in ipairs(location_errors) do
                table.insert(errors, err)
            end
        else
            if index[location.id] then
                table.insert(errors, "duplicate location id: " .. location.id)
            else
                index[location.id] = location
            end
        end
    end

    if #errors > 0 then
        return nil, errors
    end

    return index, nil
end

return Location
