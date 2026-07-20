# Gridless Battle System Design Note

## Goal

Replace the current tile-based battle model with a continuous, unit-owned collision model where units move freely in world space and only engage when they are within attack range.

This is a structural migration note, not a full implementation. It describes the required architectural changes and the likely effort required to support a War3-style combat feel.

---

## Current State

The existing battle flow is still built around:

- a grid in [game/battle/battle_grid.lua](game/battle/battle_grid.lua)
- tile-based positions on [game/battle/battle_unit.lua](game/battle/battle_unit.lua)
- movement and range checks in [systems/battle/execution_system.lua](systems/battle/execution_system.lua)
- target selection and AI in [systems/battle/decision_system.lua](systems/battle/decision_system.lua)
- screen-space rendering that assumes fixed cell coordinates in [systems/battle/render_system.lua](systems/battle/render_system.lua)

The current model is effectively a turn/step tactical grid battle with discrete cell movement.

---

## Proposed Direction

### Core Idea

The battle loop should stay tick-based, but the movement model should become continuous and directional instead of tile-based.

The refined rule set is:

- every tick, a unit may take at most one action
- if the unit chooses to move, it advances a fixed step in its chosen direction that tick
- the unit’s speed stat determines the cooldown in ticks between movement actions, just as it does now
- a separate movement step size controls how far the unit travels during each movement action
- after that movement step, the unit enters its cooldown just like today
- attacks and skills still resolve on the same tick cadence, with windup/cooldown behavior preserved

This keeps the current combat rhythm intact while making the motion feel more organic.

### Refined Movement Contract

- units own their own circle collider in world space
- movement is resolved as a short, fixed-length step per tick
- a unit can move toward a target point, an enemy, or a chosen direction
- each unit has a movement step size that is independent from its action cooldown
- if a move would overlap another unit, the units are nudged apart slightly rather than fully blocking one another
- this produces a gentle push effect rather than a hard physics simulation

For the first pass, circles are still the right choice because they are:

- simpler to reason about
- cheaper to test for overlap and range
- easy to integrate into a tick-step movement rule

### Desired Behavior

- units move in small steps each tick rather than snapping between cells
- attack range is checked by distance, not tile adjacency
- attack range includes the units’ collision radii
- units stop once they are within attack reach
- nearby units gently push one another while moving, creating a more natural battlefield feel

This preserves the current tick cadence while moving the combat system toward a more action-oriented model.

---

## Architectural Changes Required

### 1. Replace the battle grid with a spatial context

The current [game/battle/battle_context.lua](game/battle/battle_context.lua) stores a grid object and uses it for occupancy. That should be replaced with a lighter battle context that contains:

- unit list
- world bounds
- optional navigation data
- temporary battle state

Suggested fields:

```lua
BattleContext.data = {
    units = {},
    unitList = {},
    bounds = {width = 1600, height = 900},
    paused = false,
    playerCommand = nil,
    selectedUnitId = nil,
    outcome = nil,
    tick = 0,
    accumulator = 0,
    camera = {x = 0, y = 0, zoom = 1.3},
    floatingTexts = {},
    projectiles = {},
    vfx = {},
    casualties = {}
}
```

The grid module should be removed or reduced to a optional debug overlay only.

### 2. Add continuous unit motion state

The current [game/battle/battle_unit.lua](game/battle/battle_unit.lua) stores:

- x, y as logical grid coordinates
- visualX, visualY for interpolation

Those should be expanded to include:

```lua
x = 0,
y = 0,
velocityX = 0,
velocityY = 0,
moveCooldown = 0,
moveStep = 24,
collisionRadius = 18,
attackRange = 32,
moveTarget = nil,
state = "idle",
```

The unit should no longer be tied to integer grid cells.

The key nuance is that `moveCooldown` should be driven by the existing speed-based combat timing, while `moveStep` is a separate movement distance value that governs how far the unit travels each time it moves.

