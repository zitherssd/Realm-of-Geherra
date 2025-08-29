local battleActions = {
  fireball = {
    name = "Fireball",
    type = "ranged",
    targeting = { type = "enemy_unit", range = 4 },
    cooldown = 5.0,
    cost = 0,
    effect = function(user, target)
      -- Example: deal 15 damage to target
      target.health = target.health - 15
      -- TODO: add animation, AoE, etc.
    end
  },
  -- Add more abilities here...
}

return battleActions 