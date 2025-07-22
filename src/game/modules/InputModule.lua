local InputModule = {}

-- Define abstract actions and their default keyboard mappings
local keyMappings = {
  navigate_up    = {'up', 'w'},
  navigate_down  = {'down', 's'},
  navigate_left  = {'left', 'a'},
  navigate_right = {'right', 'd'},
  activate       = {'return', 'kpenter', 'space'},
  cancel         = {'escape'},
  switch_panel_next = {'tab'},
  open_party_screen = {'i'}, -- New action
  camp_menu = {'c'}, -- New action for camping menu
  -- switch_panel_prev will be handled specially for shift+tab
}

function InputModule:isActionDown(action)
  local keys = keyMappings[action] or {}
  for _, key in ipairs(keys) do
    if love.keyboard.isDown(key) then return true end
  end
  return false
end

function InputModule:getMovementDirection()
  local x, y = 0, 0
  if love.keyboard.isDown('left', 'a') then x = x - 1 end
  if love.keyboard.isDown('right', 'd') then x = x + 1 end
  if love.keyboard.isDown('up', 'w') then y = y - 1 end
  if love.keyboard.isDown('down', 's') then y = y + 1 end
  return x, y
end

-- This can be expanded for gamepad later
function InputModule:handleKeyEvent(key, state)
  if state.onAction then
    -- Special handling for shift+tab as switch_panel_prev
    if key == 'tab' and (love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')) then
      state:onAction('switch_panel_prev')
      return
    end
    for action, keys in pairs(keyMappings) do
      for _, k in ipairs(keys) do
        if k == key then
          state:onAction(action)
          return
        end
      end
    end
  end
end

return InputModule 