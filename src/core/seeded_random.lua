-- A campaign-local stream; stable string keys isolate one site's population from another.
local Random = {}

function Random.new(seed, key)
    local state = math.floor(seed or 1337) % 4294967296
    for index = 1, #(key or "") do state = (state * 33 + key:byte(index)) % 4294967296 end
    return function(low, high)
        state = (1664525 * state + 1013904223) % 4294967296
        local value = state / 4294967296
        if low == nil then return value end
        if high == nil then low, high = 1, low end
        return low + math.floor(value * (high - low + 1))
    end
end

return Random
