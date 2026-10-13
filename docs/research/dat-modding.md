# Hinterland Supply Lines: AoE2 DE .dat research

Confidence levels: **High** means I confirmed it in a primary source I opened: source code, the UGC guide, or a data dump. **Medium** means a community source, or something inferred from code. **Unverified** means I found no source; test it in game.

## Key sources (all opened)
- UGC guide, Tasks: https://ugc.aoe2.rocks/general/tasks/tasks/
- UGC guide, Attributes (object attributes used by effects and XS): https://ugc.aoe2.rocks/general/attributes/attributes/
- UGC guide, Resources (player resources): https://ugc.aoe2.rocks/general/resources/resources/
- UGC guide, XS functions and constants: https://ugc.aoe2.rocks/general/xs/functions/functions/ and https://ugc.aoe2.rocks/general/xs/constants/constants/
- UGC guide, trigger effects: https://ugc.aoe2.rocks/scenarios/triggers/effects/effects/
- UGC guide, mod tools: https://ugc.aoe2.rocks/mods/tools/
- AGE source code, with the tooltip texts that document field meanings: https://raw.githubusercontent.com/Tapsa/AGE/master/AGE_Frame/Units.cpp and `Research.cpp`
- genieutils-py: https://github.com/SiegeEngineers/genieutils-py (`src/genieutils/unit.py`, `task.py`, `tech.py`, `versions.py`)
- SiegeEngineers/auto-mods: https://github.com/SiegeEngineers/auto-mods (`auto-mod.py`, `create-mods.sh`, `mods/ids.py`, `mods/util.py`, `mods/community_games.py`, `mods/rewarding_snipes.py`)
- aoe2techtree data: https://raw.githubusercontent.com/SiegeEngineers/aoe2techtree/master/data/data.json
- aoe2dat dump (archived repo): https://raw.githubusercontent.com/HSZemi/aoe2dat/master/data/units_buildings_techs.json

---

## 1. Defining a "Supply Cart" unit by cloning the Trade Cart

### Verified IDs
| Thing | ID | Source / confidence |
|---|---|---|
| Trade Cart (empty), internal name `TCART`, class 19, type 70, 70 HP, speed 1.25, cost 100W/50G, train time 51 | **128** | aoe2techtree data.json, aoe2dat dump, auto-mods `ids.py` `TRADE_CART = 128`. **High** |
| Trade Cart (full), internal name `TCARTF`, class 19 | **204** | aoe2dat dump. **High** for the ID; the dump is older, but these IDs are stable |
| Donkey trade unit `TDONK`, class 19 | 846 | aoe2dat dump. **High** |
| Trade Cog `COGXX` 17, Junk `JUNKX` 15, class 2 | 17 / 15 | aoe2dat dump. **High** |
| Town Center `RTWC` | **109** | techtree data and dump. **High** |
| Market `MRKT` | **84** | **High** |
| Dock 45, Castle 82, Barracks 12 | | dump. **High** |
| Unit class Trade Cart = 19 (XS `cTradeCartClass` = 919, which is 900 + class) | 19 | auto-mods `CLASS_TRADE_CART = 19`, XS constants. **High** |
| Castle Age tech | **102** (cost 800F/200G) | techtree data. The dat's *internal* names are shifted: tech 101 is named "Middle Age" (Feudal), 102 "Feudal Age" (Castle Age), 103 "Imperial Age". The costs confirm 102 is Castle Age. **High** |
| Heresy tech | **439** | auto-mods `ids.py`, techtree. **High** |

Empty and full are separate units (128 and 204), and the engine swaps between them when the cart carries goods. If you clone the cart, you probably need to clone **both**. The empty clone should point to the full clone through the trade task's carrying graphic, or through whatever mechanism links 128 to 204. I did not confirm which field links them; check the 128 tasks in AGE (**Unverified**). Without the trade task, one unit is enough.

