# BATTLE_GRID.md

This document defines the **battle grid** and stacking rules.

---

## 1. Grid Specs

* Dimensions: **30 x 13** cells
* Cell size: **42 px**
* Capacity per cell: **10**

---

## 2. Unit Size & Stacking

* Units define `size` from **1–10**
* Each cell has **capacity 10**
* Multiple units may occupy the same cell if total size ≤ 10

Example:

* 3 units of size 3 can share one cell (3 + 3 + 3 = 9)

---

## 3. Cell Data

Each cell stores:

* Occupant list
* Total occupied size
* Terrain properties (future)

