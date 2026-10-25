local testDirectory = love.filesystem.getSource():gsub("\\", "/")
local repositoryRoot = testDirectory:gsub("/tests/unit$", "")
package.path = repositoryRoot .. "/?.lua;" ..
    repositoryRoot .. "/?/init.lua;" ..
    testDirectory .. "/?.lua;" ..
    package.path

function love.load()
    local ok, err = xpcall(function()
        require("world_activity_scenario").run()
        require("raid_visibility_scenario").run()
        require("battle_simulation_scenario").run()
        require("headless_battle_scenario").run()
        require("campaign_battle_result_scenario").run()
        require("world_encounter_scenario").run()
        require("raid_encounter_scenario").run()
        require("world_time_sync_scenario").run()
        require("loot_resolver_scenario").run()
        require("battlefield_remains_scenario").run()
        require("battlefield_interaction_scenario").run()
    end, debug.traceback)

    if not ok then
        print(err)
        love.event.quit(1)
        return
    end

    print("World activity, Raid visibility, battle simulation, headless battle, campaign result, encounter, loot resolver, battlefield remains, and battlefield interaction scenarios passed")
    love.event.quit(0)
end