### How to add the unit (genieutils-py pattern, from auto-mods `community_games.py` "Elite Petard")
```python
from genieutils.datfile import DatFile
# clone() = to_bytes -> from_bytes deep copy (auto-mods mods/util.py)
data = DatFile.parse('empires2_x2_p1.dat')
new_id = len(data.civs[0].units)
for civ in data.civs:                     # every civ, Gaia included, has its own unit array
    u = clone(civ.units[128], data.version)
    u.id = new_id; u.base_id = new_id     # copy_id/base_id: keep consistent (base_id seen in dump)
    u.name = 'SUPPLYCART'
    u.hit_points = 100                    # Unit.hit_points
    u.speed = 1.0                         # Unit.speed
    u.enabled = 0                         # 0 = needs a tech to become available (AGE tooltip)
    u.creatable.resource_costs = (...)    # ResourceCost(type, amount, flag); flag 1 = paid (0 = required but not paid, AGE tooltip)
    u.creatable.train_locations = [TrainLocation(train_time=40, unit_id=109, button_id=?, hot_key_id=...)]
    u.creatable.conversion_chance_mod = 2.0   # see section 3
    civ.units.append(u); civ.unit_pointers.append(1)
data.save('out/empires2_x2_p1.dat')
```
- Field names come from genieutils-py `unit.py`. `Unit` has `hit_points`, `speed`, `enabled`, `standing_graphic`, `dying_graphic`, `icon_id`, `resource_storages`, `dead_unit_id`, `blood_unit_id`, `class_`, and `language_dll_name`/`language_dll_help`. `Unit.bird` has `drop_sites` and `tasks`. `Unit.creatable` has `resource_costs`, `train_locations: list[TrainLocation(train_time, unit_id, button_id, hot_key_id)]`, `min/max_conversion_time_mod`, `conversion_chance_mod`, `hero_mode`, and `button_icon_id`. **High**
- **Train location** is TC 109. In DE the dat stores a *list* of train locations. Effects and XS can edit it too: attribute 42 "Train Location", 43 "Train Button", 158/159 for list entries, and the trigger effects "Add Train Location" and "Change Train Location". **High**
- **Button slot.** AGE tooltip: "First page (also second in TC) 1-15". I did not verify which TC slots are free, because Villager, Loom, Wheelbarrow, Hand Cart, Town Watch/Patrol and the age-ups occupy some. Inspect the TC in AGE, or test in game (**Unverified**).
- **Graphics.** Keep the cloned graphics, or change `standing_graphic`, `dying_graphic`, the task `moving_graphic_id`/`carrying_graphic_id`, and `icon_id`/`button_icon_id`. A new name or tooltip needs string IDs plus a `resources/<lang>/strings/key-value/key-value-modded-strings-utf8.txt` in the mod. That file layout comes from the universal-modder example, so **Medium**.
- **Castle Age gating.** Set `enabled = 0`, then enable the unit with an effect command of type 2 (Enable/Disable unit; `TYPE_ENABLE_DISABLE_UNIT = 2` in auto-mods), with `a=new_id` and `b=1`. Two options:
  - (a) Append the command to the effect of tech 102: `data.effects[data.techs[102].effect_id]`. This is simplest. **High** that it works, because effects are plain command lists.
  - (b) Add a new hidden tech with `required_techs=(102,-1,...)`, `required_tech_count=1`, no research location, and `civ=-1`. Civ bonus techs work like this and are auto-researched when their requirements are met. I did not find that auto-research rule documented (**Medium**).

  The tech creation API is shown in auto-mods `community_games.add_great_hall_tech`.

## 2. Trade behavior: shuttling between a TC and a destination

### What the Trade task is
- Task / action type **111 "Trade"** (XS `cTaskTypeTrade = 111`). **High**
- UGC Tasks page: "Adds the ability of the unit to trade for gold with other buildings." Its fields:
  - object attributes: Work Rate (`bird.work_rate`) and **Drop sites**, which triggers cannot change
  - task attributes: Work Value 1 (work rate multiplier), Resource In, Productivity Resource (secondary trade productivity), Resource Out (a secondary resource to trade for, besides gold), Carrying graphic, and **Object ID / Object Class** = the building to trade with.

  The page also says: "Since drop sites can't be changed with triggers this task can't be added", meaning not through XS/triggers. **High**
