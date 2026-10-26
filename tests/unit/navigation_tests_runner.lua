-- Navigation test runner with explicit exit after completion
local setup = require("_runner_setup")
setup.initTests()

print("Navigation Tests:")
print("===================")
print("")
print("Test 1: Same start and goal...")
local Tests = require("navigation_tests")
local ok, result = xpcall(function()
    Tests.testSameStartAndGoal()
    Tests.testBlockedDestination()
    Tests.testUnreachableGoal()
    Tests.testBlockedStart()
    Tests.testMissingMap()
    Tests.testOutOfBoundsStart()
    Tests.testOutOfBoundsGoal()
    Tests.testNoNavigationGrid()
    Tests.testEmptyResult()
    Tests.testDiagonalMovement()
end, debug.traceback)

if ok then
    print("[PASS] All navigation tests")
else
    print("[FAIL]" .. result)
end

print("")
print("Navigator tests complete.")
return "complete"
