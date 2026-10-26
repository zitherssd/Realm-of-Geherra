# Debug mode

Press **F1** to toggle debug mode anywhere in the game. It starts disabled and lasts for
the current application session. Holding F1 does not repeatedly toggle it.

On the world map, debug mode shows the existing interaction, profile and sight rings,
party activity labels, and biome/speed information. In battle it enables collision circles.
The Merchant of Everything and its world-map viewer are available while debug is enabled.
Disabling debug closes debug tools and any open debug merchant/viewer screens. Configured
NPC goals remain part of the running campaign after tools are closed.

## Right-click tools

Right-click a party or a discovered location marker to open its debug menu. When markers
overlap, the menu offers actions for each hit entity. Hit testing uses screen pixels so it
continues to match the markers at different camera zoom levels.

- **Inspect party:** a live, scrollable view of identity, leader, position, resources,
  sight/profile, activity, encounter reservation, goals, capabilities, retries, outcomes,
  actors and cargo.
- **Inspect location:** identity, type, faction/owner, population, prosperity, road-site ID,
  residents and stationed parties. Click a stationed party's button to inspect that party.
- **Configure leader goal:** configure one Acquire Gold or Reach Location goal, its priority,
  and explicit Raid/Travel capabilities. Reach Location provides a list of map destinations.
  Click a numeric field to replace its value; Tab changes fields, and Ctrl+A selects the value.

**Apply - replace leader goals** replaces the selected leader's entire goal list with the
edited goal and stops its previous activity through the campaign APIs. Invalid input leaves
existing work unchanged. An encounter must finish before its participant's goals can be edited.
The player party, missing/dead leaders, removed entities and changed leadership are rejected.
Normal activity cooldowns remain in force after applying a replacement.

Menus and goal editors pause world input/time. The inspector does not: hold **Space** to wait
and watch the selected NPC's state change. Scroll with the mouse over the panel. **Esc** or
the panel's **X** closes it; a click outside a dropdown dismisses the dropdown. F1 closes all
world debug panels when toggled off.

Raid still requires a hostile traveling party and an eligible visible target. Travel still
requires a connected road route. Debug editing does not bypass these rules or supply resources.

## Extending the tools

- `src/debug/mode.lua` owns the shared enable flag. New debug features should respect it.
- `src/debug/campaign_tools.lua` resolves IDs and validates debug actions before calling
  normal campaign systems. UI state stores IDs instead of retaining campaign entity references.
- `src/debug/inspector.lua` supplies inspection text without changing campaign state.
- `src/ui/screens/debug_overlay.lua` owns menus, form input and rendering, using the existing
  button styling. Add further context actions here and keep their behavior in the tool/system layer.

The old console command parser and profiler scaffolding are not active tools; this change does
not add an executable Lua console. The existing external debugger workflow remains available.

Verification uses `tests/unit/debug_mode_scenario.lua` in the existing LÖVE scenario suite.
