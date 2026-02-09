-- utils/serializer.lua
-- Serialization utilities for saving/loading

local Serializer = {}

function Serializer.serialize(data)
    -- Serialize data to JSON-like string
    return require("utils.json").encode(data)
end

function Serializer.deserialize(str)
    -- Deserialize string to data
    return require("utils.json").decode(str)
end

function Serializer.saveToFile(filename, data)
    local content = Serializer.serialize(data)
    love.filesystem.write(filename, content)
end

function Serializer.loadFromFile(filename)
    if not love.filesystem.getInfo(filename) then
        return nil
    end
    local content = love.filesystem.read(filename)
    return Serializer.deserialize(content)
end

return Serializer
