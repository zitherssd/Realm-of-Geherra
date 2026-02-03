# TIME_SYSTEM.md

This document defines the **World Time System** for *Realms of Geherra*.

Time is **data-driven**, deterministic, and advances only through player-driven world activity (movement and resting).

---

## 1. Design Goals

* Deterministic time progression
* Time advances only when the player moves on the world map
* Time can advance via explicit rest actions (town rest or camp)
* Readable day and time periods for UI and gameplay

---

## 2. Core Rules

* One in-game day lasts **18 real seconds**
* A day has 24 hours
* **Seconds per hour** = $\frac{18}{24} = 0.75$
* Day count starts at **Day 1**, hour **0.0**

---

## 3. Time Periods

| Period       | Hours (start–end) |
| ------------ | ----------------- |
| Stilldark    | 0–3               |
| Lowlight     | 3–6               |
| Firstlight   | 6–9               |
| Highsun      | 9–12              |
| Suncrest     | 12–15             |
| Falling Sun  | 15–18             |
| Dusktide     | 18–21             |
| Gloamhour    | 21–24             |

The active period is determined by the current hour.

---

## 4. Night Tint

The world map uses a **night tint overlay** based on hour:

* Full daylight: 8–18 → no tint
* Fade in: 18–21 → tint increases linearly
* Full tint: 21–4 → maximum tint
* Fade out: 4–8 → tint decreases linearly

This tint affects the world map rendering only.

---

## 5. World Scene Integration

Time advances only when:

* The player party is moving on the world map
* The player chooses a rest/camp interaction

Time does **not** advance during encounters or when idle.

---

## 6. Canonical Implementation

* Core time helpers live in: /core/time.lua
* World map integration lives in: /scenes/world_scene.lua

---

## 7. Future Extensions

* Time-based healing or morale regeneration
* Night-time encounter modifiers
* Time-driven world events
* Seasonal or calendar layers
