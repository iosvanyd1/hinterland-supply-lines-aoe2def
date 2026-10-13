# Hinterland Supply Lines: what XS, triggers and RMS can do in AoE2 DE

Research date: 2026-10-13.

**Main source.** The AoE2 DE UGC Guide at https://ugc.aoe2.rocks. I downloaded the full HTML pages and read them. I also cloned its source repo, https://github.com/Divy1211/AoE2DE_UGC_Guide. The newest commit is from 2026-10-10. The docs were updated for the "TVS DLC" on 2026-09-22 and for the "TLC DLC" on 2026-02-15, so they cover the current build.

**Confidence labels used below:**
- **VERIFIED**: I read it on a cited page (the guide, a forum thread or a docs page).
- **LIKELY**: it follows from verified docs, but I found no explicit statement or test.
- **UNKNOWN**: it has to be tested in game.

## Key reference URLs

| What | URL |
|---|---|
| XS function reference (all signatures below) | https://ugc.aoe2.rocks/general/xs/functions/functions/ |
| XS constants (attributes, resources, unit properties, effect types) | https://ugc.aoe2.rocks/general/xs/constants/constants/ |
| Trigger effects | https://ugc.aoe2.rocks/scenarios/triggers/effects/effects/ |
| Trigger conditions | https://ugc.aoe2.rocks/scenarios/triggers/conditions/conditions/ (source: https://github.com/Divy1211/AoE2DE_UGC_Guide/blob/main/docs/scenarios/triggers/conditions/conditions.md) |
| XS tricks (attack/armor encoding, auras, train locations) | https://ugc.aoe2.rocks/general/xs/tricks/ |
| XS for beginners (file location, RMS `#includeXS`, rules) | https://ugc.aoe2.rocks/general/xs/beginner/ |
| Known bugs | https://ugc.aoe2.rocks/general/xs/bugs/Important/ and https://ugc.aoe2.rocks/general/xs/bugs/Individual%20Tech%20Modifiers/ |
| Resource IDs | https://ugc.aoe2.rocks/general/resources/resources/ |
| Object attribute IDs | https://ugc.aoe2.rocks/general/attributes/attributes/ |

**When the per-unit API reached the docs** (from `git log -S` on the guide repo):
- `xsGetPlayerUnitIds` and `xsGetUnitAttribute` were first documented on 2025-07-20, in commit 9bd2f41 ("PUP and upcoming update").
- `cSetUnitAttribute`, `cAddUnitAttribute` and `cMulUnitAttribute` were first documented on 2026-02-15, in commit 4f37318 ("TLC DLC").
- `xsSetUnitProperty`, `xsGetUnitProperty`, `xsResearchLocalTechnology`, `xsTrainObject`, `xsTaskUnits` and `xsSetUnitOwner` were first documented on 2026-09-22, in commit 35580fb ("TVS DLC").

These dates are when the docs were written, not necessarily when each function shipped. They do mean the functions exist in the 2026 builds. I found no official ageofempires.com patch note that names these functions. The update 141935 page (April 2025) lists only campaign-JSON modding changes: https://www.ageofempires.com/news/age-of-empires-ii-definitive-edition-update-141935/

---

## TL;DR

1. **XS can now work on individual units.** VERIFIED. `xsGetPlayerUnitIds(player, objectOrClassId)` returns an int array of the map unit IDs. Per-unit getters and setters take one of those IDs: `xsGetUnitPosition`, `xsGetUnitAttribute`, `xsSetUnitHitpoints`, `xsGetUnitProperty` / `xsSetUnitProperty`, and others.
   - You do not need to generate triggers to loop over units.
2. **XS can change one unit's stats.** VERIFIED that the API exists. `xsEffectAmount(cSetUnitAttribute | cAddUnitAttribute | cMulUnitAttribute, unitId, attribute, value)` takes effect IDs 10, 11 and 12.
   - The guide says these are "the same as modify object attribute in the editor".
   - Plain `cSetAttribute`, `cAddAttribute` and `cMulAttribute` (IDs 0, 4, 5) change the whole unit type for a player.
   - UNKNOWN: whether attack and armor use the same `class*256+value` encoding in the per-unit variants. Test this.
3. **Trigger effects can also change single units.** VERIFIED. "Modify Object Attribute", "Change Object Attack/Armor/HP/Speed/Range" and similar effects take Area or Selected Units.
   - "Modify Attribute", "Modify Attribute By Variable" and "Modify Attribute For Class" work per type.
