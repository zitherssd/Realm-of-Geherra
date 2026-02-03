# BATTLE_SCENE.md

This document defines the **Battle Scene** flow for *Realms of Geherra*.

Battles are **real-time tick-based**, but **ticks only advance while the player unit is on cooldown**.

---

## 1. Core Rules

* Grid size: **30 x 13** cells (width x height)
* Cell size: **42 px**
* Each cell has **capacity 10**
* Units have a **size** value (1–10)
* Units can share a cell as long as total size ≤ 10

---

## 2. Tick Flow (Player-Gated)

* When the player unit **can act**, the battle **pauses** for player input.
* When the player unit **commits an action**, ticks resume until the player unit is ready again.
* AI units act whenever their cooldown reaches 0 during active ticks.

---

## 3. Scene Responsibilities

* Read player input for movement and actions
* Advance battle ticks only when player is on cooldown
* Draw grid, terrain, and units (depth-sorted)
* Delegate AI decisions to battle AI system
* Apply action resolution via battle rules

---

## 3.1 Incoming Battle Config

When a battle starts, the world scene passes a config object:

* `parties` — participating parties (player + enemy)
* `deployment` — placeholders for squad deployment (future)
* `stage` — battle stage id (forest_stage, town_stage, ruin_stage, etc.)

---

## 4. Deployment

* Player and AI deployment will be handled by squad setup (future)
* The battle scene consumes the deployment layout but does not compute it

---

## 5. Related Docs

* `BATTLE_GRID.md`
* `BATTLE_FLOW.md`
* `BATTLE_RENDERING.md`
* `BATTLE_CAMERA.md`
* `BATTLE_AI.md`
* `BATTLE_ACTIONS.md`
* `ACTION_SCHEMA.md`
* `STAT_SYSTEM.md`
