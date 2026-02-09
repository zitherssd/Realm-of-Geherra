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
    
    for _, callback in ipairs(listeners[eventName]) do
        callback(...)
    end
end

return EventBus
