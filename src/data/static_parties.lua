return {
  {
    id = "bandits",
    name = "Bandit Gang",
    position = { x = 200, y = 370 },
    interactions = { "fight", "talk" },
    unitsRaw = {
      { template = "militia", count = 6 }
    }
  },
  {
    id = "dragon_king",
    name = "Dragon King",
    position = { x = 300, y = 460 },
    interactions = { "fight", "talk" },
    unitsRaw = {
      { template = "dragon", count = 1 }
    }
  },
  {
    id = "caravan1",
    name = "Merchant Caravan",
    position = { x = 700, y = 500 },
    interactions = { "trade", "talk" },
    unitsRaw = {
      { template = "militia", count = 2 }
    }
  }
} 