-- Setup module path and world for integration tests
local function initTests()
    package.path = "D:/Projects/Realm-of-Geherra/tests/unit/?/init.lua;D:/Projects/Realm-of-Geherra/src/?.lua;D:/Projects/Realm-of-Geherra/?.lua;" .. package.path
    require("src.ecs.world")
end