### 3. Replace tile movement with tick-step pursuit

In [systems/battle/execution_system.lua](systems/battle/execution_system.lua), movement should change from:

- target cell validation
- occupancy-based cell movement

to:

- move toward a target point or enemy position
- advance a fixed movement distance each tick
- stop once the unit reaches attack range
- apply a lightweight push response when another unit is too close

A minimal first version could use:

```lua
local dx = targetX - unit.x
local dy = targetY - unit.y
local dist = math.sqrt(dx*dx + dy*dy)

if dist > unit.attackRange then
    local step = unit.moveStep or 24
    if dist > step then
        unit.x = unit.x + (dx / dist) * step
        unit.y = unit.y + (dy / dist) * step
    else
        unit.x = targetX
        unit.y = targetY
    end
end
```

The important part is that the move is still resolved once per tick and still consumes the unit’s action/cooldown just like the present system.

### 4. Replace grid-based range checks with distance checks

The current battle logic uses grid distances and tile adjacency. That should be changed to use a distance metric such as:

```lua
local distSq = dx*dx + dy*dy
local rangeSq = (skill.range or 1.5) * (skill.range or 1.5)
```

For a more realistic feel, the collision radius should be considered as part of the check:

```lua
local effectiveRange = (skill.range or 1.5) + attacker.collisionRadius + target.collisionRadius
```

### 5. Define a simple push model for battle-line formation

The push behavior should be lightweight and predictable, not a full physics simulation.

My recommendation is:

- when a unit attempts to move into a space already occupied by another unit, it does not stop completely
- instead, it applies a small nudge to the other unit away from the overlap direction
- the nudge should be modest and should not launch units far across the battlefield
- the effect should be strongest when many units are moving into the same front line, creating a visible “pressing forward” effect

A simple rule set would be:

1. detect overlap between the moving unit’s circle collider and the other unit’s circle collider
2. if overlap exists, compute a small separation vector
3. move the other unit slightly away from the moving unit
4. optionally also reduce the moving unit’s step slightly for that tick so the push feels organic rather than jagged

That gives the battle line a natural shove-and-compress behavior without turning combat into a physics sandbox.

The key design goal is to make the front feel like a mass of bodies pressing together, not like units are rigidly blocked by one another.

### 6. Replace occupancy-based AI with target pursuit

In [systems/battle/decision_system.lua](systems/battle/decision_system.lua), the AI currently searches the nearest tile neighbor that improves distance to the target. That should be replaced with logic like:

- if an enemy is in range, attack
- if not, move closer
- if blocked by another unit, steer slightly around the obstacle or stop and wait

### 7. Update rendering to use continuous positions

The rendering layer in [systems/battle/render_system.lua](systems/battle/render_system.lua) currently assumes a grid cell and derives positions from it. That should be replaced with:

- drawing units directly at their world-space position
- optionally drawing a debug circle for their collision radius
- using the unit’s own x/y coordinates instead of grid->world conversion

### 8. Keep the combat data model mostly intact

The data definitions in [data/skills.lua](data/skills.lua) can remain mostly unchanged. The main difference is that range should be interpreted in world-space units rather than tile units.

That means the current values like `range = 1.5` and `range = 8.0` would need rebalancing for a continuous world scale.

---

## Suggested Migration Plan

### Phase 1 — Introduce continuous positions

- add `x`, `y`, `collisionRadius`, `moveStep`, `moveCooldown`, and `attackRange` to battle units
- keep existing grid fields temporarily as compatibility shims while the new model is introduced
- initialize units at world-space positions instead of grid coordinates
- update rendering to read from the unit’s world-space position first

### Phase 2 — Replace movement resolution

- remove grid occupancy updates from movement execution
- replace cell-based movement with direct position updates each tick
- preserve the existing one-action-per-tick cadence and cooldown logic
- make movement consume the unit’s action and set its next movement cooldown based on the existing speed-based timing