4. **The engine can buff units near a Town Center by itself.** VERIFIED as a documented technique. Give the TC an aura task through `xsModifyObjectTasks` (the guide's `xsAddAura` recipe). This may replace the hand-tracked pool of buffed units.
5. **There is no direct way to lock training or research at only one building.** The realistic options are:
   - make the building unselectable (`xsSetUnitProperty(id, cUnitSelectable, 0)`, VERIFIED to exist);
   - swap the building for a data-modded "dark" twin that has no buttons (Replace Object, or remove and create);
   - possibly local technologies (UNKNOWN whether they can strip train buttons).
6. **XS runs in RMS through `#includeXS file.xs`.** VERIFIED. According to the Racket aoe2-rms docs, the included XS file is transferred to players automatically.
   - Trigger variables (`xsTriggerVariable`) only work in scenarios.
   - Anything named `xsUnsync*`, plus `xsGetLocale` and localized strings, causes desyncs if it drives game logic.

---

## 1. Per-building supply countdown timers (drain 1 per second)

**What's possible: VERIFIED.**
- Keep parallel global arrays keyed by building: unit ID and remaining supply.
- Run a rule once per second.

**API** (functions page, sections 1 Rules and 3 Arrays):
```c
int  xsArrayCreateInt(int size, int defaultValue, string uniqueName)   // see guide §3.1 for exact params
void xsArraySetInt(int arrayId, int index, int value)
int  xsArrayGetInt(int arrayId, int index)
int  xsArrayResizeInt(int arrayId, int newSize)
int  xsArrayGetSize(int arrayId)
// rule syntax:
rule supplyTick active minInterval 1 maxInterval 1 group supply { ... }
void xsEnableRule(string ruleName); void xsDisableRule(string ruleName); void xsDisableSelf();
bool xsIsRuleEnabled(string ruleName); void xsSetRuleMinInterval(string ruleName, int interval);
void xsEnableRuleGroup(string g); void xsDisableRuleGroup(string g);
int  xsGetGameTime()   // seconds; xsGetTime() = game time - 1; xsGetWorldTime() = ms; xsGetTurn() = tick
bool xsDoesUnitExist(int unitId)   // prune destroyed buildings
```
- I verified the array create functions by name but did not copy their parameter list. Check §3.1–3.5 for the exact signature.

**Display:**
```c
bool xsDisplayTimer(int timerId, string msg, int time, int timerUnit, bool resetTimer, int playerId)
bool xsClearTimer(int timerId, int playerId)
bool xsSetUnitCaption(int unitId, string caption)
```
- `xsSetUnitCaption` puts per-building text over the building, for example "Supply 42". VERIFIED that the function exists. UNKNOWN how it looks in game.

**Limitations:**
- `minInterval` is in game seconds.
- `highFrequency` runs 60 times per real second and does not follow game speed. Avoid it for gameplay logic.
- Rules are quantized to the sim tick, so a 1-second rule can drift slightly. Use `xsGetGameTime()` deltas if you need exact timing. LIKELY.

**Sources:**
- https://ugc.aoe2.rocks/general/xs/beginner/ (Rules section)
- https://ugc.aoe2.rocks/general/xs/functions/functions/ (§1, §3, §11, §12, §9.43)

---

## 2. Detecting a "supply cart" arriving at a specific building

**XS option: VERIFIED API.**
```c
int    xsGetPlayerUnitIds(int playerId, int objectOrClassId, int arrayId /*optional reuse*/) // returns int array of unit IDs
vector xsGetUnitPosition(int unitId)
float  xsVectorGetX(vector v); float xsVectorGetY(vector v);
float  dist(vector a, vector b)          // §4.24 (verify param types)
int    xsGetUnitTargetUnitId(int unitId) // what the cart is targeting
vector xsGetUnitMoveTarget(int unitId)
int    xsGetGarrisonedInUnitId(int unitId); int xsGetGarrisonedUnitIds(int unitId) // if the cart garrisons into the building
float  xsGetUnitProperty(int unitId, int property, int typeOrPlayer) // cUnitTargetId=10007, cUnitActionId=10009, cUnitOrderId=10010
bool   xsRemoveUnit(int unitId)          // consume the cart
```
Pattern:
1. Every second, get all supply-cart IDs for the player.
2. For each cart, compute the distance to each tracked building, or check whether the cart is garrisoned in it.
3. If the distance is under a threshold, refill that building's timer and call `xsRemoveUnit(cart)`.

**Garrisoning may be the most robust trigger.** Give the cart a garrison task into the building class in the data mod. Then `xsGetGarrisonedInUnitId(cart) == buildingId` tells you exactly which building it reached. LIKELY: depends on your data mod.

**Trigger alternative** (scenario only, VERIFIED):
- The "Bring Object To Object" condition handles one specific placed unit.
- The "Objects In Area" condition counts units of an object or class in an area, with quantity, class, type and state filters.

**Limitations:**
- XS has no built-in "units in radius" function. You loop yourself, which is O(carts × buildings). That is fine at a 1 s interval.
- `dist()` exists in Maths §4.24. I did not record its exact parameters. Compute `sqrt(dx*dx+dy*dy)` if unsure.

**Sources:**
- https://ugc.aoe2.rocks/general/xs/functions/functions/ (§7.2, §9.7, §9.11–9.12, §9.32–9.33, §9.50)
- conditions page (Bring Object To Object, Objects In Area)

---

## 3. Units inside or outside the radius of any Town Center, and a pool of buffed units

**Option A: manual pool in XS. VERIFIED API.**
1. `tcs = xsGetPlayerUnitIds(p, 109)`. 109 is the TC object ID. You can also pass a class ID (9xx) for unit classes.
2. `units = xsGetPlayerUnitIds(p, classId)` for each military class, or loop over the classes you care about.
3. For each unit: if the minimum distance to any TC is under R and the unit is not in the pool, apply the buff and add it to the pool. If it is in the pool and now outside, remove the buff and drop it from the pool.
4. Keep the pool as an int array of unit IDs. Prune IDs where `xsDoesUnitExist(id)` is false.

**Option B: native aura on the TC. VERIFIED as a documented recipe; UNKNOWN for your exact stats.**
- The tricks page gives a full `xsAddAura(auraUnit, affectedUnitOrClass, player, attribute, value, range, auraEffectsBitField, targetDiplomacy, ...)` function.
- It sets `cCombatAbility` bits on the aura unit.
- It adds a task of type `cTaskTypeAura` with `xsResetTaskAmount`, `xsTaskAmount(cTaskAttr..., v)` and `xsModifyObjectTasks(auraUnit, player)`.
- Its example aura gives +5 attack to cavalry (class 912) within range 10.
- The engine then buffs and unbuffs units automatically as they move in and out. No pool and no per-unit stat writes.
- **Caveats from the guide:**
  - Adding an aura "freezes" the aura unit for further non-task modifications.
  - Re-adding an aura for the same attribute and target overwrites the old one.
  - Not every attribute is supported by auras.
- A good fit for "buff near any TC". You can also make the aura depend on the capital by adding it only to the capital's object type. The task is set per object type and player, not per unit, unless you use `xsModifyUnitTasks(unitId, taskIndex, edit)`.

**Per-unit task API** (VERIFIED, §8):
```c
void  xsResetTaskAmount(); void xsTaskAmount(int taskFieldId, float value); float xsGetTaskAmount(int taskFieldId)
bool  xsModifyObjectTasks(int objectId, int playerId, int taskId, bool edit)   // per type
bool  xsModifyUnitTasks(int unitId, int taskId, bool edit)                      // per individual unit
int   xsGetUnitTaskCount(int unitId); bool xsUnitTaskAmount(int unitId, int taskId)
// xsTask / xsRemoveTask are marked Deprecated.
```
- `xsModifyUnitTasks` could put an aura on one specific TC, the capital. UNKNOWN: I have not seen this tested.

**Sources:**
- https://ugc.aoe2.rocks/general/xs/tricks/ (§3 Adding auras)
- https://ugc.aoe2.rocks/general/xs/functions/functions/ (§7.2, §8)

---

## 4. Changing stats of one unit vs a whole unit type (critical)

### 4a. XS, whole type for one player. VERIFIED.
```c
void xsEffectAmount(int effectId, int objectOrTechnologyId, int attributeOrOperation, float value, int playerId, int trainLocationIndex)
// effectId: cSetAttribute=0, cAddAttribute=4, cMulAttribute=5, cModResource=1, cEnableObject=2, cUpgradeUnit=3,
//           cMulResource=6, cSpawnUnit=7, cModifyTech=8, cSetPlayerData=9; Gaia variants are negative.
// playerId omitted => ALL players except Gaia.
```
**Attack and armor value encoding** (tricks §1):
- `value = damageClass*256 + amount`. Negate the whole number for a negative amount.
- For `cMulAttribute`, use `damageClass*256 + 100*factor`, which caps at 2.55×. Example: `xsEffectAmount(cAddAttribute, 731, cAttack, cDamageClassPierce*256 + 5)`.
- **Encoding history is messy:**
  - Build 58259 (Jan 2022) briefly needed 65536 for `cSetAttribute`: https://forums.ageofempires.com/t/bug-with-modifying-attack-and-armor-with-xs-script-after-jan-31-patch/195140
  - Since update 66692 (Aug 2022), "Set" on attack and armor adds instead of setting: https://forums.ageofempires.com/t/modify-attribute-and-xseffectamount-do-not-work-with-set-option-for-attack-and-armor-classes/222145. Logged, no fix found.
  - **Use Add with negative values, never Set, for attack and armor.** Changing a damage class the unit does not already have does not work: https://forums.ageofempires.com/t/changing-attack-armor-of-a-unit-for-a-class-that-a-unit-does-not-have-by-default-does-not-work/131626. That thread title is from search results; I did not open it.

### 4b. XS, one unit instance. VERIFIED API; effect details partly UNKNOWN.
```c
xsEffectAmount(cSetUnitAttribute /*10*/, unitId, attribute, value);   // "same as modify object attribute in the editor"
xsEffectAmount(cAddUnitAttribute /*11*/, unitId, attribute, value);
xsEffectAmount(cMulUnitAttribute /*12*/, unitId, attribute, value);
// The guide's example uses a map unit ID: xsEffectAmount(cAddUnitAttribute, 0, cHitpoints, 40) "adds 40 to unit 0's HP".
float xsGetUnitAttribute(int unitId, int attribute, int damageClassOrEntryMod)  // read the instance's current value
float xsGetObjectAttribute(int playerId, int objectId, int attribute, int damageClass) // read the type's value
bool  xsSetUnitHitpoints(int unitId, float value); float xsGetUnitHitpoints(int unitId)
bool  xsSetUnitProperty(int unitId, int property, float value, int typeOrForce)
```
**Attribute IDs you will want** (constants §11):

| Constant | ID |
|---|---|
| cHitpoints | 0 |
| cLineOfSight | 1 |
| cMovementSpeed | 5 |
| cArmor | 8 |
| cAttack | 9 |
| cAttackReloadTime | 10 |
| cAccuracyPercent | 11 |
| cMaxRange | 12 |
| cWorkRate | 13 |
| cCarryCapacity | 14 |
| cBaseArmor | 15 |
| cShownAttack | 46 |
| cShownMeleeArmor | 48 |
| cShownPierceArmor | 49 |
| cRegenerationRate | 109 |
| cPopulation | 110 |
| cTrainLocation | 42 |
| cTrainButton | 43 |
| cTrainLocationsEntryMod | 158 |
| cTrainLocationsTotalNum | 159 |
| cCombatAbility | 63 |

- **UNKNOWN:**
  - whether `cAttack` and `cArmor` in the per-unit variants use the same `class*256` packing and have the same Set-adds bug;
  - whether "Shown" attack and armor update in the UI.
  - Test in the editor: add +2 melee to one militia and read it back with `xsGetUnitAttribute(id, cAttack, 4)`.
- `xsSetUnitProperty` covers only these properties:
  - cUnitHitpoints = 0
  - cUnitBuildpoints = 1
  - cUnitCharge = 2
  - cUnitCaptionStringId = 3
  - cUnitAttributeHeld = 4
  - cUnitGarrisonedInId = 5
  - cUnitCaptureFlag = 6
  - cUnitDeletable = 7
  - cUnitTargetable = 8
  - cUnitAttackable = 9
  - cUnitSelectable = 10
  - cUnitStance = 11
  - cUnitVisibility = 12
  - cUnitColorId = 13
  - cUnitLocked = 14
  - plus read-only properties from 10000 to 10010
- It does not cover attack or armor. Use `c*UnitAttribute` for stats.

### 4c. Trigger effects (scenario only). VERIFIED (effects page).

**Work on single units** (they take "Area" and/or "Selected Units"; Selected Units overrides the other filters; "Max Units Affected" also applies):
- Change Object Attack / Change Object Armor
  - Fields: Armour Attack Quantity (max 255), Armour Attack Class, Operation.
- Change Object HP, Change Object Speed, Change Object Range
- Modify Object Attribute, Modify Object Attribute By Variable (any attribute, with Operation, Quantity or Quantity Float)
- Heal Object, Damage Object, Freeze Object
- Disable/Enable Object Selection, Disable/Enable Unit Targeting or Attackable, Disable Object Deletion
- Replace Object, Change Ownership, Teleport Object, Stop Object, Task Object
- Train Unit, Initiate Research, Research Local Technology, Set Building Gather Point

**Work on a type or class** (Object plus Player only, no Area):
- Modify Attribute, Modify Attribute By Variable, Modify Attribute For Class, Enable/Disable Object, Enable/Disable Technology, Change Object Cost, Change Train Location, Add Train Location, Change Research Location

A forum answer from 2025-04-17 confirms the difference:
> "Change object speed" only applies to units currently on the map, and it always adds speed

It also says per-unit "change object" effects create "some kind of duplicated version of the unit", while Modify Attribute changes the base type for future spawns: https://forums.ageofempires.com/t/change-unit-speed-resets-when-respawing/273439

**Limitation:**
- Trigger "Selected Units" means units chosen in the editor, so they must be pre-placed.
- At runtime, triggers can only reach "units in this fixed Area". Areas are fixed rectangles, so a moving TC radius is not possible. Per-unit work at runtime belongs in XS (4b).

**Sources:**
- https://ugc.aoe2.rocks/general/xs/constants/constants/ (§8 Effect Amount Effect Type: cSetUnitAttribute, cAddUnitAttribute, cMulUnitAttribute; §11; §32)
- https://ugc.aoe2.rocks/general/xs/tricks/
- https://ugc.aoe2.rocks/scenarios/triggers/effects/effects/

---

## 5. Player resources, military population and continuous food drain

**VERIFIED.**
```c
float xsPlayerAttribute(int playerId, int resourceId)
void  xsSetPlayerAttribute(int playerId, int resourceId, float value)
xsEffectAmount(cModResource, cAttributeFood, cAttributeAdd, -amount, playerId)  // relative change
```
**Resource IDs** (constants §13, resources page):

| Constant | ID |
|---|---|
| cAttributeFood | 0 |
| cAttributePopulationCap | 4 |
| cAttributePopulation | 11 |
| cAttributeCivilianPopulation | 37 |
| cAttributeMilitaryPopulation | 40 ("Current military population") |
| cAttributeFoodTotal | 166 |

**Pattern:** once a second, `food = xsPlayerAttribute(p,0); xsSetPlayerAttribute(p, 0, max(0, food - upkeep*milPop))`.
- If food reaches 0, set an "unsupplied" flag that turns off buffs or applies debuffs.
- Fractional upkeep works because resources are floats.
- LIKELY: `cModResource` with a negative add is also fine.

**Limitation:** the UI shows integer food, but fractional drains still accumulate. LIKELY.

**Sources:**
- https://ugc.aoe2.rocks/general/xs/functions/functions/ (§7.8, §7.9)
- https://ugc.aoe2.rocks/general/resources/resources/ (#40)

---

## 6. Locking training and research at one specific building

**What does not work per building** (VERIFIED: these are per player and per type):
- `xsEffectAmount(cEnableObject, unit, cAttributeDisable, 0, p)`, plus the triggers Enable/Disable Object and Enable/Disable Technology
- `cModifyTech` with `cAttrSetState`
- Change Train Location and Change Research Location
- `cTrainLocation` and `cTrainLocationsEntryMod`
  - These live on the trained unit's data, with a list of train locations by building type, and apply per player. Tricks §4 shows how to insert or remove train-location entries. That is per type, not per building instance.
- `xsModifyUnitTasks` changes one unit's task list. Training and research are not tasks, so it cannot block them. LIKELY.

**Realistic options, best first:**

1. **Make the one building unselectable.** VERIFIED that the API exists; UNKNOWN in UX terms.
   - `xsSetUnitProperty(buildingId, cUnitSelectable /*10*/, 0)`. The trigger equivalent is "Disable Object Selection" with Selected Units or Area.
   - A player cannot queue units or techs in a building they cannot select.
   - Queues that already exist keep running. There is no XS function to cancel a building's queue.
   - You also lose garrison and ungarrison through the UI, gather points and inspection. Show the state with `xsSetUnitCaption`.
   - UNKNOWN: whether hotkeys (go to TC, select all TCs) or idle-building cycling bypass it. Test it.
   - AI players do not use the UI, but AIs can be ignored here.
2. **Swap in a "dark" twin building.** VERIFIED that the pieces exist.
   - Add a copy of the TC (and of each other building) to the data mod that has no train or research buttons, or has the units disabled.
   - To lock: `pos = xsGetUnitPosition(id); hp = xsGetUnitHitpoints(id); xsRemoveUnit(id); nid = xsCreateUnit(darkTcId, p, pos, false, false, false); xsSetUnitHitpoints(nid, hp)`.
   - In a scenario you can use the trigger Replace Object (Area, Max Units Affected = 1) instead, which keeps the unit in place.
   - Downsides:
     - The unit ID changes, so update your arrays.
     - Garrisoned units and queues are lost. Read `xsGetGarrisonedUnitIds` first and re-garrison with `xsSetUnitProperty(id, cUnitGarrisonedInId, newId, force)`. UNKNOWN whether that works.
     - Pop-space and housing side effects. The TC also counts for victory.
   - A cleaner swap may be the data attribute `cTransformUnit` (204), if your twin is a transformable pair. UNKNOWN.
   - No `xsReplaceUnit` function exists in the function list. VERIFIED absent.
3. **Turn the building into a foundation.** UNKNOWN, risky. `xsSetUnitBuildPoints(id, 0)` exists, VERIFIED. Unfinished buildings cannot train, but this was not tested and may destroy or reset the building.
4. **Local technologies.** UNKNOWN.
   - The current build has building-instance techs: `xsResearchLocalTechnology(int buildingId, int localTechId)`, `xsHasResearchedLocalTechnology(int buildingId, int localTechId)`, the trigger effect "Research Local Technology" (Selected Units or Area) and the condition "Local Tech Researched" (Unit, Area, Quantity).
   - If a local tech's effect can disable train or research buttons for that one building, this would be the official per-building lever.
   - The guide does not document what local-tech effects can change. Inspect a data file that ships local techs with AGE, or ask in the UGC Discord.
5. **Refund approach.** VERIFIED API; it works around the problem rather than locking.
   - Leave training enabled. Detect units that pop from a locked building (new IDs near it), delete them and refund their cost with `xsSetPlayerAttribute`.
   - Bad UX. Use only as a fallback.

**Sources:**
- https://ugc.aoe2.rocks/general/xs/functions/functions/ (§6.7–6.9, §9.1, §9.2, §9.17–9.19, §9.51)
- https://ugc.aoe2.rocks/general/xs/constants/constants/ (§32)
- https://ugc.aoe2.rocks/general/xs/tricks/ (§4)
- effects and conditions pages

---

## 7. Per-player capital state, the "make capital" button and cooldowns

**State:** keep a global int array of capital TC unit IDs, indexed by player 1–8. Store cooldown end times as `xsGetGameTime()` plus a duration. VERIFIED that these primitives exist.

**Detecting the click: three options.**

1. **Global tech in the data mod.** VERIFIED API.
   - Add a cheap, stackable "Make Capital" tech researched at the TC.
   - Poll `int xsGetTechState(int techId, int playerId)`. The states are:

| Constant | Value |
|---|---|
| cTechStateNotReady | 0 |
| cTechStateReady | 1 |
| cTechStateResearching | 2 |
| cTechStateDone | 3 |
| cTechStateQueued | 4 |
| cTechStateDisabled | -1 |
| cTechStateInvalid | -2 |

   - Re-enable afterwards with `xsEffectAmount(cModifyTech, techId, cAttrSetState, cAttributeEnable, p)`. Trigger alternatives: "Enable Technology Stacking" or Enable/Disable Technology.
   - **Problem: which TC?** A global tech does not tell you which building researched it.
     - One workaround: have the tech spawn a marker unit. A tech effect can spawn a unit at the researching building (effect type 7, `cSpawnUnit`; LIKELY). Then find the TC nearest the new marker and remove the marker.
     - Another: per unit, read `xsGetUnitProperty(tcId, cUnitActionId /*10009*/)` or `cUnitOrderId`. UNKNOWN whether this exposes "researching tech X".
2. **Dummy "Capital Charter" unit trained at the TC.** VERIFIED API; the technique is common practice but I found no single citation.
   - When a new charter unit appears (its ID is not in your set), the TC closest to it, or the TC from its gather point, becomes the capital.
   - Then `xsRemoveUnit(charter)`.
   - Use `xsGetObjectCount(p, charterId)` to detect it cheaply.
   - This identifies the building without ambiguity.
3. **Local technology "Make Capital".** UNKNOWN, but the most elegant.
   - `xsHasResearchedLocalTechnology(tcId, localTechId)` tells you exactly which TC.
   - Needs a data-modded local tech. Re-researchability is UNKNOWN.

**Cooldown:**
- Disable the tech or charter unit per player for N seconds: `xsEffectAmount(cEnableObject, charterId, cAttributeDisable, 0, p)`, re-enabled later by a rule.
- Or run a per-player rule that checks `xsGetGameTime() >= cooldownEnd[p]`.
- Show it with `xsDisplayTimer(timerId, "Capital move: <TIMER>", secs, cTimerUnitSeconds, true, p)`.

**Sources:**
- https://ugc.aoe2.rocks/general/xs/functions/functions/ (§6.3, §6.8, §7.1, §9.34, §12.10)
- https://ugc.aoe2.rocks/general/xs/constants/constants/ (§17 Tech State, §32)

---

## 8. XS in RMS vs scenario, and multiplayer sync

**Where files go:**
- `...\AoE2DE\resources\_common\xs\` (VERIFIED, beginner page).
- Paths may also be relative to the xs folder in the player profile.
- Never edit `default0.xs`; it is temporary.
- `Constants.xs` holds the built-in constants.

**Scenario:**
- Add a "Script Call" effect in a trigger. The scenario's XS file's `main()` runs automatically.
- Triggers can call XS functions through the effect "Script Call" (Message = function name or definition) and the condition "Script Call" (must return bool).
- XS can talk to triggers through `int xsTriggerVariable(int id)` and `void xsSetTriggerVariable(int id, int value)`. Both work in scenarios only.
- There is no XS function that fires an arbitrary trigger effect. VERIFIED absent from the list. XS acts through `xsEffectAmount` and the dedicated per-unit functions, or signals triggers through variables.

**RMS:**
- `#includeXS filename.xs` at the top of the .rms. `main()` runs at map generation and rules keep running all game. VERIFIED, beginner page.
- Racket aoe2-rms docs: "Unlike included rms files, included XS files DO transfer automatically to players and spectators". This is a third-party doc, so treat it as LIKELY. The data mod (dark TC twins, supply cart unit, techs) is a different matter: every player must have it installed. https://docs.racket-lang.org/aoe2-rms/including-files.html
- For runtime events, use the runtime name `"Random Map"` (vs `"Scenario Triggers"`) in `xsAddRuntimeEvent`.
- **Not available in RMS:** `xsTriggerVariable` and `xsSetTriggerVariable` ("only works in a custom scenario"), and all trigger effects and conditions.
- **Everything else in the function list has no RMS restriction noted.** That covers per-unit functions, `xsEffectAmount`, player attributes, UI timers and instructions, and `xsCreateUnit`. LIKELY; the guide notes no other restriction. Known RMS quirk: `xsGetMapSeed()` returns -1 in the editor.
- **Recommendation:** ship as a data mod (dark TC twins, supply cart unit, tech or charter unit) plus an RMS that does `#includeXS`. This needs no scenario and all logic lives in XS rules.

**Determinism and desyncs** (VERIFIED, function notes):
- XS runs in lockstep on every client.
- Use these only for UI, never for logic:
  - `xsUnsyncGetLocalPlayerId`, `xsUnsyncGetPlayerSelectedUnitIds`, `xsUnsyncGetViewPosition`, `xsUnsyncGetZoom`, `xsUnsyncIsUnitVisible`
  - `xsUnsyncGetTimerTimeRemaining` with a specific playerId
  - `xsGetLocale`
  - `xsGetString` or name getters with `localized=true`
- `xsGetRandomNumber` (and the LH and Max variants) are presumably synced. LIKELY.
- `xsGetTurn` ticks "may differ in games and replays".

**Known crash:** calling `xsResearchTechnology` twice for the same tech and player crashes the game. Guard it with `xsGetTechState`. https://ugc.aoe2.rocks/general/xs/bugs/Important/

**Known broken:** `cSetTechCost`, `cAddTechCost`, `cModTechTime` and their Gaia variants do nothing. Use `cModifyTech` with `cAttrSet*Cost` or `cAttrSetTime` instead. https://ugc.aoe2.rocks/general/xs/bugs/Individual%20Tech%20Modifiers/ and the tricks page §5.

**Language note:** a `mutable` function modifier (overloadable functions) was documented on 2026-09-22 (repo commit 1f0f7e8, programmer.md §5.1). There is no unary minus in XS; write `0 - x` or `-1 * x`.

---

## 9. Function inventory (current guide, 2026-10)

All functions are on https://ugc.aoe2.rocks/general/xs/functions/functions/ (section numbers in brackets). These are the signatures most relevant to this mod, copied from the guide.

**Rules [§1]**
- `xsEnableRule(string)`, `xsDisableRule(string)`, `xsDisableSelf()`, `bool xsIsRuleEnabled(string)`
- `xsSetRulePriority(string,int)`, `xsSetRuleMinInterval(string,int)`, `xsSetRuleMaxInterval(string,int)`, plus `*Self` variants
- `xsEnableRuleGroup(string)`, `xsDisableRuleGroup(string)`, `bool xsIsRuleGroupEnabled(string)`

**Vectors [§2]**
- `xsVectorGetX/Y/Z(vector)`, `xsVectorSetX/Y/Z`, `vector xsVectorSet(x,y,z)`, `xsVectorLength`, `xsVectorNormalize`

**Arrays [§3]**
- `xsArrayCreate{Int,Float,Bool,String,Vector}`, `xsArraySet*`, `xsArrayGet*`, `xsArrayResize*`, `int xsArrayGetSize(int)`

**Maths [§4]**
- abs, sqrt, pow, sin…atan2, floor, ceil, round, dist, bitAnd/Or/Xor/Lsh/Rsh/Not, bitCastToFloat/Int, xsCeilToInt

**Random [§5]**
- `xsGetRandomNumber()`, `xsGetRandomNumberLH(lo,hi)`, `xsGetRandomNumberMax(max)`

**Techs [§6]**
- `bool xsResearchTechnology(int techId, bool force, bool techAvailable, int playerId)`
- `int xsGetTechState(int techId, int playerId)`
- `int xsGetTechAttribute(int playerId, int techId, int techAttribute, int indexOrCostType)`
- `xsSetTechName(techId, playerId, string)`, `xsSetTechDescription(techId, playerId, string)`
- `bool xsInitiateResearch(int buildingId, int techId)`
- `bool xsHasResearchedLocalTechnology(int buildingId, int localTechId)`
- `bool xsResearchLocalTechnology(int buildingId, int localTechId)`

**Player [§7]**
- `void xsEffectAmount(int effectId, int objectOrTechnologyId, int attributeOrOperation, float value, int playerId, int trainLocationIndex)`
- `int xsGetPlayerUnitIds(int playerId, int objectOrClassId, int arrayId)`
- `float xsPlayerAttribute(int playerId, int resourceId)`, `void xsSetPlayerAttribute(int playerId, int resourceId, float value)`
- `bool xsGetPlayerInGame(int)`, `int xsGetPlayerCivilization(int)`, `int xsGetPlayerType(int)`
- `xsGetDiplomacy`, `xsSetDiplomacy`, `xsDeclareVictory(int, bool)`, `xsGetPlayerName`, `xsSetPlayerName`, `xsSetChatToPlayer`

**Tasks [§8]**
- `xsTaskAmount(int field, float v)`, `xsResetTaskAmount()`, `float xsGetTaskAmount(int)`
- `int xsGetObjectTaskCount(int objectId, int playerId)`, `int xsGetUnitTaskCount(int unitId)`
- `bool xsObjectTaskAmount(int objectId, int playerId, int taskId)`, `bool xsUnitTaskAmount(int unitId, int taskId)`
- `bool xsModifyObjectTasks(int objectId, int playerId, int taskId, bool edit)`, `bool xsModifyUnitTasks(int unitId, int taskId, bool edit)`
- `xsTask` and `xsRemoveTask` are deprecated.

**Units/Objects [§9]**
- Create and remove:
  - `int xsCreateUnit(int objectId, int playerId, vector location, bool foundation, bool playCreatedSound, bool checkCollision)`
  - `bool xsRemoveUnit(int)`, `bool xsDoesUnitExist(int)`
- Attributes:
  - `float xsGetObjectAttribute(int playerId, int objectId, int attribute, int damageClass)`
  - `float xsGetUnitAttribute(int unitId, int attribute, int damageClassOrEntryMod)`
- Owner and position:
  - `int xsGetUnitOwner(int)`, `bool xsSetUnitOwner(int unitId, int playerId, bool flash)`
  - `vector xsGetUnitPosition(int)`, `bool xsSetUnitPosition(int unitId, vector pos, bool checkCollision)`
- Targets and movement:
  - `int xsGetUnitTargetUnitId(int)`, `vector xsGetUnitMoveTarget(int)`, `int xsGetUnitGroupId(int)`, `vector xsGetGroupMoveTarget(int)`
- HP and build points:
  - `float xsGetUnitHitpoints(int)`, `bool xsSetUnitHitpoints(int, float)`
  - `float xsGetUnitBuildPoints(int)`, `bool xsSetUnitBuildPoints(int, float)`
- Identity:
  - `int xsGetUnitObjectId(int)`, `xsGetUnitCopyId`, `xsGetObjectCopyId(p, obj)`
  - `int xsGetUnitClass(int)`, `xsGetObjectClass(p, obj)`, `xsGetUnitType`, `xsGetObjectType`
- Resources held and charge:
  - `xsGetUnitAttributeTypesHeld`, `xsGetUnitAttributeHeld(unit, attr)`, `xsSetUnitAttributeHeld(unit, value, attr)`
  - `xsGetUnitCharge`, `xsSetUnitCharge`
- Garrison:
  - `int xsGetGarrisonedInUnitId(int)`, `int xsGetGarrisonedUnitIds(int)` (returns an int array)
- Counts and checks:
  - `int xsGetObjectCount(int playerId, int objectOrClassId)`, `int xsGetObjectCountTotal(int playerId, int objectOrClassId)`
  - `bool xsObjectHasAction(int playerId, int objectOrClassId, int actionId, int targetPlayerId, int targetType, int targetUnitLevel)`
  - `bool xsIsObjectValid(int objectId, int playerId)`, `bool xsIsObjectAvailable(int objectId, int playerId)`
- Building commands:
  - `bool xsTrainObject(int buildingId, int objectId, int count)`
  - `bool xsSetUnitGatherPoint(int buildingId, vector pos, int unitId)`, `vector xsGetUnitGatherPoint(int buildingId)`
- Labels:
  - `xsGetUnitCaption`, `bool xsSetUnitCaption(int, string)`, `xsSetUnitName`, `xsSetObjectDescription(p, obj, string)`
- Properties:
  - `float xsGetUnitProperty(int unitId, int property, int typeOrPlayer)`
  - `bool xsSetUnitProperty(int unitId, int property, float value, int typeOrForce)`
- Orders:
  - `bool xsFlashUnit(int unitId, int playerId, int sound)`, `bool xsStopUnit(int)`
  - `bool xsBuildUnit(int unitIds, int objectId, vector loc1, vector loc2, bool shift, bool formation)`
  - `bool xsTaskUnits(int unitIds, int actionType, vector location, int locationUnitId, bool isShiftQueue, bool isFormationCommand, bool shouldPlayUnloadSound, int patrolPoints)`

**Map [§10]**
- `xsGetMapName(bool)`, `xsGetMapWidth()`, `xsGetMapHeight()`, `xsGetMapSeed()`
- `xsTriggerVariable(int)`, `xsSetTriggerVariable(int,int)` (scenario only)
- `xsGetMapTileAttribute(x,y,attr)`

**Game info [§11]**
- `xsGetNumPlayers()`, `xsGetTime()`, `xsGetGameTime()`, `xsGetWorldTime()`, `xsGetTurn()`, `xsGetVictoryType()`…

**UI [§12]**
- `void xsChatData(string message, int value)`
- `bool xsSendChat(string msg, int playerId, bool silent)`
- `bool xsDisplayInstructions(string msg, int time, int sourcePlayer, int iconObjectId, int panelPosition, bool useTagColorForIcon, bool playNotificationSound, string soundFilename, int playerId)`
- `bool xsClearInstructions(int panelPosition, int playerId)`
- `bool xsDisplayTimer(int timerId, string msg, int time, int timerUnit, bool resetTimer, int playerId)`, `bool xsClearTimer(int timerId, int playerId)`
- `bool xsPlaySound(string eventOrSoundFileName, int playerId, vector position, float angle, int unitId, bool global)`
- `xsSetViewPosition`, `xsSetZoom`
- `xsUnsync*` functions (UI only)

**File IO [§13]**
- `xsCreateFile`, `xsOpenFile`, `xsWrite*`, `xsRead*`, …
- `.xsdat` files are per player in MP.

**AI [§14]**
- `xsGetGoal`, `xsSetGoal`, `xsGetStrategicNumber`, `xsSetStrategicNumber`, `xsGetAiSignal`, …

**Misc [§15]**
- `xsGetContextPlayer()`, `xsSetContextPlayer(int)`
  - Passing -2 as the player to `xsEffectAmount` uses the context player.
- `bool xsAddRuntimeEvent(string runtimeName, string functionName, int arg)`

**Strings [§16]**
- strLen, strSubstring, strSplit, strJoin, strReplace, strToInt, strToFloat, fstr, …

**Checked and not found** in the guide's complete function list (2026-10):
- No `xsGetObjectList`.
- No "units in area/radius" query.
- No `xsReplaceUnit`.
- No function to cancel a building's production queue.
- No generic "run trigger effect" function.
- No per-instance train or research enable.

Per-unit loops are therefore `xsGetPlayerUnitIds` plus a manual distance check.

---

## 10. Fallback: generating scenario triggers programmatically

If some per-unit behaviour only works through trigger effects (for example a verified Change Object Attack on one unit), use AoE2ScenarioParser by KSneijders: https://github.com/KSneijders/AoE2ScenarioParser
- It is a Python library that reads and writes `.aoe2scenario` files.
- It can add, edit and remove triggers, conditions, effects and units.
- It supports scenario versions 1.36 to 1.59. 1.59 is "Current Version (Since: Sept 2026)".
- Its page does not mention XS embedding.

The limitation stays: triggers need fixed Areas or pre-placed Selected Units. Prefer the XS per-unit API from section 4b, and keep triggers for scenario-only extras.

---

## Tests to run first in the editor (open questions)

1. Does `xsEffectAmount(cAddUnitAttribute, unitId, cAttack, 4*256 + 2)` change only that unit's melee attack? Read it back with `xsGetUnitAttribute(unitId, cAttack, 4)`, and check whether the shown attack updates.
2. Do Set and Add on per-unit attack and armor have the same bug as the per-type versions (Set acting as Add)?
3. Does `xsSetUnitProperty(tc, cUnitSelectable, 0)` block all ways of queueing, including hotkeys and "select all TCs"?
4. Does `xsModifyUnitTasks(capitalTcId, ...)` with an aura task affect only that TC?
5. Can a local tech's effect disable train or research buttons on one building, and can it be re-researched?
6. What does `xsGetUnitProperty(tc, cUnitActionId)` return while the TC is researching? Can it identify which TC clicked "make capital"?
