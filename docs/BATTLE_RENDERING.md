# BATTLE_RENDERING.md

This document defines rendering rules for the battle scene.

---

## 1. Depth Sorting

* Units are drawn by grid **row** (lower rows drawn last)
* Units within the same row are drawn by **column** order
* This ensures units lower on the screen appear in front

---

## 2. Sprites

* Unit sprites are defined in unit data (`sprite.image`)
* Item sprites are not drawn in battle by default

---

## 3. Animations (Planned)

* Move animations interpolate between cell centers
* Attack animations apply rotation or quick offset
* Animation timing is deterministic and tick-aligned

