local Registry = require("src.data.definition_registry")
local Scenario = {}

local function fails(fn, message)
    local ok, err = pcall(fn)
    assert(not ok and tostring(err):find(message, 1, true), "Expected " .. message .. ", got " .. tostring(err))
end

local function catalogIds()
    Registry.checkId("fixture", "matching", {id = "matching"})
    for _, definition in ipairs({{}, {id = "different"}, false}) do
        fails(function() Registry.checkId("fixture", "matching", definition) end, "Invalid fixture ID: matching")
    end

    -- Reload each catalog to check every entry passes through the shared boundary.
    for _, case in ipairs({
        {"src.data.items", "item"}, {"src.data.troops", "troop"},
        {"src.data.dialogue", "dialogue"}, {"src.data.skills", "skill"}, {"src.data.quests", "quest"}
    }) do
        local module, kind = case[1], case[2]
        local previous, checkId, checked = package.loaded[module], Registry.checkId, {}
        Registry.checkId = function(entryKind, id, definition)
            checkId(entryKind, id, definition)
            if entryKind == kind then checked[id] = definition end
        end
        package.loaded[module] = nil
        local ok, catalog = pcall(require, module)
        Registry.checkId = checkId
        package.loaded[module] = previous
        assert(ok, catalog)
        for id, definition in pairs(catalog) do
            assert(checked[id] == definition, module .. " did not validate " .. id)
        end
    end

    -- Malformed imported definitions must fail before an aggregate can be used.
    for _, case in ipairs({
        {"src.data.items", "src.data.items.quest_items", "sealed_message", "item"},
        {"src.data.troops", "src.data.units.neutral.neutral_units", "soldier", "troop"},
        {"src.data.dialogue", "src.data.dialogues.elder", "elder_intro", "dialogue"}
    }) do
        local module, source, id, kind = unpack(case)
        local previous, definition = package.loaded[module], require(source)[id]
        local originalId = definition.id
        for _, badId in ipairs({false, "different"}) do
            if badId == false then definition.id = nil else definition.id = badId end
            package.loaded[module] = nil
            local ok, err = pcall(require, module)
            definition.id, package.loaded[module] = originalId, previous
            assert(not ok and tostring(err):find("Invalid " .. kind .. " ID: " .. id, 1, true),
                module .. " accepted a missing or mismatched ID: " .. tostring(err))
        end
    end
end

local function elderIntroduction()
    local Ecs = require("src.ecs.world")
    local Game = require("src.game.game_context")
    local Factory = require("src.systems.population.npc_factory")
    local Dialogue = require("src.game.states.dialogue_state")
    local UI = require("src.ui.ui_manager")
    local world = Ecs.init()
    Game.init()
    for _, name in ipairs({"Theron the Elder", "Ion the Elder"}) do
        local elder = Factory.create(world, "elder", {seed = 42}, {name = name})
        Dialogue.enter({target = elder, dialogueId = "elder_intro"})
        local screen = UI.getActiveScreen()
        assert(screen.dialogueTree.speaker == elder.name, "Introduction lost the actor's actual identity")
        assert(screen.lines[1].text == "I am the elder of this hearth. Name yourself.",
            "Shared introduction must identify the role without claiming a fixed personal name")
        local introduction
        for _, option in ipairs(screen.lines[1].options) do
            if option.action == "meet_npc" then introduction = option end
        end
        assert(introduction, "Introduction no longer establishes the relationship")
        Dialogue.exit()
    end
end

function Scenario.run()
    catalogIds()
    elderIntroduction()
end

return Scenario
