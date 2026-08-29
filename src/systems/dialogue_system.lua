-- systems/dialogue_system.lua
-- Dialogue variable store, conditions, and mutations.
-- Keeps dialogue-scoped flags separate from quest/relationship state.
--
-- Usage in dialogue data:
--   set = { "talked_about_ruins", gold = "gold - 50" }
-- Conditions in dialogue options:
--   if = "talked_about_ruins"     (checks if flag is truthy)
--   if = "gold >= 100"            (checks a numeric condition)

local GameContext = require("src.game.game_context")

local DialogueSystem = {}

--- Ensure the dialogue flags table exists.
local function ensureStore()
    GameContext.data.dialogueFlags = GameContext.data.dialogueFlags or {}
    return GameContext.data.dialogueFlags
end

--- Get a dialogue flag value.
function DialogueSystem.getFlag(key)
    local store = ensureStore()
    return store[key]
end

--- Set a dialogue flag to a value.
function DialogueSystem.setFlag(key, value)
    local store = ensureStore()
    store[key] = value
end

--- Evaluate a simple condition string like "talked_about_ruins" or "gold >= 100".
-- Returns true if the condition passes (or is empty).
function DialogueSystem.evaluateCondition(condition)
    if not condition or condition == "" then
        return true
    end

    -- Try parsing "key op value" pattern
    local key, op, expected = condition:match("^(%S+)%s*(>=?|<=?|==|~=)%s*(.+)$")
    if key and op and expected then
        -- Resolve the left side (could be a flag or a game value)
        local actual
        if key == "gold" then
            local playerParty = GameContext.data.playerParty
            actual = playerParty and playerParty:getTreasury() or 0
        elseif key == "favor" then
            actual = GameContext.data.favor or 0
        else
            actual = DialogueSystem.getFlag(key) or 0
        end

        local numExpected = tonumber(expected)
        if numExpected ~= nil then
            if op == ">=" then return actual >= numExpected end
            if op == ">"  then return actual >  numExpected end
            if op == "<=" then return actual <= numExpected end
            if op == "<"  then return actual <  numExpected end
            if op == "==" then return actual == numExpected end
            if op == "~=" then return actual ~= numExpected end
        end
        return actual == expected
    end

    -- Plain key: treat as boolean check
    return not not DialogueSystem.getFlag(condition)
end

--- Apply a set of mutations from a `set` table.
-- Supports:
--   set = { "flag_name" }              -- sets flag_name = true
--   set = { flag_name = true }         -- sets flag_name = true
--   set = { gold = "gold - 50" }       -- subtracts 50 from party gold
--   set = { favor = "favor + 10" }     -- adds to favor
function DialogueSystem.applySet(setTable)
    if not setTable then return end

    -- Array-style: each element is a flag name to set to true
    if setTable[1] then
        for _, flagName in ipairs(setTable) do
            DialogueSystem.setFlag(flagName, true)
        end
        return
    end

    -- Table-style
    for key, value in pairs(setTable) do
        if type(value) == "string" and type(key) == "string" then
            -- Handle "gold - 50" / "favor + 10" mutations
            local varName, op, amount = value:match("^(%w+)%s*([+%-])%s*(%d+)$")
            if varName and op and amount then
                local numAmount = tonumber(amount)
                if varName == "gold" then
                    local playerParty = GameContext.data.playerParty
                    if playerParty then
                        if op == "-" then
                            playerParty:addTreasury(-numAmount)
                        else
                            playerParty:addTreasury(numAmount)
                        end
                    end
                elseif varName == "favor" then
                    local current = GameContext.data.favor or 0
                    GameContext.data.favor = op == "-" and (current - numAmount) or (current + numAmount)
                end
                -- Also store as a flag
                DialogueSystem.setFlag(key, true)
            else
                DialogueSystem.setFlag(key, value)
            end
        elseif type(value) == "boolean" then
            DialogueSystem.setFlag(key, value)
        end
    end
end

return DialogueSystem
