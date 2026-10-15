# Technical unknowns: status

Consolidated from the four research reports in this folder (researched 2026-10-13, game build as of the Sept 2026 update). Each item links back to its report for sources.

**Status key:**
- **Resolved**: the docs answer it and the scaffold already uses the answer.
- **Test**: an API or approach exists, but behaviour must be confirmed in game.
- **Open**: no known approach yet, or the sources conflict.

| ID | Unknown | Status | Answer / best approach | Test |
|---|---|---|---|---|
| U1 | XS API surface; what runs in an RMS | Resolved / Test | Full function list: [xs-api.md §9](xs-api.md). RMS: `#includeXS` at the top; `main()` runs at map generation and rules keep running. Unit functions are "no longer limited to scenario games" (Aug 2025 notes), but confirm each function we use in an RMS game. | T1 |
| U2 | Modify stats of ONE unit | Test | `xsEffectAmount(cAddUnitAttribute (11), unitId, attr, value)` (also Set = 10, Mul = 12). Read back with `xsGetUnitAttribute`. Attack/armor packing is `class*256 + amount`. The per-type "Set adds instead" bug (Aug 2022) may also apply per unit, so use Add with negative values only. | T2, T3 |
| U3 | TC aura: manual pool vs native aura task | Superseded 2026-10-14 | No unit penalty and no TC aura any more: only the Palace has a native home-turf aura (`palace_aura.py`). TC auras failed because age-ups replace the TC's data (109 -> 71 -> 141 -> 142). | T19 |
| U4 | Custom Supply Cart unit in the .dat | Resolved / Test | Clone Trade Cart 128 into every civ (genieutils-py, auto-mods pattern); train at TC 109; enable via Castle Age tech 102 effect (type 2). Implemented in `hinterland/datmod/patches/supply_cart.py`. Unverified: a free TC button slot (`TC_BUTTON_ID`). | T5 |
| U5 | Trade-Cart-style auto pathing capital → destination → capital | Resolved 2026-10-14 | XS issues Move orders (`xsTaskUnits`): a cart's delivery sets its route, then it shuttles Palace ↔ building. Playtested. The native trade-path experiment was dropped. | ~~T6~~ |
| U6 | Lock training AND research at one building | Open | No per-building API: every enable/disable is per player per type. Candidates: (a) `xsSetUnitProperty(id, cUnitSelectable, 0)` (scaffold stand-in; blocks new orders but also gather points/garrison); (b) swap for a data-mod "dark twin" with no buttons (`xsRemoveUnit` + `xsCreateUnit`, restore HP); (c) local technologies per building instance, if a local tech can remove buttons; (d) Stop/Freeze Object clears one building's queue (Sept 2026). | T7, T8 |
| U7 | Detect a cart arriving at a building | Resolved | Poll cart positions each second (`xsGetPlayerUnitIds` + `xsGetUnitPosition` + `dist`). More robust: make carts garrison into the target, then `xsGetGarrisonedInUnitId`. | — |
| U8 | ~~"Make capital" button + cooldown~~ | Superseded 2026-10-14 | The capital is now the Palace building (design section 11): one per player, rebuildable, no button or cooldown. | ~~T9~~ |
| U9 | Supply UI: timers, status, minimap | Test | Per-building text: `xsSetUnitCaption` / Change Object Caption. Timers: `xsDisplayTimer` per player (max count unknown). Display Instructions: 3 panels. Minimap shape via .dat `minimap_mode`; distinct colour per unit is unknown. Enemy info: only what vision shows. Never drive logic from `xsUnsync*`. | T10 |
| U10 | Death cause: killed vs converted vs Heresy | Test | Track cart IDs: still exists with a new owner = converted; gone = died. Heresy flag = resource 192 "Converted Units Die". Native gold-to-killer: task 161 "Unit refund" with work range > 0 (docs say the killer receives it). | T11 |
| U11 | Multiplayer packaging | Resolved / Test | Data mod (cart unit, dark twins) + RMS with `#includeXS`; all logic in XS rules. Unranked lobbies only. Lobby prompts players to subscribe to the data mod. Known issues: XS is not saved in recorded games; nested XS `include` historically did not transfer (irrelevant when everything ships in the mod); whether the game lists RMS from inside a local mod is unverified (`deploy.ps1 -AlsoProfile` fallback). | T12 |
| U12 | Performance of aura + pool at late-game scale | Test | No benchmarks exist. Use 1–2 s rule intervals, never `highFrequency`; the buffed pool is bounded by units near TCs. | T13 |
| U13 | Can a data mod run XS on its own (no RMS/scenario)? | Open (conflicting) | [triggers-ui-multiplayer.md §4](triggers-ui-multiplayer.md) reports tech effects calling XS via resource 33 + `Effects.xs` (Aug 2025). [dat-modding.md](dat-modding.md) found no evidence. If true, the mod could work on any map. | T14 |
| U14 | What happens to queued units when a building locks | Decided 2026-10-14: **cancel the queue and refund** (user choice; replaces design 10.1 "pause, no refund"). Playtest 2026-10-14: an unselectable building keeps producing its existing queue; `xsStopUnit` alone does not clear it. **Resolved:** `xsTaskUnits(Stop)` + `xsStopUnit` on lock clears the queue and the engine refunds (playtest 2026-10-14). Which of the two calls does it is untested. | T8 |