- Task struct fields in genieutils-py `task.py`: `task_type, id, is_default, action_type, class_id, unit_id, terrain_id, resource_in, resource_multiplier, resource_out, unused_resource, work_value_1, work_value_2, work_range, auto_search_targets, search_wait_time, enable_targeting, combat_level_flag, gather_type, work_flag_2, target_diplomacy, carry_check, pick_for_construction, moving/proceeding/working/carrying_graphic_id, sounds, enabled`. **High**
- `target_diplomacy` (AGE tooltip "Owner Type"): 0/7+ all objects, 1 yours only, 2 neutral and enemy, 3 Gaia, 4 Gaia/yours/ally, 5 Gaia/neutral/enemy, 6 all but yours. **High** for the meaning. In vanilla you cannot trade with your own markets; a player thread confirms this behavior: https://forums.ageofempires.com/t/market-trade-with-yourself-with-trade-carts/281603. Whether vanilla blocks it through `target_diplomacy` or through hardcoded logic is **Unverified**.
- How gold is computed: player resources **70/71** "Source Market or Dock X/Y Coordinate" control how much gold carts deposit "when the source market is changed". So gold depends on distance from the source (home) building's coordinates (UGC Resources). Resource 101 is "Trade Income Sum"; 251/252/253 are Trade Food/Wood/Stone Percent (Bengali-style extra resources). **High**
- **Return endpoint = drop site.** Trade units deposit at their `bird.drop_sites` list (AGE "Drop Sites"). The engine chooses the trade partner from the task's Object ID/Class, and the home deposit from the drop sites. **Medium**: I inferred this from the task docs and AGE's "Resource deposited on drop site" tooltip.

### Can the endpoints be a TC, Barracks or Castle?
- By the data model, **probably yes.** Set the trade task `unit_id = -1` and `class_id = 3` (Building class; auto-mods `CLASS_BUILDING = 3`), or set `unit_id` to a specific building such as 109, 82 or 12. Then set `bird.drop_sites = [109]` so the cart returns to a TC. I found **no public mod or documentation showing trade to a non-Market or non-Dock building working in DE**. That includes the trade-gold calculation using a TC as the source, and the auto-repeat shuttling. **Unverified: build a test dat first.**
- Known references: Trade Cog/Junk use the Dock (45) as target and drop site. Mule Cart / AGE tip: "Giving to a villager drop site to cart-like unit can allow you to have mobile resource-gatherers". This shows drop sites are freely editable in the dat. **High**
- **Zeroing or redirecting gold** (**Medium**; untested):
  - Set `bird.work_rate` to 0, or `work_value_1` to 0. This may also break the "carrying" state or the loop.
  - Set Resource Out to another resource to get a secondary payout.
  - Use a civ effect setting resource 251-253 for extra outputs.
  - A cleaner idea: keep a tiny work rate and use an unused player resource as Resource Out, so XS can read deliveries via `xsPlayerAttribute`. **Unverified**

### Fallback if Trade will not target a TC (recommended to prototype in parallel)
- Remove the trade task, so the cart is a plain moving unit. Drive it with XS in a `rule` loop:
  - Find carts: `xsGetPlayerUnitIds(player, cartObjectId)`.
  - Detect arrival: `xsGetUnitPosition` / `xsGetUnitMoveTarget`.
  - Send to the next endpoint: `xsTaskUnits(unitIds, cActionTypeMove /*1*/, location, locationUnitId, isShiftQueue)`.

  The trigger "Task Object" effect can do the same, including "Queue Action" for shift-queuing. **High** for the API (UGC functions and effects pages); the gameplay quality depends on how you implement it.
- Give supply "deliveries" with `xsSetPlayerAttribute` or the Modify Resource effect.
- XS only runs from a scenario (Map tab "Script Filename") or an RMS (`#includeXS file.xs`); per the UGC beginner guide, included XS files are distributed to players. I found **no** evidence that a data mod by itself can auto-run XS in every game (**Unverified**). So plan to ship an RMS (or a scenario) with the mod.

## 3. Conversion

- **Per-unit resistance:** `Unit.creatable.conversion_chance_mod` (AGE: "Modifier to the overall chance it takes to convert this unit"). It is object attribute **113 "Conversion Chance Modifier"**: "The probability of conversion every monk second is divided by this value for the unit". Also per unit:
  - 111/112: Min/Max Conversion Time Modifier (`min/max_conversion_time_mod`)
  - attribute 40 Hero Status, with flag 2 "Cannot be Converted" (`creatable.hero_mode`)

  **High**
