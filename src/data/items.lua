return {
  {
    id = "longsword",
    name = "Longsword",
    type = "weapon",
    attack = 1,
    defense = 1,
    damage = 5,
    sprite = "items/longsword.png",
    actions = {
      {
        id = "attack",
        name = "Attack",
        description = "Deal damage to the target",
        cooldownStart = 25,
        cooldownEnd = 25,
      }
    }
  },
    {
    id = "dagger",
    name = "Dagger",
    type = "weapon",
    attack = 1,
    defense = 0,
    damage = 3,
    sprite = "items/Dagger.png",
    actions = {
      {
        id = "attack",
        name = "Attack",
        description = "Deal damage to the target",
        cooldownStart = 0,
        cooldownEnd = 30,
      }
    }
  },