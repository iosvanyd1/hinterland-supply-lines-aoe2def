# Hinterland Supply Lines: AoE2:DE triggers, XS, UI, multiplayer and performance research

Researched 2026-10-13. Confidence labels:
- **VERIFIED**: I read it in a primary or authoritative source (official patch notes, or the UGC guide source repo, which was last updated 2026-10-10).
- **LIKELY**: strong indirect evidence or a consistent community report.
- **UNKNOWN**: no source found. Test it in-game.

Where the sources are:
- The UGC guide's effect and condition pages are generated from the AoE2ScenarioParser definitions. I read them from the repo source (https://github.com/Divy1211/AoE2DE_UGC_Guide). The rendered pages are at https://ugc.aoe2.rocks/scenarios/triggers/effects/effects/ and https://ugc.aoe2.rocks/scenarios/triggers/conditions/conditions/.
- XS function and constant references: https://ugc.aoe2.rocks/general/xs/functions/functions/ and https://ugc.aoe2.rocks/general/xs/constants/constants/.

---

## 0. Corrections to the effect and condition names in the brief (VERIFIED, none of these exist under these names)

| Name in the brief | Actual DE effect or condition |
|---|---|
| "Disable/Enable Object Creation" | **Enable/Disable Object**: per type, per player, with an Enabled checkbox. |
| "Enable/Disable Technology" | **Enable/Disable Technology** exists under exactly this name. |
| "Change Object Player" | **Change Ownership** (effect). XS has `xsSetUnitOwner`. |
| "Transform Object" | Does not exist. Use **Replace Object** (area, type/class filters, or Selected Units). |
| "Units Killed"/"Building Destroyed" as conditions | These are not conditions. They are **player resources** (see §2), read with **Accumulate Attribute** or XS `xsPlayerAttribute`. |
| "Object in Area with unit/class filters" | **Objects In Area** has Object, Object Group (class), Object Type, Unit State and Include Transformable Units filters. |
| "Object Not Visible" | Exists but is **deprecated since 1.36** and unreliable. Use **Object Visible Multiplayer**, with Inverted if needed. Since Sept 2026 it has an "Allow in Fog" checkbox. |

---

## 1. Trigger conditions and effects: which ones target single objects or areas, and which target a whole type

