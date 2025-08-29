local itemTemplates = {
  iron_sword = {
    name = "Iron Sword",
    type = "weapon",
    slot = "main_hand",
    stats = { attack = 10, speed = -1 },
    weight = 3.5,
    value = 50,
    sprite = "sprites/items/iron_sword.png",
  },
  leather_armor = {
    name = "Leather Armor",
    type = "armor",
    slot = "chest",
    stats = { defense = 4 },
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
}

return itemTemplates 