## In-game test list

Run in the Scenario Editor (Test button) unless noted. Record results in [../PLAYTEST.md](../PLAYTEST.md).

| Test | What to check | Unblocks |
|---|---|---|
| T1 | Start an RMS skirmish on `HinterlandArabia`: does `xsChatData` from a rule appear every second? Do `xsGetPlayerUnitIds`, `xsSetUnitCaption`, `xsSetUnitProperty` work there? | U1 |
| T2 | `xsEffectAmount(cAddUnitAttribute, id, cAttack, 4*256+2)` changes only that unit; check the displayed attack and real damage | U2 |
| T3 | Per-unit Set on attack/armor: does it set or add? | U2 |
| T4 | Aura task on one TC via `xsModifyUnitTasks`: only that TC projects it? Which attributes work? | U3 |
| T5 | Built data mod: Supply Cart appears at TC in Castle Age, in a free button slot, correct cost | U4 |
| T6 | ~~Native trade path to a TC~~: dropped; XS routing works (U5). | U5 |
| T7 | `cUnitSelectable = 0` on a Barracks: can the player still queue via hotkeys / select-all / control groups? | U6 |
| T8 | Disable-then-reenable on a building with a 5-unit queue: what happens to the queue and resources, for each lock option (a–d)? | U6, U14 |
| T9 | ~~Charter unit at a secondary TC~~: superseded by the Palace (U8). | U8 |
| T10 | Caption over a building: readable? Does it show to the enemy? Under fog? | U9 |
| T11 | Kill / convert / convert-with-Heresy a cart: check owner change, `xsDoesUnitExist`, resources 20/154/240, task 161 gold | U10 |
| T12 | Local mod only (no `-AlsoProfile`): is the map listed? 2-player LAN/lobby: does it sync? | U11 |
| T13 | 4-player late game, 200 pop each: frame time with the aura + pool rules on vs off | U12 |
| T14 | Data mod with a tech that sets resource 33: does an `Effects.xs` function run without the RMS? | U13 |
| T15 | ~~Supply circles~~: abandoned 2026-10-14. The TC circle seen in game was its arrow-range indicator; inert and Caravanserai-shaped auras drew nothing on the TC or the Palace. Captions show supply state instead. | U9 |
| T16 | **Passed 2026-10-14.** Palace (Wonder clone, slot 12, replaces the Wonder): no Wonder victory once task 120 is dropped; a second Palace cannot be placed while the first is under construction; an unfinished Palace does not act as the capital; the Palace can be rebuilt after it is destroyed. | U8 |
| T17 | **Passed 2026-10-14.** Loaded-cart look: XS swaps the cart to a Loaded Supply Cart unit (Ox Wagon look) at the Palace and back on delivery (`xsRemoveUnit` + `xsCreateUnit`). Swap looks right, route continues, HP kept, no death sound, no extra units lost in statistics. Known cost: a selected cart is deselected at each swap (accepted). A carrying graphic on a trade task never showed. | U5 |
| T18 | **Passed 2026-10-14.** `xsGetUnitProperty(id, cUnitBuildpoints) >= xsGetObjectAttribute(p, type, cTrainTime)` tells foundations from finished buildings (starting TC included). New buildings outside coverage start at 20 s once built; a TC's outpost goes dark at once when the TC is lost or runs dry and recovers when it is refilled; Palace loss gives a countdown. | U6 |
| T19 | **Passed 2026-10-14.** Supply aura: speed and armor change between supplied and unsupplied ground and flip at once on crossing the edge; villagers and carts unaffected; Dark/Feudal vanilla. Attributes 116/117 = melee/pierce armor; Combat Ability bit 32 switches auras on. Ships untested in game (Arabia has no water); excluded by data, enforced by a test. | U3 |
| T20 | ~~Dry TC switches its aura off~~: dropped 2026-10-14, TCs no longer have auras. | U3 |
| T21 | **Passed 2026-10-14.** Home-turf aura: +1/+1 armor and +10% speed for friendly military units inside the Palace radius (from Feudal) and TC radii (from Castle Age); vanilla outside; no TC aura in Dark/Feudal; no TC healing; villagers and carts unaffected. Combat Ability is `type_50.break_off_combat`; TC data must cover all four age variants. | U3 |

## Reports

- [xs-api.md](xs-api.md): XS functions, per-unit stats, locks, capital, RMS vs scenario.
- [dat-modding.md](dat-modding.md): IDs, cloning units, trade task, conversion, death hooks, packaging.
- [triggers-ui-multiplayer.md](triggers-ui-multiplayer.md): trigger effects, death cause, UI, multiplayer, performance.
- [mod-repos-and-paths.md](mod-repos-and-paths.md): how other mods structure repos; Windows/Steam paths.