### 1a. Conditions (VERIFIED, UGC conditions page)
- **Objects In Area**: Quantity, Object, Source Player, Area, Object Group, Object Type, **Unit State**, Include Transformable Units.
- **Own Objects** and **Own Fewer Objects**: the same filters, map-wide. Own Fewer Objects also takes an optional Area.
- **Accumulate Attribute**: checks that a player has at least N of a resource, where the resource can be any player attribute (kills, conversions and so on).
- **Timer**: seconds since the trigger became active. "Inverted" means the condition succeeds only before that time.
- **Variable Value** (Quantity, Variable, Comparison) and **Compare Variables**.
- Other conditions that matter for this mod:
  - **Destroy Object** (one specific unit)
  - **Capture Object** (a specific unit is now owned by the Source Player)
  - **Object HP**
  - **Object Has Target** (unit's target is a specific unit, or one matching object/class/type)
  - **Object Has Action** (flagged in the docs as "not always consistent due to a bug")
  - **Object Attacked**
  - **Object Visible Multiplayer**
  - **Units Garrisoned**
  - **Building Is Trading**
  - **Researching Tech**, **Technology State**, **Local Tech Researched**
  - **Display Timer Triggered**
  - **Script Call** (an XS bool function)
  - **Chance**
  - **And** / **Or**
- Looping triggers re-check **once per second** (UGC trigger basics, https://ugc.aoe2.rocks/scenarios/triggers/).

### 1b. Effects and their targeting (VERIFIED, UGC effects page)
"Per object" means the effect has Area, Selected Units (specific instances, which override all other filters) and usually Max Units Affected. "Per type" means it changes the player's object definition, so every current and future unit of that type is affected.

| Effect | Targeting |
|---|---|
| **Modify Attribute**, **Modify Attribute By Variable** | **Per type** (Object + Source Player). Has Quantity Float and Message for string attributes. |
| **Modify Attribute For Class** | Per class/type, player-wide. |
| **Modify Object Attribute**, **Modify Object Attribute By Variable** (added Aug 2025, Update 153015) | **Per object**: Selected Units or Area. "Can modify stats of specific units on the map." The "Object Modified State" filter (All / Previously Unmodified / Previously Modified) was renamed in Sept 2026 (Update 185872). |
| **Change Object HP**, **Damage Object**, **Heal Object** | Per object (Area/Group/Type/Selected Units/Max). Max HP is capped at 32768. |
| **Change Object Name** | **Per object**: Area/Selected Units/Max, with a custom Message. "Barracks [Supply 45s]" on one building is possible. |
| **Change Object Caption** | **Per object**: text shown *above* units (overhead). Custom strings are allowed since Update 153015. |
| **Change Object Description** | **Per type per player** only: no Area and no Selected Units. Supports placeholders such as `<hp> <attack> <armor> <Cost>`. |
| **Change Object Icon** | Per object (Area/Group/Type/Selected Units). Uses the icon of a Secondary Object. |
| **Change Ownership** | Per object (Area/Group/Type/Selected Units/Max). Has a Flash Unit option. |
| **Replace Object** | Per object (Area/Group/Type/Selected Units/Max). Has Target Player and Secondary Object. |
| **Create Object**, **Create Garrisoned Object**, **Remove Object** (has Unit State), **Kill Object** | Per object or location. |
| **Task Object** | Per object. Has Action Type, Queue Action (shift), Issue Group Command. "Unload" was renamed "Unload All" and "Ungarrison" became "Ungarrison Specific" (Sept 2026). |
| **Stop Object**, **Freeze Object**, **Patrol**, **Attack Move**, **Teleport Object**, **Unload** | Per object. |
| **Disable/Enable Unit Targeting**, **Disable/Enable Unit Attackable**, **Disable/Enable Object Selection**, **Disable/Enable Object Deletion** | Per object (Area/Selected Units/Max). |
| **Set Building Gather Point** | Per object (Area/Selected Units/Max). |
| **Train Unit** | Per building (Area/Selected Units/Max). Queues units and deducts cost. |
| **Initiate Research** | One building (Selected Units). Deducts cost. |
| **Research Local Technology** | A tech whose effect applies only to selected units and/or an area. |
| **Change Train Location**, **Add Train Location** | **Per type per player** (unit type → building *type*, button, train time, hotkey). |
| **Change Research Location** | **Per tech per player** (tech → building *type*). |
| **Enable/Disable Object**, **Enable/Disable Technology** | Per type or tech, per player. |
| **Enable Technology Stacking** (Quantity = max times), **Disable Technology Stacking** | Per tech. |
| **Research Technology** | Per player. Has a Force option. |
| **Modify Resource**, **Modify Resource By Variable**, **Tribute** | Per player. Negative tribute to Gaia gives a silent trickle. |
| **Change Variable**, **Modify Variable By Resource / By Attribute / By Variable**, **Counts Units Into Variable** (Object/Area/Group) | Variables. |
| **Display Timer**, **Clear Timer**, **Display Instructions**, **Clear Instructions**, **Send Chat**, **Play Sound**, **Change View**, **Create Decision** | UI. |
| **Change Color Mood** | Exists. Has a fade time. |
| **Script Call** | Calls an XS function. |

**XS equivalents** (VERIFIED, from Update 153015 (Aug 2025) and Update 185872 (Sept 22, 2026)). Every one of these works per unit ID:
- `xsGetPlayerUnitIds(player, objOrClass, reuseArray)`
- `xsDoesUnitExist`, `xsGetUnitOwner`, `xsGetUnitPosition`, `xsGetUnitHitpoints` / `xsSetUnitHitpoints`
- `xsGetUnitAttribute`, `xsGetUnitTargetUnitId`
- `xsSetUnitName`, `xsSetUnitCaption`, `xsSetUnitOwner`
- `xsGetUnitProperty` / `xsSetUnitProperty` (properties: Targetable, Attackable, Selectable, Visibility, Locked, ActionId, OrderId and others)
- `xsTrainObject(buildingId, objectId, count)`, `xsInitiateResearch`, `xsResearchLocalTechnology`
- `xsSetUnitGatherPoint`, `xsTaskUnits`, `xsStopUnit`

These two remain per type: `xsEffectAmount` and `xsSetObjectDescription(player, objectId, text)`.
- https://www.ageofempires.com/news/age-of-empires-ii-definitive-edition-update-153015/
- https://www.ageofempires.com/news/age-of-empires-ii-definitive-edition-update-185872/

### 1c. Can training or research be disabled at one building instance?
- **Change Train Location, Add Train Location and Change Research Location cannot do it (VERIFIED).** They map a unit type or tech to a building *type* per player. Train locations are a per-type list edited through `cTrainLocationsEntryMod` and `cTrainLocationsTotalNum` (https://ugc.aoe2.rocks/general/xs/tricks/). Enable/Disable Object and Enable/Disable Technology are also per player and type.
- **Workarounds, in order of how practical they look:**
  1. **Swap the instance to a clone building type.** Add a data-mod copy such as "Barracks (Cut Off)", with no units trained there (they would just be type IDs whose train-location lists do not include the clone). Then run **Replace Object** with Selected Units on that one building, and replace it back when supply returns. Replace Object itself is VERIFIED to work per instance. **UNKNOWN**: whether the swap keeps HP, garrison, queue and the player's control groups, and how it interacts with the age-up graphic replacements. Test this first.
  2. **Clear the queue with Stop Object or Freeze Object at one building, and keep re-clearing.** **VERIFIED**: since Sept 2026, "Stop Object/Freeze Object/Task Object (Stop action) triggers will now correctly clear building production queues" (Update 185872). **UNKNOWN**: whether resources are refunded, and whether a frozen building can still accept new queue clicks.
  3. **Raise the train time at a local building (UNKNOWN feasibility).** Tech effect types 200/201 "set/add attribute value for the local building where the tech … was researched" (Update 128442, Nov 2024). Research Local Technology / `xsResearchLocalTechnology` can apply a tech to selected units only. I found nothing showing that a local building attribute can slow or block training there.
  4. **Per-unit property `cUnitLocked`** exists in `xsSetUnitProperty`. Its semantics are undocumented (UNKNOWN).
  - https://www.ageofempires.com/news/age-of-empires-ii-definitive-edition-update-128442/

---

## 2. Telling whether a unit was killed, converted, or converted with Heresy

- **Ownership persists through conversion (LIKELY).** The engine keeps the same unit reference when ownership changes. The **Capture Object** condition (a specific unit is now owned by the Source Player) and `xsGetUnitOwner(unitId)` both depend on that. This makes per-cart tracking feasible.
- **Recommended XS detection loop:**
  1. Keep an array of cart unit IDs and their expected owner.
  2. Every N seconds, check `xsDoesUnitExist(id)`:
     - Exists, with `xsGetUnitOwner(id)` different from the expected owner → **converted** (or captured). VERIFIED that the functions exist. The semantics are LIKELY.
     - Gone → **died**. Possible causes are a kill, deletion, Heresy-conversion death, or a trigger Kill/Remove.
  3. Optionally cache `xsGetUnitHitpoints(id)` each tick. A unit that vanishes at high HP is a hint of a Heresy death or a deletion rather than a kill (heuristic, UNKNOWN reliability).
  4. In trigger-only form, use **Destroy Object** and **Capture Object** on a specific unit. Those conditions need units placed in the editor, so on random maps use XS.
- **Player resources that work as counters (VERIFIED IDs, https://ugc.aoe2.rocks/general/resources/resources/):**

| ID | Resource |
|---|---|
| 20 | Units Killed (excluding buildings) |
| 43 | Razings |
| 154 | Killed by Others (own units killed by other players) |
| 155 | Razed by Others |
| **240** | **Units Converted** ("the amount of units lost to enemy conversions") |
| 192 | Converted Units Die (Heresy flag; 1 = yes) |
| 300–308 | Killed Gaia / Killed P1..P8 |
| 325–333 | Kills by Gaia / Kills by P1..P8 (own units killed by each player) |

  Snapshot-diffing 154, 240 and 325–333 on the victim player in the same tick as a cart disappears lets you attribute the cause, as long as only one loss happens per tick. That is a heuristic.
- **UNKNOWN**: whether a Heresy conversion death increments 240 (Units Converted), 154 (Killed by Others), or both. Test it, because this decides the Heresy branch.
- **Object Has Target**, or `xsGetUnitTargetUnitId` on enemy monks, could flag "a monk is targeting cart X" just before it changes owner. That supports the heuristic only (LIKELY to work, untested).

---

## 3. UI options

- **Display Timer** (VERIFIED): it has a Timer ID ("multiple timers can be shown simultaneously"), a time unit, `<TIMER>` / `%d` placeholders, and colour prefixes such as `<RED>`. `xsDisplayTimer(timerId, msg, time, unit, reset, playerId)` can show a timer to **one player only**. **UNKNOWN**: the maximum number of timer IDs and simultaneous timers; I found no source.
- **Display Instructions** (VERIFIED): there are **3 panel positions** (`cPanelTop`, `cPanelMiddle`, `cPanelBottom`), and each panel shows one message at a time. `xsDisplayInstructions(..., playerId)` can target **one player**. It takes an icon from an object and colour prefixes.
- **Per-object name**: Change Object Name, or `xsSetUnitName` (VERIFIED). "Barracks [Supply 45s]" on one building is doable. Updating it every second for many buildings has unknown cost.
- **Overhead text**: **Change Object Caption** or `xsSetUnitCaption` puts per-unit text above a unit (VERIFIED). This is the closest thing to an overhead indicator. Overhead *icons* are not available as a trigger feature (UNKNOWN; I found nothing).
- **Description**: per type per player only (Change Object Description / `xsSetObjectDescription`). It is not per instance.
- **Icon**: Change Object Icon works per object, but only by borrowing another object's icon (VERIFIED).
- **Custom UI panels**: I found no trigger or XS API. UI mods exist only as client-side file mods (layout and graphics), not as scriptable widgets (LIKELY).
- **Minimap**: the .dat unit fields include `MinimapMode` and `MinimapColor` (genieutils source, https://github.com/Tapsa/genieutils/blob/master/include/genie/dat/Unit.h). `MinimapMode` can be modded through the attribute `cMinimapMode` (144), with values None / Unit / Building / Terrain / TerrainBig (UGC constants §40).
  - Legacy genieutils notes: mode 1 is a square dot, 2–3 a diamond, 0 or 6–10 no dot.
  - A distinct **shape** (square vs diamond) via a data mod is LIKELY.
  - A distinct **colour** for player-owned units is UNKNOWN; player units probably render in player colour. Community reports say the minimap palette is limited to 256 fixed colours (https://forums.ageofempires.com/t/how-can-i-mod-the-mini-map-colors-design/85692).
- **Fog-aware enemy info**:
  - The **Object Visible Multiplayer** condition takes a Source Player and has "Allow in Fog" (Sept 2026).
  - `xsGetUnitProperty(unitId, cUnitVisibility, player)` is synced per player (VERIFIED as an API; semantics LIKELY).
  - `xsUnsyncIsUnitVisible` is **unsynced**: use it only for display, never for game logic (VERIFIED warning).
  - `xsUnsyncGetLocalPlayerId` must only drive chat or UI, or the game will desync (VERIFIED warning).

---

## 4. Multiplayer

- **Random maps cannot contain scenario triggers.** An RMS gets logic only through **`#includeXS file.xs`**: `main()` runs at map generation, and XS rules provide ongoing logic (VERIFIED: https://ugc.aoe2.rocks/general/xs/beginner/; Zetnus RMS guide https://docs.google.com/document/d/1jnhZXoeL9mkRUJxcGlKnO98fIwFKStP_OBozpr0CHXo).
  - Rules keep running during an RMS game (LIKELY). A Sept 2026 forum user runs a 4-second XS rule from an RMS in skirmish: https://forums.ageofempires.com/t/out-of-sync-multiplayer-mod-touching-random-map/289392.
  - Use runtime name `"Random Map"` with `xsAddRuntimeEvent`.
- **Scope of XS functions in RMS:**
  - Nov 2024 notes said the xsTask functions were "only supported in Custom Scenarios".
  - Aug 2025 notes say they are "no longer limited to scenario games".
  - The Sept 2026 unit functions carry no scope note.
  - Verdict: most unit functions working in RMS is LIKELY but not explicitly stated. Test each function you use.
- **Transfer of files:**
  - Included **XS files DO transfer automatically** to players and spectators (Zetnus guide).
  - Aug 2022: "XS files now transfer correctly on either Subscribed or Local Mods (but still don't work for spectators)".
  - Recursive XS `include` from other sources has historically not transferred (UGC "Fixed" bug list).
  - **Bug: XS is not included in recorded games** (Zetnus guide), so expect broken recs.
  - Included *.rms* files do NOT transfer.
- **Data mods:**
  - Selected in lobby settings. "Players will now be prompted to subscribe to a data mod as soon as they join a lobby" (Update 35584).
  - Unlisted mods "download automatically when a user joins a lobby where the mod is being run" (same notes): https://www.ageofempires.com/news/aoe2de-update-35584/.
  - A 2021 fix covered players being booted when joining with an outdated data mod version (LIKELY, Update 51737 via search summary).
  - All players need the same version.
- **A data-mod-only hook (VERIFIED, Aug 2025):** tech effects can call XS by setting **resource 33**, which invokes `EffectFunctionN` in a new **Effects.xs**, so a data mod can carry XS logic. Sept 2026 fixed "rules in Effects.xs would run multiple times instead of just once at the start of the game". That wording is ambiguous; test whether Effects.xs rules loop.
- **Recommended packaging:**
  - Ship as an **RMS mod** (map plus `#includeXS`). Add a **data mod** only for clone units or buildings (supply carts, "cut-off" building variants).
  - Publish on the official mod centre (mods.ageofempires.com). Subscribed mods auto-update (Update 35584).
  - Scenarios use the separate lobby Game Mode "Custom Scenario", which lists the host's subscribed scenarios (https://devtrackers.gg/aoe/p/68679c6c-play-these-custom-scenarios-with-all-your-friends-in-aoe-ii-de, 2024).
  - A scenario gives you real triggers but a fixed map.
- **Ranked**: ranked is matchmaking-only with official map pools and no custom lobbies, so the mod is **unranked lobbies only** (LIKELY; forum consensus: https://forums.ageofempires.com/t/community-growth-and-changes-map-pools-ranked-ladder/175090).
- **Desync risks:**
  - Never use `xsUnsync*` results in logic.
  - Deprecated **Object Selected**, Object Visible and Acknowledge AI Signal cause desyncs in MP (VERIFIED).
  - RMS + XS rule desyncs at game start are reported but unanswered (thread above, Sept 2026). A guess, not verified: wall-clock or locally varying values in the rule.
  - Keep logic deterministic: use `xsGetGameTime` / `xsGetTurn` and the synced RNG `xsGetRandomNumber`.
- Since Aug 2025, Task Object, Patrol, Attack Move and Change Diplomacy act "instantly … without being affected by network delay" in MP (Update 153015).

---

## 5. Performance

- **Rule syntax (VERIFIED, UGC)**: `minInterval` / `maxInterval` are in integer seconds. `highFrequency` "loops the rule 60 times every physical second" (UGC wording). The official notes say "high-frequency rules run every turn" (`xsGetTurn`, Update 153015). You cannot combine `highFrequency` with intervals. `priority` sets the order. `xsSetRuleMinInterval` / `xsSetRuleMaxInterval` change intervals at runtime.
- Looping triggers re-check once per second. A community DE guide recommends timers of 2 seconds or more for loops (Steam guide https://steamcommunity.com/sharedfiles/filedetails/?id=1913776309, LIKELY).
- `infiniteLoopLimit` caps loop iterations, with an off-by-one bug. `for` loops are faster than `while` loops (UGC).
- `xsGetPlayerUnitIds` takes an optional array to reuse, which avoids allocations; use it.
- **Community advice (LIKELY, anecdotal)**: lag comes from what triggers *do*, not how many exist. Big Area or "all units" effects and many simultaneously firing loops cause hitches. Chain triggers to activate one another instead of keeping thousands on standby (https://ugc.aoe2.rocks/scenarios/triggers/; AoE wiki https://ageofempires.fandom.com/wiki/Trigger; HeavenGames thread https://aok.heavengames.com/cgi-bin/forums/display.cgi?action=st&fn=4&tn=41141).
- **UNKNOWN**: there are no published benchmarks for area-scan cost or for how many XS unit queries per second are safe with large late-game armies.
- Suggested approach:
  - Track only carts and supply buildings, not armies.
  - Spread the work across ticks (round-robin a slice of the array per rule run).
  - Use intervals of 1–2 seconds, not `highFrequency`.
  - Only rename or caption objects when the value changes.

---

## 6. What disabling production does to queued units

- **UNKNOWN**: what Enable/Disable Object (disabled) does to units **already queued**. I found no source; a forum thread on detecting queue state is unresolved and reports "Object Has Action = Train" as unreliable (https://forums.ageofempires.com/t/object-has-action-train/287672, 2026).
- **VERIFIED (Sept 22, 2026, Update 185872)**: Stop Object, Freeze Object, and Task Object with the Stop action now **clear building production queues**. Per-building queue cancellation is therefore possible with Selected Units. The notes do not say whether resources are refunded (UNKNOWN).
- Suggested test matrix:
  1. Disable the object mid-queue: does the queue continue, cancel, or refund?
  2. Run Stop Object on one building: refund amount?
  3. Run Replace Object on a building that has a queue: is the queue lost or refunded?
  4. Change Train Location while queued.

---

## Key URLs
- UGC guide: https://ugc.aoe2.rocks/ (source: https://github.com/Divy1211/AoE2DE_UGC_Guide)
- Effects: https://ugc.aoe2.rocks/scenarios/triggers/effects/effects/
- Conditions: https://ugc.aoe2.rocks/scenarios/triggers/conditions/conditions/
- XS functions: https://ugc.aoe2.rocks/general/xs/functions/functions/
- XS constants: https://ugc.aoe2.rocks/general/xs/constants/constants/
- Resources: https://ugc.aoe2.rocks/general/resources/resources/
- Attributes: https://ugc.aoe2.rocks/general/attributes/attributes/
- XS tricks (train locations): https://ugc.aoe2.rocks/general/xs/tricks/
- Patch notes:
  - Update 185872 (Sept 22, 2026): https://www.ageofempires.com/news/age-of-empires-ii-definitive-edition-update-185872/
  - Update 153015 (Aug 12, 2025): https://www.ageofempires.com/news/age-of-empires-ii-definitive-edition-update-153015/
  - Update 128442 (Nov 14, 2024): https://www.ageofempires.com/news/age-of-empires-ii-definitive-edition-update-128442/
  - Update 42848 (XS introduced): https://www.ageofempires.com/news/aoe2de-update-42848/
  - Update 35584 (data mod lobby prompt): https://www.ageofempires.com/news/aoe2de-update-35584/
- Zetnus RMS guide: https://docs.google.com/document/d/1jnhZXoeL9mkRUJxcGlKnO98fIwFKStP_OBozpr0CHXo
- Forgotten Empires XS doc: https://www.forgottenempires.net/age-of-empires-ii-definitive-edition/xs-scripting-in-age-of-empires-ii-definitive-edition
