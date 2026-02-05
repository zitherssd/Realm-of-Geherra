local UnitTemplateLoader = require('src.data.unit_template_loader')

-- Default/fallback templates
local defaultTemplates = {
  player = {
    name = "Player",
    attack = 18,
    defense = 13,
    strength = 11,
    protection = 8,
    morale = 100,
    health = 50,
    speed = 14,
    sprite = "units/commander.png",
    equipmentSlots = { {
      type = "main_hand",
      item = nil
    }, {
      type = "off_hand",
      item = nil
    }, {
      type = "chest",
      item = nil
    }, {
      type = "head",
      item = nil
    } },
    abilities = {},
    controllable = true,
    commander = true,
  },
  militia = {
    name = "Militia",
    attack = 8,
    defense = 8,
    strength = 7,
    protection = 3,
    morale = 100,
    health = 25,
    speed = 12,
    sprite = "units/milita.png",
    equipmentSlots = { {
      type = "main_hand",
      item = nil
    }, {
      type = "off_hand",
      item = nil
    }, {
      type = "chest",
      item = nil
    } },
    abilities = {},
  },
  peasant = {
    name = "Peasant",
    attack = 8,
    defense = 8,
    strength = 7,
    protection = 3,
    morale = 100,
    health = 25,
    speed = 13,
    sprite = "units/peasant.png",
    equipmentSlots = { {
      type = "main_hand",
      item = "pitchfork"
    }, {
      type = "off_hand",
      item = nil
    }, {
      type = "chest",
      item = nil
    } },
    abilities = {},
  },
  knight = {
    name = "Knight",
    attack = 18,
    defense = 12,
    strength = 14,
    protection = 8,
    morale = 120,
    health = 45,
    speed = 10,
    sprite = "units/heavyinfantry.png",
    equipmentSlots = { {
      type = "main_hand",
      item = nil
    }, {
      type = "off_hand",
      item = nil
    }, {
      type = "chest",
      item = nil
    }, {
      type = "head",
      item = nil
    } },
    abilities = {},
  },
  dragon = {
    name = "Dragon",
    attack = 15,
    defense = 5,
    strength = 30,
    protection = 20,
    morale = 100,
    health = 200,
    speed = 9,
    size = 9,
    sprite = "units/dragon.png",
    innate_actions = {
      "dragon_breath"
    },
    equipmentSlots = { {
      type = "accessory",
      item = nil
    } },
    abilities = {},
    scale = 1
  },
  troll = {
    name = "Troll",
    attack = 13,
    defense = 8,
    strength = 19,
    protection = 12,
    morale = 100,
    health = 70,
    speed = 14,
    size = 9,
    sprite = "units/troll.png",
    equipmentSlots = { "accessory" },
    abilities = {},
    scale = 1
  },
  barbarian_leader = {
    name = "Barbarian Leader",
    attack = 16,
    defense = 14,
    strength = 18,
    protection = 5,
    morale = 100,
    health = 50,
    speed = 15,
    size = 9,
    sprite = "units/barbarian.png",
    equipmentSlots = { {
      type = "main_hand",
      item = nil
    }, {
      type = "off_hand",
      item = nil
    }, {
      type = "chest",
      item = nil
    }, {
      type = "head",
      item = nil
    } },
    abilities = {},
    scale = 1,
    commander = true
  }
}

-- Try to load CSV templates, fall back to defaults if CSV loading fails
local function loadTemplates()
    local success, csvTemplates = pcall(function()
        return UnitTemplateLoader.loadFromCSV("src/data/BaseU.csv")
    end)
    
    if success and csvTemplates then
        -- Merge CSV templates with defaults
        return UnitTemplateLoader.mergeTemplates(defaultTemplates, csvTemplates)
    else
        print("Warning: Could not load CSV templates, using defaults")
        return defaultTemplates
    end
end

return loadTemplates() 