### Phase 3 — Replace targeting and AI

- change AI from tile neighbor search to pursuit logic
- decide whether a unit should chase the nearest enemy, the nearest in-range enemy, or a formation target
- ensure units stop moving once they are within effective attack range
- add simple collision avoidance or nudging behavior when units overlap

### Phase 4 — Add simple battle-line pressure

- use unit collision radii for attack reach and formation spacing
- when two units overlap during a movement step, nudge them apart slightly
- allow repeated nudges to create a visible pressure effect across a frontline
- tune the nudge strength so it feels like a shove, not a bounce

### Phase 5 — Preserve combat systems and polish

- keep the existing skill, windup, cooldown, projectile, and status effect pipeline intact
- keep the battle tick system unchanged and use it as the core cadence for both movement and combat actions
- optionally add debug rendering for collision circles and movement vectors
- only later consider box colliders, pathfinding, or more advanced formations

---

## Recommended First Implementation

The lowest-risk first version would be:

- circles only
- no global pathfinding
- no complex obstacle avoidance
- simple pursuit toward target enemies
- one fixed movement step per tick
- attack when within a radius derived from skill range and unit collider size
- simple overlap nudging between units during movement
- no full physics, no advanced formations, no box colliders

That version is enough to validate the new combat feel without overcommitting to a full tactical simulation.

---

## Open Questions

These are the main decisions that should be settled before implementation begins:

1. Should movement step size be a shared battle constant, or should it be derived from each unit’s speed stat?
2. Should units be allowed to push each other only when both are moving, or also when one is stationary and the other attempts to move through?
3. Should a gentle push be resolved by simply nudging the overlapping unit away, or by applying a small velocity impulse that decays over a few ticks?
4. Should attack range be based strictly on center-to-center distance, or should it include the units’ collision radii?
5. Do you want the initial version to preserve the current “one unit acts per tick” rule exactly, or should it allow a limited amount of queued movement/attack sequencing later?
6. Should the battle still visually show a grid overlay in debug mode while the movement is gridless?

My recommendation is to keep the push rule very simple:

- only a small nudge, no full physics
- only apply it when overlap is detected during a movement step
- let the front line naturally compress under repeated pushes

That should be enough to create organic battle-line formation without making the combat system harder to reason about.

---

## Estimated Scope

### Small change set

If the goal is only to prove the concept and remove grid dependency, the work is roughly:

- 1–2 days for positions and movement
- 1 day for AI and targeting
- 1 day for rendering and debugging

### Medium change set

If the goal is to make the battle system feel polished and robust, expect:

- 1–2 weeks of work
- more time if collision avoidance, formations, or pathing are added

---

## Risks and Tradeoffs

### Risk: losing the current tactical clarity

The current grid gives clear positioning and predictable spacing. A continuous system can feel looser unless the unit spacing and attack ranges are tuned carefully.

### Tradeoff: simpler pathing

A full gridless system can support more natural movement, but it also removes some of the clean tile-based pathfinding. That is acceptable for a first version if the game prioritizes readability and speed over strict tactical simulation.

### Tradeoff: collision handling

Circles are simpler, but they can feel less precise than boxes for humanoid units. Boxes are more expressive, but they are more expensive and usually require more careful collision logic.

---

## Recommendation

Use circles for the initial migration.

They are the better fit because they offer:

- lower implementation cost
- simpler distance checks
- faster iteration
- acceptable behavior for a first version of the combat system

Boxes can be added later if the battle feel needs more fidelity.

---

## Summary

To move away from a grid-based battle system, the main work is to:

1. remove tile occupancy from battle state
2. make units own continuous position and collision data
3. move units by pursuit / steering instead of cell movement
4. switch attack and AI logic from grid distance to world-space distance
5. render battles from continuous coordinates rather than grid cells

That is a substantial but manageable refactor, and it fits the current architecture without requiring a full rewrite of the combat data layer.
