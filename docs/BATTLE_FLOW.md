# BATTLE_FLOW.md

This document describes **battle tick flow and state**.

---

## 1. Tick States

The battle cycles between two high-level states:

1. **Player-Ready**
   * Player unit cooldown is 0
   * Ticks are paused
   * Player selects movement or an action

2. **Active Ticks**
   * Player unit is on cooldown
   * Ticks advance in real-time
   * AI units act when their cooldown reaches 0

---

## 2. Tick Advancement

* A tick advances only in **Active Ticks** mode
* When the player unit cooldown returns to 0, the battle returns to **Player-Ready**
* AI decisions are evaluated on tick boundaries

---

## 3. Action Lifecycle

Actions follow `ACTION_SCHEMA.md`:

```
READY → WINDUP → EXECUTE → COOLDOWN → READY
```

---

## 4. Result State (Future)

* Victory/Defeat checks will run after each tick
* Retreat is handled by a dedicated interaction (future)

