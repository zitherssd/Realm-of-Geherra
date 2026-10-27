local Concord = require("src.libs.concord")

-- Capability-specific actor state, deliberately independent of selected goals.
return Concord.component.new("caravan_formation", function(c)
    c.nextSponsorshipAt = 0
    c.expeditionServiceIds = {}
end)
