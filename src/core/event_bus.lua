-- core/event_bus.lua
-- Decoupled event dispatch system

local EventBus = {}

local listeners = {}

function EventBus.init()
    listeners = {}
end

function EventBus.subscribe(eventName, callback)
    if not listeners[eventName] then
        listeners[eventName] = {}
    end
    table.insert(listeners[eventName], callback)
end

function EventBus.unsubscribe(eventName, callback)
    if not listeners[eventName] then return end
    
    for i, cb in ipairs(listeners[eventName]) do
        if cb == callback then
            table.remove(listeners[eventName], i)
            break
        end
    end
end

function EventBus.emit(eventName, ...)
    if not listeners[eventName] then return end

    local callbacks = {}
    for i, callback in ipairs(listeners[eventName]) do
        callbacks[i] = callback
    end

    for _, callback in ipairs(callbacks) do
        local ok, err = pcall(callback, ...)
        if not ok then
            print(string.format("EventBus error on '%s': %s", tostring(eventName), tostring(err)))
        end
    end
end

return EventBus
