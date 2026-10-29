local Conditions = require("src.systems.actors.conditions")
local Visuals = {}
local function clamp(value) return math.max(0,math.min(1,value)) end

function Visuals.compose(actor)
    local result = {alpha=1,saturation=1,tint={1,1,1},active=false}
    local entries = Conditions.entries(actor)
    table.sort(entries,function(a,b)
        local ap,bp=(a.definition.visual or {}).priority or 0,(b.definition.visual or {}).priority or 0
        if ap ~= bp then return ap < bp end
        return a.id < b.id
    end)
    for _, item in ipairs(entries) do
        local visual = item.definition.visual
        if visual then
            result.active = true
            result.alpha = result.alpha * (visual.alpha or 1)
            result.saturation = result.saturation * (visual.saturation or 1)
            if visual.tint then
                local weight = clamp(visual.tint[4] or 0.5)
                for i=1,3 do result.tint[i]=result.tint[i]*(1-weight)+clamp(visual.tint[i])*weight end
            end
        end
    end
    result.alpha=clamp(result.alpha)
    result.saturation=math.max(0,result.saturation)
    return result
end
return Visuals