- **Player-wide resistance:**
  - resource **77 "Conversion Resistance"** (XS `cAttributeConvertResistance = 77`): conversion chance is divided by it for all of the player's units
  - **178/179** "Convert Resist Min/Max Adjustment": extra monk-seconds before conversion is possible or forced

  Careful: *attribute* IDs 178/179 are cost-type fields. These are *resource* IDs, a different numbering space. **High**
- **Heresy:** tech 439. It sets resource **192 "Converted Units Die"** (XS `cAttributeHeresy = 192`) to 1, so "converted units die instead of switching over to the enemy". This is **player-wide**, not per unit. **High**
- I found no per-unit "die when converted" field (**Medium**: no documentation of one). Options for carts only:
  - (a) Make them unconvertible (hero_mode flag 2).
  - (b) Give them a very high `conversion_chance_mod`.
  - (c) Use XS to detect a cart whose owner changed (`xsGetUnitOwner`) and kill it (`xsRemoveUnit` / Kill Object effect).

## 4. Death-cause hooks: "destroyed cart, attacker gets gold"

- **Native solution: task 161 "Unit refund"** (XS `cTaskTypeRefund = 161`). UGC: "Resource to grant on death". Its fields:
  - **Work Range**: 0 refunds the *owner*; **>0 grants the resource to the killer**
  - Combat Level Flag: 0 means Work Value 1 is a flat amount, 1 means a fraction of the unit's cost
  - Productivity Resource: a multiplier
  - Resource Out: the resource granted (3 = gold)

  Add it to the cart's `bird.tasks` in the dat. **High** for the documentation; untested by me. Conversion is not death, so converting the cart should not pay the killer (**Unverified**).
- **Alternative on the attacker side: task 154 "Loot"** (`cTaskTypeLoot`). It gives resources and attributes after killing or converting a filtered object (Object ID/Class target). The UGC example has Attila gaining 2 gold per kill. You could put it on military classes and target class 19, the carts. **High** for the documentation.
- Existing related resources: 274 "Infantry Kill Reward" enables gold per second while infantry fight villagers, trade units and monks (Vikings get it with Chieftains); 284 "Cavalry Kill Reward". **High**
- **Resource storage modes** (AGE tooltip): 0 Keep/decayable; 1 "Give. Stored after death also"; 2 "Give and take. Resets on dying"; 4 Building, enables on completion; 8 (UP); **32 (DE) "Stored throughout dying animation"**. None of these transfer to the killer, so storages are *not* the hook. Use task 161. **High**
- Other on-death fields:
  - `dead_unit_id` (attribute 57): spawns a unit on death
  - `blood_unit_id` (66): a second spawned unit. auto-mods `rewarding-snipes` uses the King's blood unit to spawn a cloned Relic Cart that gives pop via storage flag 2
  - attribute 205 "Pile Unit"

  A spawned marker unit can be polled by XS to detect *where* a cart died. **High**
- XS has no documented "killer of unit" function among those listed (**Medium**). Per-player counters exist: resources 300-308 "Killed Gaia..P8" and 325-333 "Kills by Gaia..P8".

## 5. "Make Capital" TC command

- **Tech button at the TC:** a new `Tech` with `research_locations=[ResearchLocation(location_id=109, research_time=..., button_id=..., hot_key_id=...)]`. The full constructor is shown in auto-mods `community_games.py`. **High**
- **Repeatable:** the dat `Tech.repeatable` field exists (genieutils-py, AGE "Repeatable"). Vanilla Loom has `Repeatable=True` in techtree data, yet Loom is researched only once, so this flag alone does **not** make a tech re-researchable. Its exact meaning is **Unverified**; it is likely related to whether stacking is "allowed" (`cTechStackingAllowed`). Real repetition is enabled at runtime:
  - trigger effect **"Enable Technology Stacking"**: "allow a technology to be researched multiple times, stacking its effects", with a Quantity cap
  - or XS `xsEffectAmount(cModifyTech /*8*/, techId, cAttrSetStacking /*9*/, 1, player)` plus `cAttrSetStackingResearchCap` (10)
  - or RMS `ATTR_SET_STACKING`

  **High** for the trigger and XS docs; forum confirmation: https://forums.ageofempires.com/t/mod-to-develop-technology-multiple-times/258814
