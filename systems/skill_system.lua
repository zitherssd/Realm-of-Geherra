-- systems/skill_system.lua
-- Handle skills, abilities, and their effects

local SkillSystem = {}

function SkillSystem.learnSkill(actor, skillId)
    if not actor.skills then
        actor.skills = {}
    end
    if not actor.skills[skillId] then
        actor.skills[skillId] = {learned = true}
    end
end

function SkillSystem.forgetSkill(actor, skillId)
    if actor.skills then
        actor.skills[skillId] = nil
    end
end

function SkillSystem.hasSkill(actor, skillId)
    return actor.skills and actor.skills[skillId] ~= nil
end

function SkillSystem.getSkillLevel(actor, skillId)
    if not actor.skills or not actor.skills[skillId] then return 0 end
    return actor.skills[skillId].level or 1
end

return SkillSystem
