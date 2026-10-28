local testDirectory = love.filesystem.getSource():gsub("\\", "/")
local repositoryRoot = testDirectory:gsub("/tests/unit$", "")
package.path = repositoryRoot .. "/?.lua;" ..
    repositoryRoot .. "/?/init.lua;" ..
    testDirectory .. "/?.lua;" ..
    package.path

function love.load(args)
    if args and args[1] == "investigation_scenario" and args[2] and args[2]:match("^%-%-preview") then
        if args[2] == "--preview-smoke" then
            love.errorhandler = function(err) print(debug.traceback(err)); return function() return 1 end end
        end
        require("investigation_scenario").preview(args[3] == "--empty", args[2] == "--preview-smoke")
        return
    end
    if args and args[1] == "caravan_scenario" and (args[2] == "--preview" or args[2] == "--preview-smoke") then
        require("caravan_scenario").preview(args[2] == "--preview-smoke")
        return
    end
    if args and args[1] == "services_scenario" and args[2] == "--preview" then
        require("services_scenario").preview()
        return
    end
    local ok, err = xpcall(function()
        -- Run one existing scenario independently, including past suite failures.
        if args and args[1] and args[1]:match("^[%w_]+_scenario$") then
            require(args[1]).run()
            return
        end
        require("navigation_tests").run()
        require("data_definitions_scenario").run()
        require("faction_identity_scenario").run()
        require("combat_regression_scenario").run()
        require("location_types_scenario").run()
        require("population_scenario").run()
        require("retinue_scenario").run()
        require("inline_party_scenario").run()
        require("debug_campaign_scenario").run()
        require("caravan_scenario").run()
        require("services_scenario").run()
        require("knowledge_scenario").run()
        require("travel_knowledge_scenario").run()
        require("battle_knowledge_scenario").run()
        require("world_events_scenario").run()
        require("world_activity_scenario").run()
        require("npc_goals_scenario").run()
        require("dynamic_importance_scenario").run()
        require("recovery_scenario").run()
        require("raid_visibility_scenario").run()
        require("battle_simulation_scenario").run()
        require("headless_battle_scenario").run()
        require("campaign_battle_result_scenario").run()
        require("campaign_battle_resolution_scenario").run()
        require("world_encounter_scenario").run()
        require("raid_encounter_scenario").run()
        require("world_time_sync_scenario").run()
        require("campaign_runtime_scenario").run()
        require("loot_resolver_scenario").run()
        require("battlefield_remains_scenario").run()
        require("battlefield_interaction_scenario").run()
        require("campaign_architecture_milestone_1_scenario").run()
        require("campaign_identity_milestone_2_scenario").run()
        require("travel_activity_scenario").run()
        require("debug_mode_scenario").run()
        require("roam_activity_scenario").run()
        require("knowledge_search_scenario").run()
        require("investigation_scenario").run()
    end, debug.traceback)

    if not ok then
        print(err)
        love.event.quit(1)
        return
    end

    print(args and args[1] and (args[1] .. " passed")
        or "All 37 scenarios and navigation tests passed, including campaign runtime ordering and lifecycle")
    love.event.quit(0)
end
