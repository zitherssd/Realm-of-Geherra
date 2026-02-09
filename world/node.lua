-- world/node.lua
-- Travel node or region

local Node = {}

function Node.new(id, name)
    local self = {
        id = id,
        name = name or "Node",
        x = 0,
        y = 0,
        connections = {},
        type = "road"
    }
    return self
end

function Node:connect(nodeId)
    table.insert(self.connections, nodeId)
end

function Node:disconnect(nodeId)
    for i, id in ipairs(self.connections) do
        if id == nodeId then
            table.remove(self.connections, i)
            break
        end
    end
end

function Node:getConnections()
    return self.connections
end

return Node
