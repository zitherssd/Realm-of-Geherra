local UnitModule = {}
local unitTemplates = require('src.data.unit_templates')
local unitAnimations = require('src.data.unit_animations')

local nextUnitId = 1

function UnitModule.create(templateName)
  local tpl = unitTemplates[templateName]
  if not tpl then error('Unknown unit template: ' .. tostring(templateName)) end
  local unit = {
    id = 'unit_' .. nextUnitId,
    template = templateName,
    name = tpl.name,
    attack = tpl.attack,
    defense = tpl.defense,
    strength = tpl.strength,
    protection = tpl.protection,
    morale = tpl.morale,
    health = tpl.health,
    speed = tpl.speed,
    equipmentSlots = tpl.equipmentSlots,
    equipment = {},
    abilities = tpl.abilities,
    -- For drawing/animation
    bodySprite = tpl.bodySprite,
    headSprite = tpl.headSprite,
    animation = 'idle',
    animationFrame = 1,
  }
  nextUnitId = nextUnitId + 1
  return unit
end

function UnitModule.draw(unit, x, y)
  local animName = unit.animation or 'idle'
  local frame = unit.animationFrame or 1
  local anim = unitAnimations[animName] and unitAnimations[animName][frame] or nil
  if not anim then anim = unitAnimations['idle'][1] end
  -- Draw body
  if unit.bodySprite then
    love.graphics.draw(unit.bodySprite, x + anim.body.x, y + anim.body.y, anim.body.r, anim.body.sx, anim.body.sy)
  end
  -- Draw armor (if any, as overlay)
  if unit.equipment.chest and unit.equipment.chest.sprite then
    love.graphics.draw(unit.equipment.chest.sprite, x + anim.body.x, y + anim.body.y, anim.body.r, anim.body.sx, anim.body.sy)
  end
  -- Draw head
  if unit.headSprite then
    love.graphics.draw(unit.headSprite, x + anim.head.x, y + anim.head.y, anim.head.r, anim.head.sx, anim.head.sy)
  end
  -- Draw helmet (if any)
  if unit.equipment.head and unit.equipment.head.sprite then
    love.graphics.draw(unit.equipment.head.sprite, x + anim.head.x, y + anim.head.y, anim.head.r, anim.head.sx, anim.head.sy)
  end
  -- Draw main hand (weapon)
  if unit.equipment.main_hand and unit.equipment.main_hand.sprite then
    love.graphics.draw(unit.equipment.main_hand.sprite, x + anim.main_hand.x, y + anim.main_hand.y, anim.main_hand.r, anim.main_hand.sx, anim.main_hand.sy)
  end
  -- Draw off hand (weapon/shield)
  if unit.equipment.off_hand and unit.equipment.off_hand.sprite then
    love.graphics.draw(unit.equipment.off_hand.sprite, x + anim.off_hand.x, y + anim.off_hand.y, anim.off_hand.r, anim.off_hand.sx, anim.off_hand.sy)
  end
end

return UnitModule 