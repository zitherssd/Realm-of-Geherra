# BATTLE_FILE_LAYOUT.md

This document proposes a **battle module file layout**.

All battle systems live under `/battle`.

---

## Suggested Files

/battle

* battle_scene.lua           — battle orchestration (input + draw)
* battle_state.lua           — battle state container
* battle_map.lua             — grid + terrain (existing)
* battle_grid.lua            — stacking + cell occupancy (new)
* battle_rules.lua           — action resolution (existing)
* battle_system.lua          — battle state orchestration
* battle_camera.lua          — camera follow/clamp
* battle_renderer.lua        — draw grid/units
* battle_ai.lua              — battle AI behaviors
* battle_actions.lua         — action helpers
* battle_animation.lua       — sprite animation helpers

/systems

* stat_system.lua            — effective stats aggregation

---

## Related Docs

* `BATTLE_SCENE.md`
* `BATTLE_FLOW.md`
* `BATTLE_GRID.md`
* `BATTLE_RENDERING.md`
* `BATTLE_CAMERA.md`
* `BATTLE_AI.md`
* `BATTLE_ACTIONS.md`
* `STAT_SYSTEM.md`
