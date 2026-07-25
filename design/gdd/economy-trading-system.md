# Economy/Trading System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: A Living, Persistent World, Meaningful Progression

## Overview

The Economy/Trading System handles all buying and selling of goods between the player and NPC traders. It determines prices based on base item value, faction reputation (Oratory aptitude), settlement prosperity, and supply/demand. Trading occurs at settlement NPCs with the `trader` role, at specialised NPCs (blacksmiths, herbalists), and with trader parties encountered on the world map.

## Player Fantasy

Trade is how you turn the spoils of adventure into better equipment and supplies. A keen negotiator (high Oratory) gets better prices. A prosperous town offers better goods. A blacksmith in a small village may have limited stock but lower prices. The economy rewards building relationships and exploring different settlements.

## Detailed Design

### Core Rules

1. **Currency**: Gold pieces (gold) are the single universal currency. No barter system for MVP.

2. **Prices**: 
   `sell_price = base_value * settlement_prosperity_modifier`
   `buy_price = base_value * settlement_prosperity_modifier * rep_multiplier`

3. **Settlement prosperity modifier**: Each settlement has a `prosperity` value (0–100) that affects prices and available goods:
   - Prosperity 0–20: Poor — limited stock, lower sell prices, higher buy prices
   - Prosperity 21–50: Average — moderate stock, standard prices
   - Prosperity 51–80: Prosperous — good stock, better sell prices
   - Prosperity 81–100: Rich — excellent stock, best prices

4. **Reputation/Oratory effect**: The player's Oratory aptitude and faction reputation modify buy prices:
   `rep_multiplier = 1.0 - (oratory * 0.05) - (rep_tier_bonus)`
   - Oratory 0: 0%
   - Oratory 4: 20% discount
   - Friendly reputation: additional 10% discount
   - Allied reputation: additional 20% discount

5. **Trader inventories**: Each trader NPC has an inventory of items for sale. Inventories are defined in the trader's NPC data. Default traders have a fixed inventory; speciality traders (blacksmiths, herbalists) have curated stock.

6. **Buying**: The player selects an item from the trader's inventory. The gold cost is deducted from the player's gold. The item is added to the party inventory.

7. **Selling**: The player selects an item from their inventory. The item is removed. Gold equal to the sell price is added. Quest items cannot be sold.

8. **Gold tracking**: The party has a single shared gold pool. Gold is displayed in the HUD.

### Merchant Types

| Merchant | Sells | Buys |
|----------|-------|------|
| General Trader | Common items, food, supplies, materials | All common items |
| Blacksmith | Weapons, armour, shields, repair service | Weapons, armour, materials |
| Herbalist | Potions, herbs, medicines | Herbs, monster parts |
| Tavern Keeper | Food, drink, rumours | — |
| Hunter Trader | Pelts, trophies, tracking supplies | Pelts, monster parts |
| Trader Party (world map) | Varies — random goods, sometimes rare items | All common items |

### States and Transitions

| State | Description |
|-------|-------------|
| **Browsing** | Trader's inventory displayed. Player can browse items. |
| **Buying** | Player has selected an item to purchase. Gold deducted if affordable. |
| **Selling** | Player has selected an item from their inventory to sell. |
| **Closed** | Trader has no gold remaining for purchases (if applicable) or is unavailable. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S12 Inventory System | Consumes | Items in inventory for selling. Items added for buying. |
| S25 Faction Reputation | Consumes | Reputation tier affects price multipliers |
| S11 Aptitudes (Oratory) | Consumes | Oratory level affects buy price discounts |
| S08 Location System | Consumes | Settlement prosperity affects prices and stock |
| S09 NPC Data System | Consumes | Trader NPCs define their inventory |
| S16 Party Encounter | Consumed by | Trader parties on world map open trade interface |

## Formulas

**Buy price:**

`buy_price = base_value * prosperity_modifier * (1.0 - oratory * 0.05 - rep_bonus)`

**Sell price:**

`sell_price = base_value * prosperity_modifier * 0.5`

