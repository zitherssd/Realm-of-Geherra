-- entities/entity.lua
-- Base entity schema for all game objects

local Entity = {}
Entity.__index = Entity

function Entity.new(id, entityType)
    local self = setmetatable({}, Entity)
    self.id = id
    self.type = entityType or "entity"
    self.tags = {}
    self.data = {}
    self.x = 0
    self.y = 0
    return self
end

function Entity:addTag(tag)
    self.tags[tag] = true
end

function Entity:removeTag(tag)
    self.tags[tag] = nil
end

function Entity:hasTag(tag)
    return self.tags[tag] or false
end

function Entity:setData(key, value)
    self.data[key] = value
end

function Entity:getData(key)
    return self.data[key]
end

function Entity:setPosition(x, y)
    self.x = x
    self.y = y
end

function Entity:getPosition()
    return self.x, self.y
end

return Entity
