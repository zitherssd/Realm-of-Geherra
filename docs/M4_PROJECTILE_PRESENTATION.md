# M4 projectile presentation correction

This revision preserves the player's tuned character presentation. It does not repeat the reverted sprite resizing/anchor/tick-only rendering change.

## Root cause and mapping

Physics height and visible sprite height are different units. A Size-3 archer has a 72-pixel physical cylinder, but its 37-pixel image renders at scale 1.3 (48.1 pixels), with the existing feet offset of 12 pixels. `Y - Z` alone therefore puts the physical 64.8-pixel launch height above the visible body.

The new projectile-only conversion derives its coordinates from the existing actor draw:

- `visibleHeight = alphaBoundsHeight * existingActorScale`
- `visibleFeetY = unit.visualY + existingFeetOffset + (alphaBottom - canvasHeight) * existingActorScale`
- `projectileY = visibleFeetY + (projectile.y - unit.y) - projectile.z * visibleHeight / physicalHeight`
- X includes the sprite alpha-center offset, facing, and the actor's existing interpolation displacement.

For the archer at launch this is `Y + 12 - 0.90 * 48.1 = Y - 31.29`, inside the existing upper body, without changing its sprite or its physical launch height.

Flight blends the shooter and intended-target presentation frames over trajectory progress. Progress is clamped only for presentation calibration, so flight beyond the aim point continues. Actual contact effects use the unit struck, including an unintended ally/enemy. Missing image data retains the previous raw XYZ projection. Alpha bounds are cached once per sprite.

This is a rendering conversion, not trajectory correction: flight, aiming RNG, collisions and damage continue using the original XYZ values. The different sprite frames approximate the view between units; collision remains cylindrical rather than per-pixel.

## Changed files

- `src/systems/battle/render_system.lua`: cached sprite measurements and projectile-to-sprite projection. The original projectile interpolation runs toward the converted screen position at the same 15/s rate. Flight glyphs/trails and contact VFX use this frame.
- `src/systems/battle/execution_system.lua`: retain intended/actual unit references and contact Z for presentation only; emit a brief contact ring only on a successful attack roll. Evaded projectiles continue visually with collisions and damage disabled until their original trajectory terminates. A shield-dependent block (attacker would strictly win without the shield bonus) stops the visual and wears the shield. Non-decisive shields take no durability loss. Existing physics and damage calls are untouched.
- `tests/unit/projectile_presentation_scenario.lua`: actual-asset rendering tests and an optional capture.
- `tests/unit/main.lua`: register the scenario.
- `docs/M4_projectile_presentation.png`: visually inspected LÖVE capture with original-size sprites, calibrated launch arrows and an unintended-target contact marker.

Compared against a saved pre-change copy: the actor scale function, entire actor interpolation block, and entire actor draw block (including anchors, feet offset, sorting, status visuals, and health bars) are **byte-for-byte unchanged**. Projectile interpolation remains 15/s and unit interpolation remains 10/s. Launch 0.90, target 0.80, and current arcs are unchanged. No changes to `projectiles.lua`, movement, collision geometry, Precision, or defense/damage formulas.

## Validation

PASS:

- `projectile_presentation_scenario`: archer, slinger, padded Pelasgian sprite, custom-height ogre, dragon, dog, mirrored facing; exact original draw scales/anchors/feet offsets; launch and contact calibration; actual versus intended victim; retained interpolation rates; moving target display displacement; XYZ values unmodified by rendering.
- `projectile_scenario`: M4 physics, aim, collisions, damage, defense, friendly fire, AI and rendered/headless parity.
- `battle_simulation_scenario`: interactive simulation/results.
- `headless_battle_scenario`: headless compatibility.
- `ability_range_preview_scenario`: existing debug rendering.
- `morale_scenario`: morale and debug overlay.
- `git diff --check`.

Reproduce the captured frame from the repository root:

```powershell
$env:GEHERRA_RENDER_PREVIEW = "$PWD/docs/M4_projectile_presentation.png"
& 'C:\Program Files\LOVE\lovec.exe' tests/unit projectile_presentation_scenario
```

Manual follow-up: fire arrows/javelins while units move, then repeat with padded sprites and different creatures. Original unit sizes and feet placement should remain; movement should still ease between ticks. Shots should originate within the rendered upper body, and contact flashes should use the struck unit's displayed pose. Camera zoom applies to both through the existing battle transform.

No manual interactive playthrough or full-suite rerun was performed. A cylindrical hit may still land outside an opaque limb pixel; no per-pixel collision or animation-specific weapon socket was added.


## Shared projectile depth sorting

Units and projectiles now use one draw queue. Unit depth remains its existing interpolated battlefield Y. Projectile ground depth is interpolated at the existing projectile rate (15/s); physical/rendered altitude is deliberately excluded from the depth key. Equal Y uses X and then insertion order for stable ties. Projectile trails draw with their projectile, while hit indicators/explosion VFX remain overlay effects.

The actor/projectile drawing bodies were moved into helpers for the queue without changing actor anchors, feet offset, scales, smoothing, or sprite draw arguments. Presentation regression tests verify projectiles behind, between, and in front of units even when their elevated screen Y is above those units, and retain the existing draw-transform/interpolation checks.

Shield classification uses the original four die results, with no reroll: for a failed attack, `margin + 2 * shieldDefense > 0` means the shield was decisive. A counterfactual tie remains an evade. Tests cover unshielded ties, shielded but non-decisive ties, decisive blocks and shield breakage, harmless continuation, no further attacks, no block/miss hit-circle or splash, and successful-hit circles.