(Items sell for 50% of base value, modified by prosperity.)

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base value | `base_value` | int | 1–10000 | Item's base gold value |
| Prosperity modifier | `prosperity_mod` | float | 0.8–1.2 | Settlement wealth multiplier |
| Oratory level | `oratory` | int | 0–4 | Player's Oratory aptitude |
| Reputation bonus | `rep_bonus` | float | 0–0.2 | Friendly=0.1, Allied=0.2 |

**Example:** Buying a bronze sword (base 50 gold) at a prosperous town (1.1) with Oratory 2 and Friendly reputation:
`50 * 1.1 * (1.0 - 2*0.05 - 0.1) = 55 * 0.8 = 44` gold

## Edge Cases

- **If the player has insufficient gold**: The purchase is refused. "Not enough gold."
- **If the trader has insufficient gold for buying**: For MVP, traders have unlimited gold for purchases (simplification).
- **If the player tries to sell a quest item**: "This item is required for an active quest." Cannot sell.
- **If the player's inventory is full**: The purchase is refused. "Inventory full."
- **If a settlement's prosperity changes**: Prices update on the next visit.
- **If the player has Friendly or Allied reputation**: Prices include the discount automatically. No special action needed.
- **If the player interacts with a trader from a hostile faction**: Trade is refused. "We don't deal with your kind."

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S12 Inventory System | Hard | Item definitions with base_value, inventory management |
| S25 Faction Reputation | Hard | Reputation tier for price calculation |
| S11 Aptitudes (Oratory) | Hard | Oratory level for price discount |
| S08 Location System | Hard | Settlement prosperity values |
| S09 NPC Data System | Hard | Trader NPC inventory definitions |

**Depended on by:** (consuming system — trade is triggered by NPC interaction)

## Tuning Knobs

- **Sell price ratio**: Float. Default: 0.5 (50% of base value). Range: 0.3–0.8.
- **Oratory discount per point**: Float. Default: 0.05 (5% per point).
- **Friendly reputation discount**: Float. Default: 0.1 (10%).
- **Allied reputation discount**: Float. Default: 0.2 (20%).
- **Prosperity modifier range**: Float 0.8–1.2. Per-settlement configurable.
- **Trader gold pool**: For MVP, infinite. Future: finite trader gold that resets periodically.

## Visual/Audio Requirements

- **Trade UI sound**: Coin clink on purchase, coin drop on sale.
- **Item icons**: 24×24px icons in the trade window matching inventory icons.

## UI Requirements

- **Trade screen**: Split layout — trader's inventory on the left, player's inventory on the right. Selected item shows details and price in the centre.
- **Price breakdown**: Tooltip showing base price, prosperity modifier, Oratory discount, and reputation discount.
- **Gold display**: Current party gold displayed prominently at the top of the trade screen.
- **Buy/Sell buttons**: Shield-shaped buttons (per art bible) for confirming transactions.
- **Quantity selector**: For stackable items, a +/- selector for buying/selling multiple units.

## Acceptance Criteria

- **GIVEN** a trader NPC, **WHEN** the player interacts, **THEN** the trade screen opens with the trader's inventory displayed.
- **GIVEN** the player selects an item to buy with sufficient gold, **WHEN** the purchase is confirmed, **THEN** the item is added to inventory and gold is deducted.
- **GIVEN** the player selects an item to buy with insufficient gold, **WHEN** the purchase is attempted, **THEN** it is refused.
- **GIVEN** the player sells an item, **WHEN** the sale is confirmed, **THEN** the item is removed from inventory and gold is added.
- **GIVEN** the player has Oratory 2 and Friendly reputation, **WHEN** buying an item, **THEN** the price includes both discounts.
- **GIVEN** the player interacts with a trader from a hostile faction, **WHEN** trade is attempted, **THEN** it is refused.
- **GIVEN** the player tries to sell a quest item, **WHEN** the sale is attempted, **THEN** it is refused.

## Open Questions

- **Trader inventory refresh**: Should trader inventories refresh over time (restock goods)? Proposed: yes — daily refresh based on settlement prosperity. A prosperous town restocks faster.
- **Limited trader gold**: Should traders have finite gold for buying, forcing the player to visit multiple settlements to sell large hauls? Proposed: deferred from MVP. For now, traders have infinite buying gold.
