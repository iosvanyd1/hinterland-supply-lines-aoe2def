# Architecture

How the design ([Supply Lines & Upkeep — AoE2 DE Mod Design](https://claude.ai/code/artifact/f78bb463-4b0f-4604-94be-e4146d721e85)) maps to code. Open engine questions are tracked in [research/TECHNICAL_UNKNOWNS.md](research/TECHNICAL_UNKNOWNS.md).

## Runtime shape

- **Data mod** defines new objects only: Supply Cart (slice 1), later the charter unit for "make capital" and the dark-twin buildings if U6 needs them. No logic.
- **XS** holds all logic as rules on 1–5 s intervals. The build flattens it and appends it to the game's `Effects.xs`, which every game includes, so it runs on any map (no custom RMS, no `main()`).
- There are no scenario triggers, because random maps cannot carry them.

## XS files

| File | Role |
|---|---|
| `src/xs/HinterlandSupplyLines.xs` | Flat entry point (RMS and scenario load this) |
| `src/xs/Hinterland/main.xs` | State arrays, helpers, rules |
| `src/xs/Hinterland/constants.xs` | Vanilla IDs and tuning dials |
| `src/xs/Hinterland/generated_ids.xs` | IDs of new data-mod objects. Committed with `-1` placeholders; the build writes real IDs into its copy under `build/` |

## Mechanics → implementation

| Design mechanic | Implementation | Rule / file | Blocked by |
|---|---|---|---|
| 1 Supply Cart | Trade Cart clone, TC-trained, Castle Age | `patches/supply_cart.py` | U4, U5 |
| 2 Supply window | Per-building seconds in parallel int arrays; drain 1/s outside TC coverage; refill on cart arrival; lock at 0 | `hlSupplyTick`, `hlCartLogistics` | U6, U14 |
| 3 Food upkeep | Military pop (res 40) × rate subtracted from food (res 0) each second; starvation debuff at 0 food | `hlFoodUpkeep` (inactive) | U2 |
| 4 Supply aura | Units debuffed by default (dat or start-of-game effect); TC radius buff via buffed pool or native aura | not started | U2, U3, U12 |
| 5 Supply UI | Building captions now; timers/instructions later | `hlUpdateCaption` | U9 |
| 6 Capital & TC network | Capital ID per player; coverage = union of TC radii, capital larger | `hlAssignCapitals`, `hlIsCoveredByTc` | U8 |
| 7 Grace countdown | Same timer as the supply window, started when coverage is lost | not started | — |
| Raiding rewards | Owner change = capture; disappearance = kill → gold to killer | not started | U10 |
| Palace techs (2026-10-20) | Six techs at the Palace (`patches/palace_techs.py`, empty effects); XS reads `xsGetTechState` for incomes, delivery profit and the Paved Roads radii | `hlPalaceIncome`, `hlDeliveryProfit`, `hlRefreshPlayers` (radii) | T36, T38 |
| Per-tick caches (2026-10-20, performance review) | Every rule starts with `hlBeginTick`: per-player computer flag, age gate, radii and Palace position read once; sources grouped by owner; captions written only on change; delivery scan filters full buildings from arrays first | `hlRefreshPlayers`, `hlRebuildSources`, `hlUpdateCaption` | T13 |
| Attrition (2026-10-20) | From Castle Age, non-cavalry military units outside every supply radius and over 20 tiles from a loaded cart lose 1% max HP every 2 s | `hlAttrition` | T37 |
| Computer players exempt (2026-10-20) | Every rule skips players whose `xsGetPlayerType` is 3; a building that passes to the AI is restored | `hlIsComputer` | T35 |

## Conventions

- All XS names are prefixed `hl` (functions, rules) or `g` (globals); constants are `c...`.
- Constants shared across files must be `extern const` (xs-check enforces this).
- Includes use Windows separators: `include "Hinterland\x.xs";`.
- Logic uses only synced values: game time, unit state, `xsGetRandomNumber`. Never `xsUnsync*`.
