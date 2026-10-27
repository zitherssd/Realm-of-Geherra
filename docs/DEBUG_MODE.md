# Debug mode

For a populated playable world, choose **Debug Campaign** on the main menu or launch
with `--debug-campaign`. See [Debug Campaign](DEBUG_CAMPAIGN.md) for profiles,
starting NPCs, reset instructions and playtests. That campaign starts with debug
tools enabled; ordinary launches retain the behavior below.

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
  actors and cargo. **Inspect NPC: <name>** opens the shared NPC inspector for each
  important NPC with personal memory, plus the party commander. Regular troops are omitted,
  even if they have display names or recovery goals.
- **Inspect location:** identity, type, faction/owner, population, prosperity, road-site ID,
  residents and stationed parties. **Inspect NPC: <name>** opens the same NPC inspector
  for important residents with personal memory. Click a stationed party's button to inspect that party.
- **Inspect NPC:** shows the NPC's present stats, goals, capabilities and personal knowledge.
  **Configure Goal** opens that NPC's goal editor, and **Grant event knowledge** opens their
  personal knowledge editor. NPCs without personal memory are identified in the inspector;
  knowledge grants still require a memory component.
- **Configure Goal** (inside the NPC inspector): browse every implemented goal, add goals, select an assigned
  goal to edit its fields/priority, or remove it. The capability list shows every registered
  capability (Raid, Travel, Roam and Heal), plus any custom flags already assigned to the NPC.
  Reach Location provides a list of map destinations. Click a field to replace its value;
  Tab changes fields, and Ctrl+A selects the value. Changes remain a draft until applied.

**Apply - save all NPC goals and capabilities** replaces the selected NPC's entire goal
list with the draft, resets goal evaluation state and stops its previous activity through the
campaign APIs. An empty list is allowed and suppresses legacy AI. Invalid input in any goal
leaves all existing goals, capabilities and activities unchanged. An encounter must finish
before its participant's goals can be edited. The player party, missing/dead NPCs, removed
entities and changed leadership are rejected. Editing a follower does not stop the party
leader's activity. Applying or cancelling returns to the selected NPC inspector. Independent
residents can also configure goals; normal goal eligibility and activity cooldowns remain in force.

The catalog includes Acquire Gold, Reach Location, Rest and Recover, Provide Service and
Fulfill Obligation. Fulfill Obligation is created by accepting a service request and cannot be
added or edited manually. Accepted obligations block applying replacement goals until the
service is completed or cancelled. Resolved obligation entries can then be removed. Recovery
and service provision still require important actors with memory; enabling Heal does not
make an ordinary troop an important actor.

Roaming area settings belong to each Acquire Gold goal; the Roam capability independently
allows using them. Enable both to seek raid targets through roaming.

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

### Adding goals and capabilities

`src/systems/goal_definitions.lua` is the shared runtime/editor registry. Register a goal
with `registerGoal(id, spec)` and its label, default priority, description and `fields`.
Fields support `number`, `string`, `boolean` and `location`; `default`, `optional` and `when`
control initial values and conditional display. Runtime construction uses the same definition.
Use `validate(goal, definition)` for goal-specific rules. Complex data can use `readForm` /
`writeForm` hooks and `uiOnly` fields, as Acquire Gold does for its nested roaming area.
`managed = true` lists system-owned goals without offering manual creation.

Register implemented capability flags with `registerCapability(id, label)`. Existing custom
flags remain supported. Adding definitions and implementing their runtime behavior requires
no changes to the debug overlay, its keyboard input, or the campaign tools. Lua has no runtime
reflection for local conditional branches; this explicit shared registry keeps discoverable
metadata alongside construction and validation instead of parsing source code.

The old console command parser and profiler scaffolding are not active tools; this change does
not add an executable Lua console. The existing external debugger workflow remains available.

Verification uses `tests/unit/debug_mode_scenario.lua` in the existing LÖVE scenario suite.
