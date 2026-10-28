-- Explicit action IDs, resolved lazily to avoid loading UI/gameplay during data validation.
local Actions = {}
local entries = {}

function Actions.register(id, module, method)
    assert(type(id) == "string" and id ~= "" and not entries[id], "Duplicate/invalid location action ID")
    assert(type(module) == "string" and type(method) == "string", "Action handler needs module/method names")
    entries[id] = {module = module, method = method}
end

function Actions.has(id) return entries[id] ~= nil end

function Actions.resolve(id)
    local entry = assert(entries[id], "Unknown location action: " .. tostring(id))
    local handler = require(entry.module)[entry.method]
    assert(type(handler) == "function", "Missing location action handler: " .. id)
    return handler
end

function Actions.execute(id, location) return Actions.resolve(id)(location) end

function Actions.validateHandlers()
    for id in pairs(entries) do Actions.resolve(id) end
    return true
end

for _, id in ipairs({"startRecruitmentDialogue", "requestAudience", "trainTroops", "pray",
    "exploreRuin", "attackBanditCamp", "rest", "tradeGoods", "buySupplies"}) do
    Actions.register(id, "src.systems.locations.location_actions", id)
end
Actions.register("examineWizardTower", "src.systems.locations.examine_wizard_tower", "execute")
return Actions
