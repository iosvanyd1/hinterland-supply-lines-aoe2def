# Knowledge base: AoE2 DE modding facts learned on this project

What we found out while building Hinterland Supply Lines, so later sessions don't rediscover it.
Every entry carries its evidence:

- **[game]** confirmed by the user in a playtest (see `docs/research/TECHNICAL_UNKNOWNS.md`, T-numbers);
- **[data]** read from the vanilla `.dat` or the game's own files;
- **[docs]** from the UGC guide (ugc.aoe2.rocks) or patch notes, not tested in game by us.

Game build at the time: AoE2 DE, October 2026; genieutils-py 0.1.2; xs-check 0.2.30.
IDs below are for that build. Re-check them after a game patch.

## 1. Mod packaging and the game client

**Data mods vs other mods**
- A data mod has a gear icon in Installed Mods and no On checkbox. You pick it per game in the lobby's Data Mod dropdown. `mods\mod-status.json` always shows it `"Enabled": false`; that is normal. Editing that file does nothing; the game rewrites it at start. [game]
- **Online lobbies only list published data mods.** A local data mod never appears there (only "Definitive Set"); single-player skirmish does list local ones. [game]
- Publishing: the user publishes and updates **only via in-game Mods > My Mods > Update Mod**. That uploads the contents of `<profile>\mods\local\<folder>`. Published as mods 551284 (data) and 551286 (Text). [game]
- A subscribed mod lands in `<profile>\mods\subscribed\<id>_<title>\` and auto-updates when the game starts. [game]
- A local copy with the same title as a subscribed mod is confusing: remove local release copies after publishing, and test with `build --dev` ("Hinterland Supply Lines (dev)", folder `HinterlandSupplyLinesDev`). [game]

**Strings (tooltips, names)**
- A data mod's own `resources\<lang>\strings\key-value\key-value-modded-strings-utf8.txt` is **never read**: the game loads mod strings at startup ("install modded languages" in the log) only from enabled mods, and a data mod is enabled later, in the lobby ("Enabling mod #0 (...)"). Ship strings in a separate, normal mod (our `HinterlandSupplyLines-Text`) that the player switches On, then restarts. [game]
- The strings file loads from such a mod; overriding a vanilla ID there works (we proved it by prefixing the Trade Cart tooltip, ID 26100). [game]
- **New string IDs must follow the vanilla unit pattern**, or they show nothing: name `N` (< 100000), "Build/Train" text `N+1000`, tooltip text `N+21000`, and the unit's `language_dll_help` = `N+100000` (the game shows help ID − 79000). Example: Trade Cart 5100 / 6100 / 26100 / help 105100. IDs in the 31 million range never showed, under either number. [game]
- One entry per line: `ID "text"`, newlines inside the text written as the two characters `\n`. A real line break breaks the entry (the button then shows only the hotkey). [game]
- Free IDs we use: 5997 (Loaded Supply Cart name), 5998 (Supply Cart), 5999 (Palace), plus their +1000/+21000. Check freedom across all `resources\en\strings\key-value\*.txt` and all unit/tech `language_dll_*` fields. [data]

**XS from a data mod: runs on any map**
- The game includes `resources\_common\xs\Effects.xs` in every game ("Included automatically" in its header), and a data mod's copy replaces the game's. Appending our XS to the vanilla `Effects.xs` makes the rules run on any map, no RMS needed (T14). [game]
- Therefore: **no `main()`** in that XS (it would clash with a map's or scenario's `main()`); do one-time setup lazily from the rules (`hlEnsureInit()`). Our top-level names must not clash with the vanilla file (the build checks). Rebuild after game patches, since `Effects.xs` changes with them. [game]
- **Nested XS `include` does not resolve inside a published mod**: the RMS's `#includeXS File.xs` found the entry file in the mod, but its `include "Sub\main.xs"` did not; it fails silently. Ship one flat file (`hinterland/xsflatten.py`). [game]
- Never put an `Effects.xs` (or our XS) in `<profile>\resources\_common\xs\`: profile files override everything, in every game, mod or not. Profile copies also mask packaging bugs (they hid the include bug above). [game]
- Vanilla `Effects.xs` gives one xs-check false positive (`cVictoryTypeConquest` unknown to 0.2.30) plus deprecation warnings; lint our part separately. [data]

**Logs and diagnosis**
- Logs: `%USERPROFILE%\Games\Age of Empires 2 DE\logs\<timestamp>\MainLog.txt`. It shows which mods were enabled for a match, not XS errors. [game]
- When a change "does nothing", first check: is the game using the build you think (mod enabled in the lobby, subscribed vs local, game restarted after deploy)? Then inspect the deployed files directly. [game]
- Deploy only with the game closed (`Get-Process AoE2DE*`); it locks mod files and reads them at start. [game]
- The profile folder `0` is the offline profile; the real one is the SteamID64. The game may live in any Steam library (`steamapps\libraryfolders.vdf`). [data]

## 2. The .dat (genieutils-py 0.1.2)

**Cloning units**
- After cloning, set `id`, `copy_id` **and** `base_id` to the new ID (`set_identity`). A Wonder clone that kept `copy_id/base_id = 276` still behaved like the Wonder in places. [game]
- Append the clone to every civ's `units` list; the new ID is `len(units)` at that moment, so it shifts when a patch adds units. XS gets real IDs through `generated_ids.xs`, written into the build only. [data]
- Floats are float32 in the dat: compare with a tolerance (0.85 reads back as 0.8500000238). [data]

**Field names that are not what they seem**
- **Combat Ability (attribute 63) is `type_50.break_off_combat`**, not `combat_level`. Bit 32 switches a unit's auras on. Vanilla aura units: Caravanserai 34, Fortified Outpost 34, Centurion 32; Castle (no aura) 2. Setting `combat_level` did nothing. [game]
- Task "productivity resource" is `resource_multiplier`. [docs]
- Aura task: `search_wait_time` holds the attribute ID, `work_value_1` the value, `work_value_2` how many units in range switch it on, `work_range` the radius, `combat_level_flag` bits (1 multiply, 2 circular, 4 range indicator), `target_diplomacy` (1 you, 4 gaia + you + allies). [docs] [game]

**Auras (task 155)**
- Work only with Combat Ability bit 32 set on the aura unit. [game]
- Attributes: 5 = speed (with the multiply flag), **116 = melee armor, 117 = pierce armor** (aura-only attributes, missing from the UGC attribute list; inferred from vanilla Hoplite / Sparabara / hero auras, verified T19). [game]
- Effects apply on entry and are removed at once on exit; no XS needed. [game]
- **Range indicator circles never showed** for our auras (inert, Caravanserai-shaped, with the visible bit). The circle seen around a TC is its **arrow range**. Abandoned (T15). [game]

**Town Centers**
- Age-ups replace the TC's data: effects of type 3 ("upgrade unit") in techs 101/102/103 turn TC 109 into **71 (Feudal), 141 (Castle), 142 (Imperial)**. Per-type TC changes must be applied to all four variants, or they vanish at the next age. Unit IDs in XS (`xsGetPlayerUnitIds(p, 109)`) and train locations (109) keep working across ages. [game]
- Each TC variant carries 15 dormant vanilla regen auras (+15 HP/min, 10 tiles); no vanilla effect sets their Combat Ability bit 32. Remove them if you switch auras on. [data]
- Free TC button slot: 10 (middle row, right). [game] No vanilla civ uses TC slots 5, 9 or 10 (October 2026); civ-specific TC buttons sit on 2-4 and 12. The Supply Cart moved to the Palace anyway (2026-10-15). [data]

**Drop sites**
- Villagers' and fishing ships' `bird.drop_sites` list the **base** IDs (Mill 68, Lumber Camp 562, Mining Camp 584, Dock 45, TC 109...); age variants still take drop-offs. A clone with its own base ID takes none: villagers cannot drop resources at a dark TC (playtest 2026-10-15). [game] [data]
- Age-ups upgrade drop sites in place (effect type 3): Mill 68/129/130/131, Lumber Camp 562/563/564/565, Mining Camp 584/585/586/587, Dock 45/133/47/51, Shipyard 2119/2117/2118, Port 2172/2143/2142/2141; Folwark 1734/1711/1720 and Settlement 2556/2558/2560 by their own techs. Mule Cart 1808 is a movable drop site. Pastures are multi-part (post 1888, annex 1890) and are their own drop site. Towers and Castles are on the villager drop-site lists too. [data]

**Towers**
- Class 52, built by villagers: Watch Tower 79, Guard Tower 234, Keep 235, Bombard Tower 236, Donjon 1665 (Sicilian bonus). Guard Tower (tech 140) upgrades 79 -> 234 and Keep (tech 63) 79 and 234 -> 235, by effect type 3; build time 80 (Donjon 125). Other shooting buildings: Krepost 1251, Harbor 1189, Fortified Church 1806, Fortified Outposts 2415/2417. [data]

**Techs and effects**
- Age tech IDs: **101 Feudal, 102 Castle, 103 Imperial** (their dat `name`s are off by one: 101 is named "Middle Age"); go by ID. [data]
- Enable a unit: effect command type 2, `a = unit`, `b = 1`, appended to the age tech's effect. [game]
- Armor change effect: type 4, attribute 8, `d = ±(class*256 + value)`; armor class 4 = melee, 3 = pierce (vanilla Masonry uses `-1025` / `-769` for −1). [data]
- Speed multiply: type 5, attribute 5, `a = -1`, `b = class`, `d = factor`. [game]

**The Wonder**
- Its only task, the default one, is **action 120 "Generate Wonder Victory"**; a clone keeps starting the Wonder victory countdown until that task is removed. [game]
- Wonder units 276, 1368, 1369 sit on villager build slot 12; only 276 is ever enabled, by "Wonder Plans" (tech 144, effect 145). [data]

**Villager build menu**
- Train location `unit_id = 118` (builder). Page by `interface_kind`: 2 = economic, 10 = military. Slots 1–13 are taken on both pages; **slot 14 is the "more buildings" arrow**. A building on 14 is hidden. [game]
- Two units on one slot: the button showed the other unit's tooltip and cost. Give your building its own slot or remove the old unit's train location. [game]

**Task 161 "Unit refund"**
- `work_value_1` amount, `combat_level_flag` 0 = flat, `resource_out` resource (3 = gold), `work_range > 0` = pay the killer. [docs]
- `xsRemoveUnit` on such a unit fires the refund with no killer, which pays the **owner** (so a delivery swap refunds the cart's gold). [game]

**Unit look**
- Vanilla Ox Cart 1271 (corpse 1272) and Ox Wagon 1273 (corpse 1274) give carts a non-Trade-Cart look. [game]
- A trade task's `carrying_graphic_id` does **not** show for a unit moved by XS Move orders; swap unit types instead. [game]

**Unit classes used** (non-ship military): 0 archer, 6 infantry, 12 cavalry, 13 siege, 18 monk, 23 mounted gunpowder, 28 war dog, 35 petard, 36 cavalry archer, 44 hand cannoneer, 47 scout, 51/54 packed/unpacked trebuchet, 55 scorpion, 59 heroes and the King. Ships: 2, 20, 21, 22, 53. Villager 4, trade 19, livestock 58, 61. [data]

## 3. XS: verified behaviour

**Running**
- XS rules run every interval in RMS skirmishes, and from `Effects.xs` on any map (T1, T14). [game]
- `xsChatData`: its number argument is not reliably shown; build the number into the string (`"x " + value`). [game]
- `xsSetUnitCaption(id, text)` puts text over a unit; `""` clears it. Captions are big white text; players accepted them for buildings only. [game]

**Units and buildings**
- `xsGetPlayerUnitIds(p, objectId, arrayId)` fills and returns the array; it lists foundations too (a second Palace was blocked during construction). Use a separate array per list you need at the same time. [game]
- Construction finished: `xsGetUnitProperty(id, cUnitBuildpoints, owner) >= xsGetObjectAttribute(owner, objectId, cTrainTime, 0)`; the starting TC reads as finished (T18). [game]
- `xsSetUnitProperty(id, cUnitSelectable, 0)` blocks selection, including hotkeys and control groups, but an existing queue **keeps producing** (T7). [game]
- It does **not** drop a building the player already has selected: its command panel stays usable and queues new units and techs (bug report 2026-10-15). No XS function deselects a unit; the swap below does it as a side effect. [game]
- Cancel one building's queue **with refund**: `xsTaskUnits(oneIdArray, cActionTypeStop, vector(-1,-1,-1), -1, false, false, false, -1)` plus `xsStopUnit(id)`. `xsStopUnit` alone did not clear it (T8). [game]
- No deselect call: to stop a selected locked building from queueing, cancel its queue (above) every second while locked; each order is refunded and nothing is produced (T24). [game]
- Empty a building's garrison: `xsTaskUnits(oneIdArray, cActionTypeUngarrison, xsGetUnitPosition(id), -1, false, false, false, -1)`; check with `xsArrayGetSize(xsGetGarrisonedUnitIds(id))` (T23). [game]
- Route units: `xsTaskUnits(oneIdArray, cActionTypeMove, xsGetUnitPosition(target), -1, false, false, false, -1)`. [game]
- Swap a unit's type in place: read position and HP, `xsRemoveUnit`, `xsCreateUnit(type, p, pos, false, false, false)`, `xsSetUnitHitpoints`. No death sound, no extra losses in the statistics; the unit leaves the player's selection and control groups (T17). [game]
- The same swap works for buildings: a tower swapped to a data-mod twin stands exactly in place, finished, with its HP, and leaves the selection (T23). [game]
- **Create the root type, never an upgrade variant.** A Mill created as 130 or a TC as 141 (`xsCreateUnit`) had no units or techs to queue and took no drop-offs: train/research locations and drop-site lists name the root (68, 109), and an upgraded building keeps its root identity (T25, T26). Swap back to the root; it then gets the player's current age data (T29 passed). [game]
- Effects that name a unit by ID skip its clones: the Donjon's HP comes from age-ups and Hoardings naming 1665 (x2 Feudal, x1.2 Castle, x1.5 Imperial, x1.44), so its dark twin stays at 625 max and a swapped Donjon keeps at most that (playtest 2026-10-15). Kept as an out-of-supply cost (decision 2026-10-15). [game] [data]
- An age-up does not upgrade a clone: a dark Castle Age TC vanished from view at the Imperial age-up but still existed. Re-swap clones to the new age's twin (T30). [game]
- `xsGetTechState(tech, p) == cTechStateDone` reads a researched tech; type-3 upgrade effects do not touch clones, so pick the live type from the techs when swapping back (T23). [game]
- `dist(vectorA, vectorB)` gives tile distance and matches a hand-computed x/y distance. [game]
- Tasks: `xsGetUnitTaskCount`, `xsUnitTaskAmount(unit, i)` then `xsGetTaskAmount(cTaskAttr...)` read a unit's task `i`. `xsModifyUnitTasks` (per-unit edits) is untested in effect. [game] [docs]

**Players**
- `xsGetNumPlayers()` counts real players without Gaia (2 in a 2-player game): loop `for (p = 1; <= xsGetNumPlayers())`. With `<` the last player was never processed (T31). [game]
- Current age: `xsPlayerAttribute(p, cAttributeCurrentAge)`; Castle Age = 2. [game]
- `xsGetMapWidth()` returns the map width in tiles (Tiny 120: supply caps came out at 71%, T33). [game]
- Gold: `xsPlayerAttribute(p, cAttributeGold)` / `xsSetPlayerAttribute(p, cAttributeGold, v)`. [game]
- Block or allow building a type: `xsEffectAmount(cEnableObject, id, cAttributeDisable / cAttributeEnable, 0, p)`. Disabling a unit **before** the data enables it (Feudal Age) left it unbuildable; only disable after the data has enabled it. Re-enabling after a disable works (Palace rebuild, T16). [game]

**xs-check 0.2.30 quirks**
- `label` is a reserved word (parse error). [game]
- Constants shared across files must be `extern const`. [game]
- Assigning a float to an int warns (`NumDownCast`); `0 + float` warns (`FirstOprArith`). Keep floats, or build strings. [game]
- CLI: put the file path before `-I <dir>`. [game]
- It knows `cAttributeCurrentAge`, `cAttributeGold`, `cEnableObject`, `cAttributeEnable/Disable`, `cActionTypeStop/Move`, `cTaskAttr*`, `cTaskTypeAura`, `cUnitBuildpoints`, `cTrainTime`, `cCombatAbility`; probe unknown names with a tiny file. [game]

## 4. Dead ends (don't retry without new information)

- Per-TC aura switching via `xsModifyUnitTasks`: built, never confirmed; superseded (T20).
- Default unit debuff cancelled by TC auras: dropped; TC auras failed until all age variants were covered, and the design changed to a home-turf bonus.
- Aura range circles as a radius indicator (T15).
- Showing the loaded state with a trade task's carrying graphic (T17).
- Profile copies of XS/RMS as a deploy shortcut: they hide packaging bugs and override vanilla.

## 5. Tooling pitfalls on this Windows setup

- PowerShell 5.1 `Out-File` / `Set-Content` add a UTF-8 BOM: read TOML with `utf-8-sig`, strip BOMs from scripts.
- Batch files need CRLF; store them as `*.cmd -text` so a raw GitHub download keeps CRLF. Editing a `.cmd` from Python with `newline="\n"` strips CRLF again (a test checks).
- Generating Python or text through shell heredocs mangles `\n` escapes (several broken files). Write files with the editor tool, or use plain string edits without escapes.
- Tests must not assemble into the real `build\` (a `--no-dat` test once wiped the .dat right before a deploy); `tests/conftest.py` redirects it.
- `gh` is not installed and Git has no push credentials here; the user pushes. Use the GitHub API (`curl api.github.com/...`) for public read-only checks.
- Builds are reproducible: the same game files give the same .dat (compare `Get-FileHash`).