- **Cooldown:** XS disables the tech after it completes (`xsEffectAmount(cModifyTech, tech, cAttrSetState /*12*/, ...)`, or the Enable/Disable Technology effect), then re-enables it after N seconds in a timed `rule`. **Medium**: the API exists, but the exact state values are untested.
- **Detection:**
  - (a) `xsGetTechState(tech, p) == cTechStateDone`; with stacking, compare counts instead.
  - (b) More robust: the tech's effect does "+1 to an unused player resource" (effect command type 1, Resource modifier), and XS polls `xsPlayerAttribute`.
  - **Which TC researched it** is not exposed by any function I found. The workaround is a train button for a dummy "Capital Charter" unit (Train Location 109). It spawns next to the TC that trained it; XS finds the new unit (`xsGetPlayerUnitIds`, then `xsGetUnitPosition`), maps it to the nearest TC, and removes it. **Medium** for the design (my inference); **High** that the functions exist.

## 6. Lowering base stats: .dat versus start-of-game tech

- **Edit the .dat directly.** Change the per-civ unit entries for every civ, plus *upgrade targets*: an Upgrade Unit effect (type 3) swaps in the target unit's dat stats, so lower those too. Tooltips, the tech tree and the in-game stats then show the new baseline. Civ bonuses and techs that **multiply** (type 5) then scale from the lower base; **add/subtract** (type 4) bonuses become relatively stronger; **set** (type 0) effects override your value entirely. **High** for the effect types: auto-mods `ids.py` has `TYPE_RESOURCE_MODIFIER=1`, `TYPE_ENABLE_DISABLE_UNIT=2`, `TYPE_UPGRADE_UNIT=3`, `ATTR_MODIFIER_MULTIPLY=5`, and team versions are +10 (`teamwork.py`). XS constants `cSetAttribute=0`, `cAddAttribute=4`, `cMulAttribute=5`.
- **Debuff through a start-of-game tech** (a hidden auto-researched tech, or one added to the Dark Age effect, or XS `xsEffectAmount` at game start). This keeps vanilla numbers in the dat, so patch diffs are easier. But the UI may show un-debuffed values in some places, and ordering against civ bonus "set" effects matters. **Medium**
- Recommendation: put the debuff in the patch script as dat edits on a list of unit IDs (and their upgrade lines). Re-applying it after every patch is cheap.

## 7. Packaging, multiplayer, patches, and script-built mod repos

### Local mod layout (Windows, Steam)
```
%USERPROFILE%\Games\Age of Empires 2 DE\<SteamID>\mods\local\HinterlandSupplyLines\
  info.json                               # Title, Author, Description (game adds CacheStatus)
  thumbnail.png                           # optional; requirements not documented anywhere I found
  resources\_common\dat\empires2_x2_p1.dat
  resources\_common\dat\civilizations.json   # recommended copy, so the mod survives civ-count changes
  resources\_common\xs\hinterland.xs         # XS, referenced by an RMS/scenario
  resources\_common\drs\gamedata_x2\*.rms    # RMS path: Unverified, check an existing published map mod
  resources\en\strings\key-value\key-value-modded-strings-utf8.txt
```
- The local mods path and `info.json` fields (author, description, title): https://forums.ageofempires.com/t/guide-to-modding/61109. **High** (community)
- The `<profile>\mods\local\<Mod>` layout, the `info.json` rewrite with `CacheStatus`, the `mods\mod-status.json` registration, and the dat / civilizations.json / strings layout: https://github.com/rehan-remade/universal-modder/tree/main/examples/aoe2-de-civ. **Medium-High**
- auto-mods builds `build/<mod>/resources/_common/dat/empires2_x2_p1.dat`, copies `civilizations.json` next to it, and zips each mod folder (`create-mods.sh`). **High**
- **Enabling a mod:** local mods appear in the in-game Mod Manager. A data mod is chosen from the **"Data Mod"** dropdown in the game settings (Skirmish, Editors, Campaign). "You can only use one at a time"; "You can use them in multiplayer, when in lobby host selects it": https://forums.ageofempires.com/t/data-mod-dont-work/82890. **High** (community)
- **Multiplayer:**
  - Only data mods **published** through the Mod Manager or the website can be selected when hosting multiplayer. This was a community claim in search snippets of a Steam thread I could not open. **Medium**
  - Joining players are auto-subscribed or prompted to download, but version mismatches give a "wrong data file" error and force a rehost: https://forums.ageofempires.com/t/if-someone-doesnt-have-a-specific-mod-when-somebody-hosts-the-lobby-does-it-install-it-for-them/112592. **Medium**
