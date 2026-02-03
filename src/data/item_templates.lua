local itemTemplates = {
  iron_sword = {
    name = "Iron Sword",
    type = "weapon",
    slot = "main_hand",
    stats = { attack = 1, defense = 1, damage = 5 },
    actions = {
      {
        id = "attack",
        name = "Iron Sword",
        description = "Deal damage to the target",
        cooldownStart = 25,
        cooldownEnd = 25,
      },
      {
        id = "attack2",
        name = "Dagger",
        description = "Deal damage to the target",
        cooldownStart = 0,
        cooldownEnd = 30,
      }
    },
    weight = 3.5,
    value = 50,
    sprite = "sprites/items/iron_sword.png",
  },
  leather_armor = {
    name = "Leather Armor",
    type = "armor",
    slot = "chest",
    stats = { protection = 4 },
    weight = 5.0,
    value = 40,
    sprite = "sprites/items/leather_armor.png",
  },
  bread = {
    name = "Bread",
    type = "food",
    value = 5,
    hungerRestore = 10,
    stackable = true,
    weight = 0.2,
    sprite = "sprites/items/bread.png",
  },
  cheese = {
    name = "Cheese",
    type = "food",
    value = 8,
    hungerRestore = 15,
    stackable = true,
  },
  fish = {
    name = "Fish",
    type = "food",
    value = 3,
    hungerRestore = 8,
    stackable = true,
  },
  fist = {
    name = "Fist",
    type = "weapon",
    range = 1,
    attack_speed = 1.5,
    damage = 5,
    value = 0,
    sprite = nil,
  },
  dagger = {
    name = "Dagger",
    type = "weapon",
    slot = "main_hand",
    stats = { attack = 0, defense = 0, damage = 3 },
    actions = {
      {
        id = "attack",
        name = "Attack",
        description = "Deal damage to the target",
        cooldownStart = 0,
        cooldownEnd = 30,
      }
    },
    weight = 1,
    value = 10,
    sprite = "sprites/items/dagger.png",
  },
}

return itemTemplates 