local unit_types = {
  human = {
    name = "Human",
    base_sprite = "assets/sprites/units/human_base.png",
    head_sprite = "assets/sprites/units/human_head.png",
    hair_types = {
      "assets/sprites/units/hair_short.png",
      "assets/sprites/units/hair_long.png",
      "assets/sprites/units/hair_bald.png",
    },
    equipment_layers = {
      body = true,   -- draw armor/clothes on top of base
      head = true,   -- draw helmets/hats on top of head
    },
    -- Optionally, animation frames, skin color options, etc.
  },
  -- dragon = { ... }, -- for future
}

return unit_types 