- **Upload:** zip the mod folder contents, preserving `resources\_common\...`, and submit via https://www.ageofempires.com/mods/ ("Submit a Mod"). Re-uploading replaces the version: https://forums.ageofempires.com/t/how-do-you-create-a-installable-mod/125688. **Medium**
- **Patches break dat mods.** A data mod ships a full dat, so any game patch that changes balance or the dat format makes it outdated or incompatible. Hence auto-mods' tagline: "generated programmatically, so they can be recreated automagically for every new patch". genieutils-py only supports DE dat versions GV_C20+ (FileVersion 7.7+; `versions.py` lists up to VER 8.9), so after a format change, update the library and re-run. **High**

### Recommended workflow
1. `pip install genieutils-py`. Optional: `dat-to-json` for diffs.
2. Write `build.py`: parse the vanilla `...\steamapps\common\AoE2DE\resources\_common\dat\empires2_x2_p1.dat`, apply idempotent patch functions, save to `build/HinterlandSupplyLines/resources/_common/dat/`, copy `civilizations.json`, the XS and the RMS, write `info.json`, and zip.
3. After each game patch, re-run, smoke-test in Skirmish, and re-upload.

### Script-built mod repos
- **SiegeEngineers/auto-mods** (Python, MIT), https://github.com/SiegeEngineers/auto-mods
  - `auto-mod.py input.dat output.dat --mods <names...> [--cache]` (pickle cache of the parsed dat)
  - `mods/` has one module per mod, each exposing `NAME` and `mod(data)`, plus `ids.py` (named IDs) and `util.py` (`clone`, `disable_unit`, ...)
  - `create-mods.sh` builds and zips every mod; `dat/`, `html/` and `.github/workflows` are also present

  Best template.
- **Krakenmeister/genieutils-examples**, https://github.com/Krakenmeister/genieutils-examples: `create_mod.py`, `constants/`, `mods/` examples, output to `datfiles/empires2_x2_p1.dat`, with caching.
- **rehan-remade/universal-modder** `examples/aoe2-de-civ`, https://github.com/rehan-remade/universal-modder/tree/main/examples/aoe2-de-civ
  - `build_mod.py` (genieutils-py) builds units, techs, effects, JSON and strings into `build/<Mod>`; `--install` copies it to `mods\local` and registers it in `mod-status.json`
  - also has `aoe2paths.py` (finds the install and profile folders), sprite/SLD tools and scenario generation
- **GoKuModder/aoe2-genie-tooling**, https://github.com/GoKuModder/aoe2-genie-tooling: an object-oriented wrapper with multi-civ propagation and task/effect builders, on the Rust-backed GenieDatParser. It is not genieutils-py.
- Alternative parser: **Divy1211/GenieDatParser**, https://github.com/Divy1211/GenieDatParser
- I did not find public build-script repos for the "Community Patch" or "Hera" style mods you mentioned.

## Open items to test in game
1. A trade task with Object ID 109 (or class 3) plus `drop_sites=[109]`: does the cart auto-shuttle, and is gold distance-based?
2. `target_diplomacy` 1 or 0 on the trade task: does it allow trade with your own buildings?
3. The empty-to-full cart link (128 to 204) for cloned carts.
4. Task 161 with Work Range > 0 pays the killer, and does not pay on conversion.
5. Free TC button slots.
6. Whether a data mod can auto-run XS without an RMS or scenario (assume no).
