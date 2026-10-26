-- One session-wide switch for development tools. Disabled on startup.
local Mode = {enabled = false}

function Mode.toggle()
    Mode.enabled = not Mode.enabled
    return Mode.enabled
end

function Mode.isDebugActor(actor)
    return actor and (actor.debugOnly or actor.troopType == "debug_trader") or false
end

return Mode
