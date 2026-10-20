// Hinterland Supply Lines - entry point.
// The build flattens this into one file and appends it to the game's Effects.xs
// (assemble.py), so it runs on every map without a custom RMS.
//
// Status: slices 1-3 (supply window, carts, Palace network; design sections 3,
// 4, 11), Palace techs, attrition, computer players exempt (decisions
// 2026-10-20). Everything marked TODO(test) depends on an in-game test listed in
// docs/research/TECHNICAL_UNKNOWNS.md.

include "Hinterland\constants.xs";

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

// Tracked supply recipients: forward buildings and every TC (parallel arrays,
// gBuildingCount used entries).
int gBuildingIds = -1;
int gBuildingSupply = -1;    // remaining seconds
int gBuildingLocked = -1;    // 0/1
int gBuildingIsTc = -1;      // 0/1; an active TC is itself a supply source
int gBuildingType = -1;      // object ID it was registered as (live type for towers)
int gBuildingReady = -1;     // 0 = under construction (no drain, no lock), 1 = finished
int gBuildingCover = -1;     // last tick: cCoverNone / cCoverPalace / cCoverTc
int gBuildingTries = -1;     // seconds spent going dark (queue cancel, then garrison out)
int gBuildingLive = -1;      // while dark: the live type to swap back to; else -1
// Unit ID -> tracked slot + 1 (0 = not tracked), so hlRegisterBuildings checks
// each listed building in O(1) instead of scanning every tracked one.
int gBuildingSlotOf = -1;
int gBuildingCount = 0;

// What covers a building this tick. A TC-covered building belongs to that TC's
// outpost: when the TC is lost or runs dry, the building is out of supply at once.
// A Palace-covered building gets the grace countdown when the Palace falls.
extern const int cCoverNone = 0;
extern const int cCoverPalace = 1;
extern const int cCoverTc = 2;

// Tracked carts (parallel arrays). gCartLoaded: 1 = carrying supply.
// gCartRoute: building the cart last delivered to; it shuttles there from the Palace.
int gCartIds = -1;
int gCartLoaded = -1;
int gCartRoute = -1;
int gCartLastPos = -1;   // position one tick ago, to tell a stopped cart from a passing one
int gCartCount = 0;
int gCartSlotOf = -1;     // unit ID -> slot + 1, see hlFindSlot

// Palace (the capital) per player, index = player ID; -1 = none.
int gPalaceIds = -1;
// Last Palace build state XS set per player: -1 unknown, 0 disabled, 1 enabled.
int gPalaceBuildable = -1;

// Active TCs this tick (rebuilt each hlSupplyTick): they cover buildings around them.
int gSourcePos = -1;
int gSourceOwner = -1;
int gSourceCount = 0;
// The same sources grouped by owner: player p's are [gSourceStart[p], gSourceEnd[p])
// of gSourceByOwner, so hlCoverType skips other players' TCs.
int gSourceByOwner = -1;
int gSourceStart = -1;
int gSourceEnd = -1;

// Per tracked building: its current max supply (hlSupplyCapFor), refreshed
// every hlSupplyTick.
int gBuildingCap = -1;
// Per player: max supply in percent of the base caps (50 + Supply Depots +
// Military Warehouses), and whether an enemy has Siege & Starve Out.
int gCapPercent = -1;
int gEnemySiegeStarve = -1;
// Sabotage & Subterfuge: uses seen per player (its counter resource), uses by
// everyone (the price), and units set to 0 HP to remove if they do not die.
int gSabotageSeen = -1;
int gSabotageUses = 0;
int gPendingKills = -1;
int gPendingKillCount = 0;

// Per-player values refreshed once at the start of every rule (hlBeginTick),
// instead of engine calls per building or unit.
int gIsComputer = -1;       // bool
int gRulesOn = -1;          // bool: Castle Age or later
int gPalaceR = -1;          // float: Palace supply radius (Paved Roads included)
int gTcR = -1;              // float: TC supply radius
int gPalacePos = -1;        // vector: position of the Palace, if any

// Object IDs hlRegisterBuildings tracks, built once in hlEnsureInit.
int gRegisterTypes = -1;

// Map size factor in percent for supply windows, set once in hlEnsureInit.
int gMapScalePercent = 100;

// Scratch array reused by xsGetPlayerUnitIds.
int gScratch = -1;

// One-element array for xsTaskUnits.
int gTaskIds = -1;

// Cart lists per tick (empty and loaded types), kept apart from gScratch.
int gEmptyCarts = -1;
int gLoadedCarts = -1;

// Attrition (hlAttrition): the unit classes it hits, and its own unit lists.
int gAttritionClasses = -1;
int gAttritionUnits = -1;
int gAttritionCarts = -1;
int gAttritionCartPos = -1; // loaded-cart positions of the player being processed

// Caption last written per tracked building: -1 none yet, -2 "", else the
// seconds shown (0 = OUT OF SUPPLY). Only changes are written.
int gBuildingShown = -1;


// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Highest player ID: xsGetNumPlayers() counts real players without Gaia (T31
// passed; the old `p < xsGetNumPlayers()` loops skipped the last player).
// Capped so arrays indexed by player cannot overflow.
int hlLastPlayer() {
    int n = xsGetNumPlayers();
    if (n > cMaxPlayers - 1) {
        n = cMaxPlayers - 1;
    }
    return (n);
}

// Supply rules start at Castle Age (design section 3); Dark/Feudal play as normal.
// Read from the per-tick cache (hlRefreshPlayers).
bool hlSupplyRulesOn(int playerId = -1) {
    return (xsArrayGetBool(gRulesOn, playerId));
}

// Computer players are left alone by every rule (decision 2026-10-20): the AI
// knows neither the Palace nor carts, so supply would only cripple it.
// Refreshed every tick, not once, so a player taken over by the AI is released.
// TODO(test T35): xsGetPlayerType returns 3 for a skirmish AI.
bool hlIsComputer(int playerId = -1) {
    return (xsArrayGetBool(gIsComputer, playerId));
}

// `p` is at war with `q` (xsGetDiplomacy: p's stance towards q; UGC constants,
// cDiplomacyEnemy = 3). TODO(test T41): stances in a team game.
bool hlIsEnemy(int p = -1, int q = -1) {
    return (xsGetDiplomacy(p, q) == cDiplomacyEnemyId);
}

// A researched tech; false while the data mod is not built (ID -1).
bool hlTechDone(int playerId = -1, int techId = -1) {
    if (techId < 0) {
        return (false);
    }
    return (xsGetTechState(techId, playerId) == cTechStateDone);
}

// What covers `pos`: the owner's Palace radius first, then (for anything but a
// TC) the radius of one of the owner's active TCs. TCs do not chain: a TC is
// active only through the Palace or its own supply (design section 11).
// Radii include Paved Roads (palace_techs.py); all per-player values come from
// the per-tick cache (hlRefreshPlayers).
int hlCoverType(int playerId = -1, vector pos = vector(0, 0, 0), bool isTc = false) {
    if ((xsArrayGetInt(gPalaceIds, playerId) >= 0) &&
        (dist(xsArrayGetVector(gPalacePos, playerId), pos) <= xsArrayGetFloat(gPalaceR, playerId))) {
        return (cCoverPalace);
    }
    if (isTc) {
        return (cCoverNone);
    }
    float tcRadius = xsArrayGetFloat(gTcR, playerId);
    int end = xsArrayGetInt(gSourceEnd, playerId);
    for (i = xsArrayGetInt(gSourceStart, playerId); < end) {
        if (dist(xsArrayGetVector(gSourceByOwner, i), pos) <= tcRadius) {
            return (cCoverTc);
        }
    }
    return (cCoverNone);
}

// Construction finished: build points reached the type's build time.
// TODO(test T18): assumes cUnitBuildpoints counts up to cTrainTime.
bool hlIsBuilt(int index = -1) {
    int id = xsArrayGetInt(gBuildingIds, index);
    int owner = xsGetUnitOwner(id);
    float points = xsGetUnitProperty(id, cUnitBuildpoints, owner);
    float needed = xsGetObjectAttribute(owner, xsArrayGetInt(gBuildingType, index), cTrainTime, 0);
    return (points >= needed);
}

// Slot maps (gBuildingSlotOf, gCartSlotOf): unit ID -> tracked slot + 1,
// 0 = not tracked. O(1) lookups instead of scanning the tracked list.
int hlFindSlot(int map = -1, int unitId = -1) {
    if ((unitId < 0) || (unitId >= xsArrayGetSize(map))) {
        return (-1);
    }
    return (xsArrayGetInt(map, unitId) - 1);
}

// Record that unit `unitId` sits in tracked slot `slot` (-1 = no longer tracked).
// Grows the map by doubling; new entries are zeroed explicitly, since the fill
// value of xsArrayResizeInt is undocumented.
void hlSetSlot(int map = -1, int unitId = -1, int slot = -1) {
    if (unitId < 0) {
        return;
    }
    int size = xsArrayGetSize(map);
    if (unitId >= size) {
        if (slot < 0) {
            return;
        }
        int grown = size * 2;
        while (unitId >= grown) {
            grown = grown * 2;
        }
        xsArrayResizeInt(map, grown);
        for (k = size; < grown) {
            xsArraySetInt(map, k, 0);
        }
    }
    xsArraySetInt(map, unitId, slot + 1);
}

// A supply window scaled by map size: cart round trips grow with the distance
// between bases (decision 2026-10-15, baseline Medium).
int hlMapScaled(int seconds = 0) {
    return (seconds * gMapScalePercent / 100);
}

// Max banked supply of tracked building `index` owned by `owner`, scaled by map
// size: Castles and Kreposts hold 2x the normal window, Donjons and TCs 1.5x
// (decisions 2026-10-15). Goes by the registered type, which a dark twin keeps.
// Decision 2026-10-20: every cap starts at 50% and Supply Depots / Military
// Warehouses add 25 points each (gCapPercent, hlRefreshPlayers).
int hlSupplyCapFor(int index = -1, int owner = -1) {
    int objectId = xsArrayGetInt(gBuildingType, index);
    int cap = hlMapScaled(cSupplyCapSeconds) * xsArrayGetInt(gCapPercent, owner) / 100;
    if ((objectId == cCastleId) || (objectId == cKrepostId)) {
        return (cap * cFortressSupplyCapPercent / 100);
    }
    if (objectId == cDonjonId) {
        return (cap * cDonjonSupplyCapPercent / 100);
    }
    if (xsArrayGetInt(gBuildingIsTc, index) == 1) {
        // A dry TC takes its whole outpost dark at once (cCoverTc), so its
        // bank is the town's siege clock (decision 2026-10-15).
        return (cap * cTownCenterSupplyCapPercent / 100);
    }
    return (cap);
}

// The cap hlSupplyTick last computed for building `index` (gBuildingCap), so
// scans read an array instead of asking the engine for each building's owner.
int hlSupplyCap(int index = -1) {
    return (xsArrayGetInt(gBuildingCap, index));
}

int hlFindBuilding(int unitId = -1) {
    return (hlFindSlot(gBuildingSlotOf, unitId));
}

int hlFindCart(int unitId = -1) {
    return (hlFindSlot(gCartSlotOf, unitId));
}

// Drop carts that no longer exist (killed, deleted), so their slots are reused.
// Before 2026-10-15 dead carts kept their slot forever and, after
// cMaxTrackedCarts carts, new ones were never tracked (never loaded).
void hlSweepCarts() {
    int i = 0;
    while (i < gCartCount) {
        int id = xsArrayGetInt(gCartIds, i);
        if (xsDoesUnitExist(id)) {
            i++;
            continue;
        }
        int last = gCartCount - 1;
        hlSetSlot(gCartSlotOf, id, -1);
        if (last != i) {
            hlSetSlot(gCartSlotOf, xsArrayGetInt(gCartIds, last), i);
        }
        xsArraySetInt(gCartIds, i, xsArrayGetInt(gCartIds, last));
        xsArraySetInt(gCartLoaded, i, xsArrayGetInt(gCartLoaded, last));
        xsArraySetInt(gCartRoute, i, xsArrayGetInt(gCartRoute, last));
        xsArraySetVector(gCartLastPos, i, xsArrayGetVector(gCartLastPos, last));
        gCartCount--;
    }
}

bool hlIn4(int x = -1, int a = -1, int b = -1, int c = -1, int d = -1) {
    return ((x == a) || (x == b) || (x == c) || (x == d));
}

// The Castle (or Imperial) variant of a building that age-ups upgrade in place
// (effect type 3, any variant in, see constants.xs); -1 if it has no ages.
int hlAgeVariant(int objectId = -1, bool imperial = false) {
    int castle = -1;
    int imp = -1;
    if (hlIn4(objectId, cTownCenterId, cTownCenterFeudalId, cTownCenterCastleId, cTownCenterImperialId)) {
        castle = cTownCenterCastleId;
        imp = cTownCenterImperialId;
    } else if (hlIn4(objectId, cMillId, cMillFeudalId, cMillCastleId, cMillImperialId)) {
        castle = cMillCastleId;
        imp = cMillImperialId;
    } else if (hlIn4(objectId, cLumberCampId, cLumberCampFeudalId, cLumberCampCastleId, cLumberCampImperialId)) {
        castle = cLumberCampCastleId;
        imp = cLumberCampImperialId;
    } else if (hlIn4(objectId, cMiningCampId, cMiningCampFeudalId, cMiningCampCastleId, cMiningCampImperialId)) {
        castle = cMiningCampCastleId;
        imp = cMiningCampImperialId;
    } else if (hlIn4(objectId, cDockId, cDockFeudalId, cDockCastleId, cDockImperialId)) {
        castle = cDockCastleId;
        imp = cDockImperialId;
    } else if (hlIn4(objectId, cShipyardId, cShipyardId, cShipyardCastleId, cShipyardImperialId)) {
        castle = cShipyardCastleId;
        imp = cShipyardImperialId;
    } else if (hlIn4(objectId, cPortId, cPortFeudalId, cPortCastleId, cPortImperialId)) {
        castle = cPortCastleId;
        imp = cPortImperialId;
    } else if (hlIn4(objectId, cFolwarkId, cFolwarkFeudalId, cFolwarkCastleId, cFolwarkCastleId)) {
        castle = cFolwarkCastleId;
        imp = cFolwarkCastleId;
    } else if (hlIn4(objectId, cSettlementId, cSettlementFeudalId, cSettlementCastleId, cSettlementCastleId)) {
        castle = cSettlementCastleId;
        imp = cSettlementCastleId;
    }
    if (imperial) {
        return (imp);
    }
    return (castle);
}

// The root type of a building that upgrades in place: what the player's train
// locations, research locations and villagers' drop-site lists name. Playtest
// 2026-10-15 (T25, T26): a building created as a variant ID (Mill 130, TC 141)
// had no buttons and took no drop-offs, so dark buildings swap back to the root,
// which the engine gives the player's current upgrade (T29 passed).
// -1 for buildings that do not upgrade in place.
int hlRootType(int objectId = -1) {
    if (hlIn4(objectId, cTownCenterId, cTownCenterFeudalId, cTownCenterCastleId, cTownCenterImperialId) ||
        hlIn4(objectId, cEconomicTownCenterId, cDefensiveTownCenterId, cMilitaryTownCenterId, cTownCenterId)) {
        return (cTownCenterId);
    }
    if (hlIn4(objectId, cMillId, cMillFeudalId, cMillCastleId, cMillImperialId) ||
        hlIn4(objectId, cFolwarkId, cFolwarkFeudalId, cFolwarkCastleId, cMillId)) {
        return (cMillId);
    }
    if (hlIn4(objectId, cDockId, cDockFeudalId, cDockCastleId, cDockImperialId) || (objectId == cHarborId)) {
        return (cDockId);
    }
    if (hlIn4(objectId, cLumberCampId, cLumberCampFeudalId, cLumberCampCastleId, cLumberCampImperialId)) {
        return (cLumberCampId);
    }
    if (hlIn4(objectId, cMiningCampId, cMiningCampFeudalId, cMiningCampCastleId, cMiningCampImperialId)) {
        return (cMiningCampId);
    }
    if (hlIn4(objectId, cShipyardId, cShipyardCastleId, cShipyardImperialId, cShipyardId)) {
        return (cShipyardId);
    }
    if (hlIn4(objectId, cPortId, cPortFeudalId, cPortCastleId, cPortImperialId)) {
        return (cPortId);
    }
    if (hlIn4(objectId, cSettlementId, cSettlementFeudalId, cSettlementCastleId, cSettlementId)) {
        return (cSettlementId);
    }
    if (hlIn4(objectId, cMonasteryId, cMonasteryFeudalId, cMonasteryCastleId, cMonasteryImperialId) ||
        (objectId == cFortifiedChurchId)) {
        return (cMonasteryId);
    }
    if ((objectId == cOutpostId) || (objectId == cFortifiedOutpostId)) {
        return (cOutpostId);
    }
    return (-1);
}

// The civ variant a root type has for this player, or -1. Playtest 2026-10-15:
// a dark Folwark looked like a Mill, because the Folwark keeps Mill 68's
// identity and XS picked the Mill's dark twin. TODO(test T34).
int hlCivVariant(int playerId = -1, int objectId = -1) {
    if (hlIn4(objectId, cMillId, cMillFeudalId, cMillCastleId, cMillImperialId) &&
        hlTechDone(playerId, cFolwarkTech)) {
        return (cFolwarkCastleId);
    }
    if (hlIn4(objectId, cDockId, cDockFeudalId, cDockCastleId, cDockImperialId) &&
        hlTechDone(playerId, cThalassocracyTech)) {
        return (cHarborId);
    }
    if (hlIn4(objectId, cMonasteryId, cMonasteryFeudalId, cMonasteryCastleId, cMonasteryImperialId) &&
        (hlTechDone(playerId, cFortifiedChurchGeorgiansTech) || hlTechDone(playerId, cFortifiedChurchArmeniansTech))) {
        return (cFortifiedChurchId);
    }
    if ((objectId == cOutpostId) && hlTechDone(playerId, cFortifiedOutpostTech)) {
        return (cFortifiedOutpostId);
    }
    if (hlIn4(objectId, cTownCenterId, cTownCenterFeudalId, cTownCenterCastleId, cTownCenterImperialId)) {
        // TODO(test T34): two TCs with different Satrapies; the engine applies
        // each upgrade player-wide, so this picks the first one researched.
        if (hlTechDone(playerId, cEconomicSatrapyTech)) {
            return (cEconomicTownCenterId);
        }
        if (hlTechDone(playerId, cMilitarySatrapyTech)) {
            return (cMilitaryTownCenterId);
        }
        if (hlTechDone(playerId, cDefensiveSatrapyTech)) {
            return (cDefensiveTownCenterId);
        }
    }
    return (-1);
}

// What a building that last read as `objectId` is today, after in-place
// upgrades a dark twin does not get: Guard Tower / Keep for towers, the age for
// TCs and drop sites. Supply rules start in Castle Age, so never below Castle.
int hlUpgradedType(int playerId = -1, int objectId = -1) {
    int civ = hlCivVariant(playerId, objectId);
    if (civ >= 0) {
        return (civ);
    }
    if ((objectId == cWatchTowerId) || (objectId == cGuardTowerId)) {
        if (xsGetTechState(cKeepTech, playerId) == cTechStateDone) {
            return (cKeepId);
        }
        if (xsGetTechState(cGuardTowerTech, playerId) == cTechStateDone) {
            return (cGuardTowerId);
        }
    }
    bool imperial = (xsPlayerAttribute(playerId, cAttributeCurrentAge) >= cAgeImperial);
    int aged = hlAgeVariant(objectId, imperial);
    if (aged >= 0) {
        return (aged);
    }
    return (objectId);
}

// The type a dark building swaps back to: the root for buildings that upgrade
// in place (hlRootType), else the tower upgrade from the techs (T23 passed).
int hlRestoreType(int playerId = -1, int liveId = -1) {
    int root = hlRootType(liveId);
    if (root >= 0) {
        return (root);
    }
    return (hlUpgradedType(playerId, liveId));
}

// The data-mod twin that cannot attack or take drop-offs (dark_buildings.py);
// -1 for buildings that never go dark (Castles, production buildings) and
// before the dat is built.
int hlDarkType(int liveId = -1) {
    if (liveId == cWatchTowerId) { return (cDarkWatchTowerId); }
    if (liveId == cGuardTowerId) { return (cDarkGuardTowerId); }
    if (liveId == cKeepId) { return (cDarkKeepId); }
    if (liveId == cBombardTowerId) { return (cDarkBombardTowerId); }
    if (liveId == cDonjonId) { return (cDarkDonjonId); }
    if (liveId == cTownCenterCastleId) { return (cDarkTownCenterCastleId); }
    if (liveId == cTownCenterImperialId) { return (cDarkTownCenterImperialId); }
    if (liveId == cEconomicTownCenterId) { return (cDarkEconomicTownCenterId); }
    if (liveId == cDefensiveTownCenterId) { return (cDarkDefensiveTownCenterId); }
    if (liveId == cMilitaryTownCenterId) { return (cDarkMilitaryTownCenterId); }
    if (liveId == cKrepostId) { return (cDarkKrepostId); }
    if (liveId == cCastleId) { return (cDarkCastleId); }
    if (liveId == cHarborId) { return (cDarkHarborId); }
    if (liveId == cFortifiedChurchId) { return (cDarkFortifiedChurchId); }
    if (liveId == cFortifiedOutpostId) { return (cDarkFortifiedOutpostId); }
    if (liveId == cFortifiedOutpost2Id) { return (cDarkFortifiedOutpost2Id); }
    if (liveId == cDockCastleId) { return (cDarkDockCastleId); }
    if (liveId == cDockImperialId) { return (cDarkDockImperialId); }
    if (liveId == cMillCastleId) { return (cDarkMillCastleId); }
    if (liveId == cMillImperialId) { return (cDarkMillImperialId); }
    if (liveId == cLumberCampCastleId) { return (cDarkLumberCampCastleId); }
    if (liveId == cLumberCampImperialId) { return (cDarkLumberCampImperialId); }
    if (liveId == cMiningCampCastleId) { return (cDarkMiningCampCastleId); }
    if (liveId == cMiningCampImperialId) { return (cDarkMiningCampImperialId); }
    if (liveId == cShipyardCastleId) { return (cDarkShipyardCastleId); }
    if (liveId == cShipyardImperialId) { return (cDarkShipyardImperialId); }
    if (liveId == cPortCastleId) { return (cDarkPortCastleId); }
    if (liveId == cPortImperialId) { return (cDarkPortImperialId); }
    if (liveId == cFolwarkCastleId) { return (cDarkFolwarkId); }
    if (liveId == cSettlementCastleId) { return (cDarkSettlementId); }
    if (liveId == cMuleCartId) { return (cDarkMuleCartId); }
    return (-1);
}

// The live type of tracked building `index` right now, if it has a dark twin,
// else -1. Its current object ID first: Dock -> Harbor, Monastery -> Fortified
// Church and TC -> Economic/Defensive/Military TC change it in place.
// TODO(test T25): does xsGetUnitObjectId return the upgraded type? If not, the
// registered type plus hlUpgradedType still covers towers (T23) and age TCs.
// Castles and Kreposts keep firing out of supply until an enemy of their owner
// has Siege & Starve Out (decision 2026-10-20; Kreposts went dark always before).
int hlDarkableType(int index = -1) {
    int id = xsArrayGetInt(gBuildingIds, index);
    int owner = xsGetUnitOwner(id);
    int registered = xsArrayGetInt(gBuildingType, index);
    if (((registered == cCastleId) || (registered == cKrepostId)) &&
        (xsArrayGetBool(gEnemySiegeStarve, owner) == false)) {
        return (-1);
    }
    int objectId = hlUpgradedType(owner, registered);
    if (hlDarkType(objectId) >= 0) {
        return (objectId);
    }
    objectId = xsGetUnitObjectId(id);
    if (hlDarkType(objectId) >= 0) {
        return (objectId);
    }
    return (-1);
}

// Cancel ONE building's queue with refund: xsTaskUnits(Stop) + xsStopUnit
// (U14, T8 passed 2026-10-14; which of the two calls does it is untested).
void hlCancelQueue(int id = -1) {
    xsArraySetInt(gTaskIds, 0, id);
    xsTaskUnits(gTaskIds, cActionTypeStop, vector(-1, -1, -1), -1, false, false, false, -1);
    xsStopUnit(id);
}

// Push every garrisoned unit out of building `id` (T23 passed for towers).
void hlEjectGarrison(int id = -1) {
    if (xsArrayGetSize(xsGetGarrisonedUnitIds(id)) > 0) {
        xsArraySetInt(gTaskIds, 0, id);
        xsTaskUnits(gTaskIds, cActionTypeUngarrison, xsGetUnitPosition(id), -1, false, false, false, -1);
    }
}

// Swap tracked building `index` in place for `objectId`, keeping HP; the
// tracked slot and cart routes follow the new unit ID. Like the cart swap
// (T17), the building leaves the player's selection (T23 passed for towers).
void hlSwapBuilding(int index = -1, int objectId = -1) {
    int id = xsArrayGetInt(gBuildingIds, index);
    int owner = xsGetUnitOwner(id);
    vector pos = xsGetUnitPosition(id);
    // Raw HP carries over. A dark twin with a lower max HP clamps it, so a
    // building can come back damaged: accepted as an out-of-supply cost
    // (decision 2026-10-15).
    float hp = xsGetUnitHitpoints(id);
    xsRemoveUnit(id);
    int nid = xsCreateUnit(objectId, owner, pos, false, false, false);
    xsSetUnitHitpoints(nid, hp);
    xsArraySetInt(gBuildingIds, index, nid);
    xsArraySetInt(gBuildingShown, index, -1);   // the new unit has no caption yet
    hlSetSlot(gBuildingSlotOf, id, -1);
    hlSetSlot(gBuildingSlotOf, nid, index);
    for (c = 0; < gCartCount) {
        if (xsArrayGetInt(gCartRoute, c) == id) {
            xsArraySetInt(gCartRoute, c, nid);
        }
    }
}

// Lock or unlock training and research at ONE building (TCs included).
// Unselectable = no new queue entries (U6, T7 passed); locking also cancels the
// queue (refunded). Shooting buildings other than Castles instead go dark: they
// turn into a twin that cannot shoot, train or research.
void hlSetBuildingLocked(int index = -1, bool locked = false) {
    int id = xsArrayGetInt(gBuildingIds, index);
    int owner = xsGetUnitOwner(id);
    if (locked) {
        int live = hlDarkableType(index);
        if (live >= 0) {
            // First tick: cancel the queue, so the refund lands before the
            // building is removed, and empty it (T23 passed; the dark twin
            // holds no garrison). Ungarrison is retried each second, then it
            // goes dark anyway.
            int tries = xsArrayGetInt(gBuildingTries, index);
            int garrison = xsGetGarrisonedUnitIds(id);
            bool full = (xsArrayGetSize(garrison) > 0);
            if ((tries == 0) || (full && (tries < cDarkUngarrisonTicks))) {
                hlCancelQueue(id);
                if (full) {
                    xsArraySetInt(gTaskIds, 0, id);
                    xsTaskUnits(gTaskIds, cActionTypeUngarrison, xsGetUnitPosition(id), -1, false, false, false, -1);
                }
                xsArraySetInt(gBuildingTries, index, tries + 1);
                return;
            }
            xsArraySetInt(gBuildingTries, index, 0);
            hlSwapBuilding(index, hlDarkType(live));
            xsArraySetInt(gBuildingLive, index, live);
            id = xsArrayGetInt(gBuildingIds, index);
        } else {
            hlCancelQueue(id);
            int registered = xsArrayGetInt(gBuildingType, index);
            if ((registered == cCastleId) || (registered == cKrepostId)) {
                hlEjectGarrison(id);    // a dry Castle holds no garrison (playtest 2026-10-20)
            }
        }
        xsSetUnitProperty(id, cUnitSelectable, 0);
        xsArraySetInt(gBuildingLocked, index, 1);
    } else {
        int wasLive = xsArrayGetInt(gBuildingLive, index);
        if (wasLive >= 0) {
            hlSwapBuilding(index, hlRestoreType(owner, wasLive));
            xsArraySetInt(gBuildingLive, index, -1);
            id = xsArrayGetInt(gBuildingIds, index);
        }
        xsSetUnitProperty(id, cUnitSelectable, 1);
        xsArraySetInt(gBuildingLocked, index, 0);
    }
}

// Swap one cart between its empty (Ox Cart) and loaded (Ox Wagon) unit types,
// in place, keeping HP; the tracked slot follows the new unit ID, so the route
// survives. Returns the new unit ID. Costs: the cart leaves the player's
// selection and control groups. TODO(test T17): does xsRemoveUnit count as a
// loss or play a death sound?
int hlSwapCart(int ci = -1, int cart = -1, int playerId = -1, bool loaded = false) {
    int objectId = cSupplyCartId;
    if (loaded) {
        objectId = cLoadedSupplyCartId;
    }
    vector pos = xsGetUnitPosition(cart);
    float hp = xsGetUnitHitpoints(cart);
    xsRemoveUnit(cart);
    int nid = xsCreateUnit(objectId, playerId, pos, false, false, false);
    xsSetUnitHitpoints(nid, hp);
    xsArraySetInt(gCartIds, ci, nid);
    hlSetSlot(gCartSlotOf, cart, -1);
    hlSetSlot(gCartSlotOf, nid, ci);
    if (loaded) {
        xsArraySetInt(gCartLoaded, ci, 1);
    } else {
        xsArraySetInt(gCartLoaded, ci, 0);
    }
    return (nid);
}

// Order one cart to walk to a unit (the Palace or its route building).
void hlMoveCart(int cart = -1, int target = -1) {
    xsArraySetInt(gTaskIds, 0, cart);
    xsTaskUnits(gTaskIds, cActionTypeMove, xsGetUnitPosition(target), -1, false, false, false, -1);
}

// Covered buildings show no caption. Writes only when the text changes
// (gBuildingShown), instead of every building every second.
void hlUpdateCaption(int index = -1, bool covered = false) {
    int s = xsArrayGetInt(gBuildingSupply, index);
    int key = -2;
    if (covered == false) {
        key = s;
        if (key < 0) {
            key = 0;
        }
    }
    if (xsArrayGetInt(gBuildingShown, index) == key) {
        return;
    }
    xsArraySetInt(gBuildingShown, index, key);
    string text = "Supply " + s + "s";
    if (covered) {
        text = "";
    } else if (s <= 0) {
        text = "OUT OF SUPPLY";
    }
    xsSetUnitCaption(xsArrayGetInt(gBuildingIds, index), text);
}

// Active TCs this tick: finished, and inside their Palace radius or with supply
// left. Before Castle Age every finished TC is active. Also groups them by
// owner (gSourceByOwner), which also gives each player's supplied-TC count.
void hlRebuildSources() {
    gSourceCount = 0;
    for (i = 0; < gBuildingCount) {
        if (xsArrayGetInt(gBuildingIsTc, i) == 0) {
            continue;
        }
        if (xsArrayGetInt(gBuildingSupply, i) <= 0) {
            continue;   // dry: covers nothing, and is outside its owner's control
        }
        if (xsArrayGetInt(gBuildingReady, i) == 0) {
            continue;   // an unfinished TC covers nothing
        }
        int id = xsArrayGetInt(gBuildingIds, i);
        if (xsDoesUnitExist(id) == false) {
            continue;
        }
        xsArraySetVector(gSourcePos, gSourceCount, xsGetUnitPosition(id));
        xsArraySetInt(gSourceOwner, gSourceCount, xsGetUnitOwner(id));
        gSourceCount++;
    }
    int k = 0;
    for (p = 0; < cMaxPlayers) {
        xsArraySetInt(gSourceStart, p, k);
        for (i = 0; < gSourceCount) {
            if (xsArrayGetInt(gSourceOwner, i) == p) {
                xsArraySetVector(gSourceByOwner, k, xsArrayGetVector(gSourcePos, i));
                k++;
            }
        }
        xsArraySetInt(gSourceEnd, p, k);
    }
}

// ---------------------------------------------------------------------------
// One-time setup
// ---------------------------------------------------------------------------

// No main(): the build appends this XS to the game's Effects.xs, which the game
// includes in every game, so a main() would clash with a map's or scenario's.
// Every rule calls hlEnsureInit() first.
bool gInitDone = false;

void hlEnsureInit() {
    if (gInitDone) {
        return;
    }
    gInitDone = true;
    // xsGetMapWidth() is in tiles (T33 passed).
    gMapScalePercent = xsGetMapWidth() * 100 / cMapScaleBaseTiles;
    if (gMapScalePercent < cMapScaleMinPercent) {
        gMapScalePercent = cMapScaleMinPercent;
    }
    if (gMapScalePercent > cMapScaleMaxPercent) {
        gMapScalePercent = cMapScaleMaxPercent;
    }
    gBuildingIds = xsArrayCreateInt(cMaxTrackedBuildings, -1, "hlBuildingIds");
    gBuildingSupply = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingSupply");
    gBuildingLocked = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingLocked");
    gBuildingIsTc = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingIsTc");
    gBuildingType = xsArrayCreateInt(cMaxTrackedBuildings, -1, "hlBuildingType");
    gBuildingReady = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingReady");
    gBuildingCover = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingCover");
    gBuildingTries = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingTries");
    gBuildingLive = xsArrayCreateInt(cMaxTrackedBuildings, -1, "hlBuildingLive");
    gBuildingSlotOf = xsArrayCreateInt(4096, 0, "hlBuildingSlotOf");
    gCartSlotOf = xsArrayCreateInt(4096, 0, "hlCartSlotOf");
    // Specific types before the ones they upgrade from, so a building registers
    // as its own type (build time): Keep/Guard before Watch Tower, Harbor before
    // Dock, Fortified Church before Monastery, the TC choices before TC 109.
    gRegisterTypes = xsArrayCreateInt(33, -1, "hlRegisterTypes");
    xsArraySetInt(gRegisterTypes, 0, cBarracksId);
    xsArraySetInt(gRegisterTypes, 1, cArcheryRangeId);
    xsArraySetInt(gRegisterTypes, 2, cStableId);
    xsArraySetInt(gRegisterTypes, 3, cSiegeWorkshopId);
    xsArraySetInt(gRegisterTypes, 4, cCastleId);
    xsArraySetInt(gRegisterTypes, 5, cFortifiedChurchId);
    xsArraySetInt(gRegisterTypes, 6, cMonasteryId);
    xsArraySetInt(gRegisterTypes, 7, cHarborId);
    xsArraySetInt(gRegisterTypes, 8, cDockId);
    xsArraySetInt(gRegisterTypes, 9, cMarketId);
    xsArraySetInt(gRegisterTypes, 10, cBlacksmithId);
    xsArraySetInt(gRegisterTypes, 11, cUniversityId);
    xsArraySetInt(gRegisterTypes, 12, cEconomicTownCenterId);
    xsArraySetInt(gRegisterTypes, 13, cDefensiveTownCenterId);
    xsArraySetInt(gRegisterTypes, 14, cMilitaryTownCenterId);
    xsArraySetInt(gRegisterTypes, 15, cTownCenterId);
    xsArraySetInt(gRegisterTypes, 16, cKeepId);
    xsArraySetInt(gRegisterTypes, 17, cGuardTowerId);
    xsArraySetInt(gRegisterTypes, 18, cWatchTowerId);
    xsArraySetInt(gRegisterTypes, 19, cBombardTowerId);
    xsArraySetInt(gRegisterTypes, 20, cDonjonId);
    xsArraySetInt(gRegisterTypes, 21, cKrepostId);
    xsArraySetInt(gRegisterTypes, 22, cFortifiedOutpostId);
    xsArraySetInt(gRegisterTypes, 23, cFortifiedOutpost2Id);
    xsArraySetInt(gRegisterTypes, 24, cFolwarkId);       // before the Mill it replaces
    xsArraySetInt(gRegisterTypes, 25, cMillId);
    xsArraySetInt(gRegisterTypes, 26, cLumberCampId);
    xsArraySetInt(gRegisterTypes, 27, cMiningCampId);
    xsArraySetInt(gRegisterTypes, 28, cShipyardId);
    xsArraySetInt(gRegisterTypes, 29, cPortId);
    xsArraySetInt(gRegisterTypes, 30, cSettlementId);
    xsArraySetInt(gRegisterTypes, 31, cMuleCartId);      // moves: its cover is rechecked each second
    xsArraySetInt(gRegisterTypes, 32, cOutpostId);       // only once fortified (hlRegisterBuildings)
    gCartIds = xsArrayCreateInt(cMaxTrackedCarts, -1, "hlCartIds");
    gCartLoaded = xsArrayCreateInt(cMaxTrackedCarts, 0, "hlCartLoaded");
    gCartRoute = xsArrayCreateInt(cMaxTrackedCarts, -1, "hlCartRoute");
    gCartLastPos = xsArrayCreateVector(cMaxTrackedCarts, vector(-1, -1, -1), "hlCartLastPos");
    gPalaceIds = xsArrayCreateInt(cMaxPlayers, -1, "hlPalaceIds");
    gPalaceBuildable = xsArrayCreateInt(cMaxPlayers, -1, "hlPalaceBuildable");
    gSourcePos = xsArrayCreateVector(cMaxTrackedBuildings, vector(-1, -1, -1), "hlSourcePos");
    gSourceOwner = xsArrayCreateInt(cMaxTrackedBuildings, -1, "hlSourceOwner");
    gScratch = xsArrayCreateInt(1, -1, "hlScratch");
    gTaskIds = xsArrayCreateInt(1, -1, "hlTaskIds");
    gEmptyCarts = xsArrayCreateInt(1, -1, "hlEmptyCarts");
    gLoadedCarts = xsArrayCreateInt(1, -1, "hlLoadedCarts");
    gBuildingShown = xsArrayCreateInt(cMaxTrackedBuildings, -1, "hlBuildingShown");
    gSourceByOwner = xsArrayCreateVector(cMaxTrackedBuildings, vector(-1, -1, -1), "hlSourceByOwner");
    gSourceStart = xsArrayCreateInt(cMaxPlayers, 0, "hlSourceStart");
    gSourceEnd = xsArrayCreateInt(cMaxPlayers, 0, "hlSourceEnd");
    gIsComputer = xsArrayCreateBool(cMaxPlayers, false, "hlIsComputer");
    gRulesOn = xsArrayCreateBool(cMaxPlayers, false, "hlRulesOn");
    gPalaceR = xsArrayCreateFloat(cMaxPlayers, cPalaceRadius, "hlPalaceR");
    gTcR = xsArrayCreateFloat(cMaxPlayers, cTownCenterRadius, "hlTcR");
    gPalacePos = xsArrayCreateVector(cMaxPlayers, vector(-1, -1, -1), "hlPalacePos");
    gAttritionUnits = xsArrayCreateInt(1, -1, "hlAttritionUnits");
    gAttritionCarts = xsArrayCreateInt(1, -1, "hlAttritionCarts");
    gAttritionCartPos = xsArrayCreateVector(cMaxTrackedCarts, vector(-1, -1, -1), "hlAttritionCartPos");
    gAttritionClasses = xsArrayCreateInt(10, -1, "hlAttritionClasses");
    xsArraySetInt(gAttritionClasses, 0, cArcherClassId);
    xsArraySetInt(gAttritionClasses, 1, cInfantryClassId);
    xsArraySetInt(gAttritionClasses, 2, cSiegeClassId);
    xsArraySetInt(gAttritionClasses, 3, cMonkClassId);
    xsArraySetInt(gAttritionClasses, 4, cWarDogClassId);
    xsArraySetInt(gAttritionClasses, 5, cPetardClassId);
    xsArraySetInt(gAttritionClasses, 6, cHandCannoneerClassId);
    xsArraySetInt(gAttritionClasses, 7, cPackedSiegeClassId);
    xsArraySetInt(gAttritionClasses, 8, cUnpackedSiegeClassId);
    xsArraySetInt(gAttritionClasses, 9, cScorpionClassId);
    gBuildingCap = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingCap");
    gCapPercent = xsArrayCreateInt(cMaxPlayers, cSupplyCapBasePercent, "hlCapPercent");
    gEnemySiegeStarve = xsArrayCreateBool(cMaxPlayers, false, "hlEnemySiegeStarve");
    gSabotageSeen = xsArrayCreateFloat(cMaxPlayers, 0.0, "hlSabotageSeen");
    gPendingKills = xsArrayCreateInt(cMaxTrackedCarts, -1, "hlPendingKills");
    // Sabotage & Subterfuge can be researched again and again (tech stacking;
    // TODO(test T42): cModifyTech + cAttrSetStacking makes it re-researchable).
    if (cSabotageTech >= 0) {
        for (p = 1; <= hlLastPlayer()) {
            xsEffectAmount(cModifyTech, cSabotageTech, cAttrSetStacking, 1, p);
            xsEffectAmount(cModifyTech, cSabotageTech, cAttrSetStackingResearchCap, cSabotageMaxUses, p);
        }
    }
}

// Per-player values every rule needs, read once per rule instead of once per
// building or unit (synced game state only).
void hlRefreshPlayers() {
    int last = hlLastPlayer();
    for (p = 1; <= last) {
        xsArraySetBool(gIsComputer, p, xsGetPlayerType(p) == cPlayerTypeComputerId);
        xsArraySetBool(gRulesOn, p, xsPlayerAttribute(p, cAttributeCurrentAge) >= cAgeCastle);
        float bonus = 0.0;
        if (hlTechDone(p, cPavedRoadsTech)) {
            bonus = cPavedRoadsRadiusBonus;
        }
        xsArraySetFloat(gPalaceR, p, cPalaceRadius + bonus);
        xsArraySetFloat(gTcR, p, cTownCenterRadius + bonus);
        int palace = xsArrayGetInt(gPalaceIds, p);
        if (palace >= 0) {
            xsArraySetVector(gPalacePos, p, xsGetUnitPosition(palace));
        }
        int capPercent = cSupplyCapBasePercent;
        if (hlTechDone(p, cSupplyDepotsTech)) {
            capPercent = capPercent + cSupplyDepotsPercent;
        }
        if (hlTechDone(p, cMilitaryWarehousesTech)) {
            capPercent = capPercent + cMilitaryWarehousesPercent;
        }
        xsArraySetInt(gCapPercent, p, capPercent);
        xsArraySetBool(gEnemySiegeStarve, p, false);
    }
    // Siege & Starve Out: mark every player that has an enemy with the tech.
    // Diplomacy is read only for the (rare) players who researched it.
    for (rival = 1; <= last) {
        if (hlTechDone(rival, cSiegeAndStarveTech) == false) {
            continue;
        }
        for (target = 1; <= last) {
            if ((target != rival) && hlIsEnemy(rival, target)) {
                xsArraySetBool(gEnemySiegeStarve, target, true);
            }
        }
    }
}

// Every rule starts here.
void hlBeginTick() {
    hlEnsureInit();
    hlRefreshPlayers();
}

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

// Find each player's Palace and allow building one only while they have none
// (one per player, rebuildable; design section 10). Feudal Age enables it in
// the data; XS touches it only to block a second one and to lift that block.
// Playtest 2026-10-14: with XS also disabling it before Feudal Age, villagers
// never got the button, so XS no longer acts before a Palace exists.
// TODO(test T16): does xsGetPlayerUnitIds list foundations (so a second Palace
// cannot be placed while the first is under construction)? Does an unfinished
// Palace already act as the capital? Does cAttributeEnable lift the block?
rule hlTrackPalaces
    active
    minInterval 1
    maxInterval 1
{
    hlBeginTick();
    if (cPalaceId < 0) {
        return;
    }
    for (p = 1; <= hlLastPlayer()) {
        if (hlIsComputer(p)) {
            continue;
        }
        int palaces = xsGetPlayerUnitIds(p, cPalaceId, gScratch);
        int n = xsArrayGetSize(palaces);
        int palace = -1;
        if (n > 0) {
            palace = xsArrayGetInt(palaces, 0);
        }
        xsArraySetInt(gPalaceIds, p, palace);
        if (palace >= 0) {
            xsArraySetVector(gPalacePos, p, xsGetUnitPosition(palace));
        }

        int state = xsArrayGetInt(gPalaceBuildable, p);
        if ((n > 0) && (state != 0)) {
            xsEffectAmount(cEnableObject, cPalaceId, cAttributeDisable, 0, p);
            xsArraySetInt(gPalaceBuildable, p, 0);
            if (cDebugSupply) {
                xsChatData("Hinterland: Palace building blocked for player " + p, palace);
            }
        } else if ((n == 0) && (state == 0)) {
            xsEffectAmount(cEnableObject, cPalaceId, cAttributeEnable, 0, p);
            xsArraySetInt(gPalaceBuildable, p, 1);
            if (cDebugSupply) {
                xsChatData("Hinterland: Palace building allowed again for player " + p, p);
            }
        }
    }
}

// Register new supply recipients. New ones start with only cNewBuildingSupplySeconds
// (no building-drop strategy); the countdown starts once construction finishes.
// Towers and the other shooting buildings too (playtest 2026-10-15: tower drops
// kept shooting anywhere), and drop sites (decision 2026-10-15: gathering needs
// supply); they go dark out of supply (hlSetBuildingLocked).
rule hlRegisterBuildings
    active
    minInterval 5
    maxInterval 5
{
    hlBeginTick();
    int types = xsArrayGetSize(gRegisterTypes);
    for (p = 1; <= hlLastPlayer()) {
        if (hlIsComputer(p)) {
            continue;   // AI buildings never need supply
        }
        for (t = 0; < types) {
            int objectId = xsArrayGetInt(gRegisterTypes, t);
            if ((objectId == cOutpostId) && (hlCivVariant(p, cOutpostId) < 0)) {
                continue;   // a plain Outpost needs no supply; a Fortified one keeps its identity
            }
            int ids = xsGetPlayerUnitIds(p, objectId, gScratch);
            int n = xsArrayGetSize(ids);
            for (i = 0; < n) {
                int id = xsArrayGetInt(ids, i);
                if (hlFindBuilding(id) >= 0) {
                    continue;
                }
                if (gBuildingCount >= cMaxTrackedBuildings) {
                    break;
                }
                xsArraySetInt(gBuildingIds, gBuildingCount, id);
                hlSetSlot(gBuildingSlotOf, id, gBuildingCount);
                xsArraySetInt(gBuildingSupply, gBuildingCount, cNewBuildingSupplySeconds);
                xsArraySetInt(gBuildingLocked, gBuildingCount, 0);
                xsArraySetInt(gBuildingIsTc, gBuildingCount, 0);
                xsArraySetInt(gBuildingType, gBuildingCount, objectId);
                xsArraySetInt(gBuildingReady, gBuildingCount, 0);
                xsArraySetInt(gBuildingCover, gBuildingCount, cCoverNone);
                xsArraySetInt(gBuildingTries, gBuildingCount, 0);
                xsArraySetInt(gBuildingLive, gBuildingCount, -1);
                xsArraySetInt(gBuildingShown, gBuildingCount, -1);
                if ((objectId == cTownCenterId) || (objectId == cEconomicTownCenterId) ||
                    (objectId == cDefensiveTownCenterId) || (objectId == cMilitaryTownCenterId)) {
                    xsArraySetInt(gBuildingIsTc, gBuildingCount, 1);
                }
                xsArraySetInt(gBuildingCap, gBuildingCount, hlSupplyCapFor(gBuildingCount, p));
                gBuildingCount++;
            }
        }
    }
}

// From Castle Age: drain 1s per second outside coverage, refill inside, lock at 0.
rule hlSupplyTick
    active
    minInterval 1
    maxInterval 1
{
    hlBeginTick();
    hlRebuildSources();
    int i = 0;
    while (i < gBuildingCount) {
        int id = xsArrayGetInt(gBuildingIds, i);
        if (xsDoesUnitExist(id) == false) {
            // Swap-remove.
            int last = gBuildingCount - 1;
            hlSetSlot(gBuildingSlotOf, id, -1);
            if (last != i) {
                hlSetSlot(gBuildingSlotOf, xsArrayGetInt(gBuildingIds, last), i);
            }
            xsArraySetInt(gBuildingIds, i, xsArrayGetInt(gBuildingIds, last));
            xsArraySetInt(gBuildingSupply, i, xsArrayGetInt(gBuildingSupply, last));
            xsArraySetInt(gBuildingLocked, i, xsArrayGetInt(gBuildingLocked, last));
            xsArraySetInt(gBuildingIsTc, i, xsArrayGetInt(gBuildingIsTc, last));
            xsArraySetInt(gBuildingType, i, xsArrayGetInt(gBuildingType, last));
            xsArraySetInt(gBuildingReady, i, xsArrayGetInt(gBuildingReady, last));
            xsArraySetInt(gBuildingCover, i, xsArrayGetInt(gBuildingCover, last));
            xsArraySetInt(gBuildingTries, i, xsArrayGetInt(gBuildingTries, last));
            xsArraySetInt(gBuildingLive, i, xsArrayGetInt(gBuildingLive, last));
            xsArraySetInt(gBuildingShown, i, xsArrayGetInt(gBuildingShown, last));
            xsArraySetInt(gBuildingCap, i, xsArrayGetInt(gBuildingCap, last));
            gBuildingCount--;
            continue;
        }
        int owner = xsGetUnitOwner(id);
        xsArraySetInt(gBuildingCap, i, hlSupplyCapFor(i, owner));
        if (hlIsComputer(owner)) {
            // Converted to (or taken over by) the AI: back to normal, no caption.
            // Full supply and a clean state, so a human who converts it back
            // starts a normal countdown (not an instant dark outpost).
            if (xsArrayGetInt(gBuildingLocked, i) == 1) {
                hlSetBuildingLocked(i, false);
            }
            xsArraySetInt(gBuildingSupply, i, hlSupplyCap(i));
            xsArraySetInt(gBuildingCover, i, cCoverNone);
            xsArraySetInt(gBuildingTries, i, 0);
            hlUpdateCaption(i, true);
            i++;
            continue;
        }
        int s = xsArrayGetInt(gBuildingSupply, i);
        if (xsArrayGetInt(gBuildingReady, i) == 0) {
            if (hlIsBuilt(i) == false) {
                i++;
                continue;   // under construction: no drain, no lock, no caption
            }
            xsArraySetInt(gBuildingReady, i, 1);
        }
        int cover = cCoverPalace;   // before Castle Age everything counts as covered
        if (hlSupplyRulesOn(owner)) {
            bool isTc = (xsArrayGetInt(gBuildingIsTc, i) == 1);
            cover = hlCoverType(owner, xsGetUnitPosition(id), isTc);
        }
        bool covered = (cover != cCoverNone);
        if (covered) {
            s = hlSupplyCap(i);
        } else if (xsArrayGetInt(gBuildingCover, i) == cCoverTc) {
            // Its TC was lost or ran dry: the outpost goes dark at once. With
            // Star Fortress a Castle or Krepost keeps half its max supply
            // instead (decision 2026-10-20; also when the TC only ran dry).
            s = 0;
            int registered = xsArrayGetInt(gBuildingType, i);
            if (((registered == cCastleId) || (registered == cKrepostId)) &&
                hlTechDone(owner, cStarFortressTech)) {
                s = hlSupplyCap(i) * cStarFortressPercent / 100;
            }
        } else if (s > 0) {
            s--;
        }
        if (s > hlSupplyCap(i)) {
            s = hlSupplyCap(i);
        }
        xsArraySetInt(gBuildingCover, i, cover);
        xsArraySetInt(gBuildingSupply, i, s);

        bool locked = (xsArrayGetInt(gBuildingLocked, i) == 1);
        if ((s <= 0) && (locked == false)) {
            hlSetBuildingLocked(i, true);
        } else if ((s > 0) && locked) {
            hlSetBuildingLocked(i, false);
        } else if (locked && (xsArrayGetInt(gBuildingLive, i) >= 0)) {
            // An age-up does not upgrade a dark twin. Playtest 2026-10-15: a dark
            // Castle Age TC vanished from view at the Imperial age-up (still
            // there: a cart restored it). Re-swap it to the new age's dark twin.
            int wasLive = xsArrayGetInt(gBuildingLive, i);
            int nowLive = hlUpgradedType(owner, wasLive);
            if ((nowLive != wasLive) && (hlDarkType(nowLive) >= 0)) {
                hlSwapBuilding(i, hlDarkType(nowLive));
                xsArraySetInt(gBuildingLive, i, nowLive);
                xsSetUnitProperty(xsArrayGetInt(gBuildingIds, i), cUnitSelectable, 0);
            }
        } else if (locked) {
            int fortress = xsArrayGetInt(gBuildingType, i);
            if (((fortress == cCastleId) || (fortress == cKrepostId)) &&
                xsArrayGetBool(gEnemySiegeStarve, owner)) {
                // An enemy researched Siege & Starve Out while this Castle or
                // Krepost was locked but still firing: it goes dark now
                // (queue cancelled, garrison out, then the swap).
                hlSetBuildingLocked(i, true);
            } else {
                // Unselectable does not drop a building the player already has
                // selected (playtest 2026-10-15): its panel still queues units and
                // techs. No XS call deselects one building, so cancel (and refund)
                // anything queued every second while locked (T24 passed).
                hlCancelQueue(id);
                if ((fortress == cCastleId) || (fortress == cKrepostId)) {
                    // Playtest 2026-10-20: a dry Castle kept its garrison. It
                    // stays empty while out of supply: anyone who garrisons is
                    // pushed out again within a second. It still shoots (until
                    // an enemy has Siege & Starve Out).
                    hlEjectGarrison(id);
                }
            }
        }
        if (hlSupplyRulesOn(owner)) {
            hlUpdateCaption(i, covered);
        }
        i++;
    }
}

// Gold a delivery to a TC at `tcPos` earns on top of the cart's own gold:
// Provincial Governors +5; Colonial Administration +5 per map-scaled 20 tiles
// between the Palace and the TC (decision 2026-10-20). The two add up.
float hlDeliveryProfit(int p = -1, vector tcPos = vector(0, 0, 0)) {
    float profit = 0.0;
    if (hlTechDone(p, cProvincialGovernorsTech)) {
        profit = profit + cProvincialGovernorsGold;
    }
    if (hlTechDone(p, cColonialAdministrationTech) && (xsArrayGetInt(gPalaceIds, p) >= 0)) {
        float stepTiles = hlMapScaled(cColonialStepTiles);
        float steps = floor(dist(xsArrayGetVector(gPalacePos, p), tcPos) / stepTiles);
        if (steps > cColonialMaxSteps) {
            steps = cColonialMaxSteps;
        }
        profit = profit + steps * cColonialGoldPerStep;
    }
    return (profit);
}

// Bribe Officials (decision 2026-10-20): a loaded cart of player p stopped
// within delivery range of an out-of-supply (locked) building of an enemy
// converts it to p, as a monk would, and hands over its load: the building
// gets one delivery's supply and p's cart goes home empty. Called only when
// no own building takes the load. TODO(test T43): xsSetUnitOwner on a building
// (and on a dark twin, which then swaps back as p's live type).
void hlBribe(int p = -1, int ci = -1, int cart = -1, vector cartPos = vector(0, 0, 0)) {
    int target = -1;
    float targetDist = 9999.0;
    for (b = 0; < gBuildingCount) {
        if ((xsArrayGetInt(gBuildingLocked, b) == 0) || (xsArrayGetInt(gBuildingSupply, b) > 0)) {
            continue;
        }
        int building = xsArrayGetInt(gBuildingIds, b);
        int owner = xsGetUnitOwner(building);
        if ((owner == p) || hlIsComputer(owner) || (hlIsEnemy(p, owner) == false)) {
            continue;
        }
        float toBuilding = dist(cartPos, xsGetUnitPosition(building));
        if ((toBuilding > cCartDeliveryRange) || (toBuilding >= targetDist)) {
            continue;
        }
        target = b;
        targetDist = toBuilding;
    }
    if (target < 0) {
        return;
    }
    int id = xsArrayGetInt(gBuildingIds, target);
    int victim = xsGetUnitOwner(id);
    xsSetUnitOwner(id, p, true);
    // Still locked: next hlSupplyTick sees supply > 0 and unlocks it for p.
    int cap = hlSupplyCapFor(target, p);
    int s = hlMapScaled(cSupplyRefuelSeconds);
    if (s > cap) {
        s = cap;
    }
    xsArraySetInt(gBuildingCap, target, cap);
    xsArraySetInt(gBuildingSupply, target, s);
    xsArraySetInt(gBuildingCover, target, cCoverNone);
    xsArraySetInt(gBuildingTries, target, 0);
    xsArraySetInt(gBuildingShown, target, -1);
    xsChatData("Bribe Officials: player " + p + " bought a building of player " + victim, p);
    xsArraySetInt(gCartRoute, ci, -1);
    int empty = hlSwapCart(ci, cart, p, false);
    int palace = xsArrayGetInt(gPalaceIds, p);
    if (palace >= 0) {
        hlMoveCart(empty, palace);
    }
}

// Load at the Palace, deliver to the nearest non-full recipient where the cart
// stopped. Loading and delivering swap the cart between its empty and loaded
// unit types (hlSwapCart). Loading costs cCartGold. The loaded unit's task 161
// pays it back: to the killer if the cart is destroyed, else to its current
// owner when the delivery swap removes it. A delivery sets the cart's route; XS then shuttles it
// between the Palace and that building with Move orders (U5).
// Without a Palace, carts already loaded still deliver; they just cannot reload.
void hlCartTick(int p = -1, int cart = -1, bool isLoadedType = false) {
    int palace = xsArrayGetInt(gPalaceIds, p);
    int ci = hlFindCart(cart);
    if (ci < 0) {
        if (gCartCount >= cMaxTrackedCarts) {
            return;
        }
        ci = gCartCount;
        xsArraySetInt(gCartIds, ci, cart);
        hlSetSlot(gCartSlotOf, cart, ci);
        xsArraySetInt(gCartRoute, ci, -1);
        xsArraySetVector(gCartLastPos, ci, vector(-1, -1, -1));
        gCartCount++;
    }
    if (isLoadedType) {
        xsArraySetInt(gCartLoaded, ci, 1);
    } else {
        xsArraySetInt(gCartLoaded, ci, 0);
    }
    vector cartPos = xsGetUnitPosition(cart);
    bool stopped = (dist(cartPos, xsArrayGetVector(gCartLastPos, ci)) < cCartStoppedEpsilon);
    xsArraySetVector(gCartLastPos, ci, cartPos);

    if (isLoadedType == false) {
        if (palace < 0) {
            return;
        }
        if (dist(cartPos, xsGetUnitPosition(palace)) > cCartLoadRange) {
            return;
        }
        // Loading takes cCartGold from the owner; without it the cart waits.
        float gold = xsPlayerAttribute(p, cAttributeGold);
        if (gold < cCartGold) {
            return;
        }
        xsSetPlayerAttribute(p, cAttributeGold, gold - cCartGold);
        int loaded = hlSwapCart(ci, cart, p, true);
        int route = xsArrayGetInt(gCartRoute, ci);
        if ((route >= 0) && xsDoesUnitExist(route) && (xsGetUnitOwner(route) == p)) {
            hlMoveCart(loaded, route);
        } else {
            xsArraySetInt(gCartRoute, ci, -1);
        }
        return;
    }

    // Unload only where the cart stopped: the building the player (or the
    // route) sent it to. Carts driving past other buildings keep their load.
    // Of the buildings in range, the nearest non-full one takes the load;
    // full ones (every covered building) never do. Moving carts skip the scan.
    if (stopped == false) {
        return;
    }
    int target = -1;
    float targetDist = 9999.0;
    // Cheapest filter first: full buildings are skipped from the arrays alone,
    // since carts parked by an army (attrition) count as stopped every second.
    for (b = 0; < gBuildingCount) {
        if (xsArrayGetInt(gBuildingSupply, b) >= hlSupplyCap(b)) {
            continue;
        }
        int building = xsArrayGetInt(gBuildingIds, b);
        if (xsGetUnitOwner(building) != p) {
            continue;
        }
        float toBuilding = dist(cartPos, xsGetUnitPosition(building));
        if ((toBuilding > cCartDeliveryRange) || (toBuilding >= targetDist)) {
            continue;
        }
        target = b;
        targetDist = toBuilding;
    }
    if (target < 0) {
        if (hlTechDone(p, cBribeOfficialsTech)) {
            hlBribe(p, ci, cart, cartPos);
        }
        return;
    }
    int s = xsArrayGetInt(gBuildingSupply, target) + hlMapScaled(cSupplyRefuelSeconds);
    if (s > hlSupplyCap(target)) {
        s = hlSupplyCap(target);
    }
    xsArraySetInt(gBuildingSupply, target, s);
    // No cCartGold here: removing the loaded cart in hlSwapCart fires its task
    // 161 refund with no killer, which pays its current owner cCartGold
    // (playtest 2026-10-14: an XS refund on top paid 2x). Only the techs' profit.
    if (xsArrayGetInt(gBuildingIsTc, target) == 1) {
        float profit = hlDeliveryProfit(p, xsGetUnitPosition(xsArrayGetInt(gBuildingIds, target)));
        if (profit > 0.0) {
            xsSetPlayerAttribute(p, cAttributeGold, xsPlayerAttribute(p, cAttributeGold) + profit);
        }
    }
    xsArraySetInt(gCartRoute, ci, xsArrayGetInt(gBuildingIds, target));
    int empty = hlSwapCart(ci, cart, p, false);
    if (palace >= 0) {
        hlMoveCart(empty, palace);
    }
}

rule hlCartLogistics
    active
    minInterval 1
    maxInterval 1
{
    hlBeginTick();
    if ((cSupplyCartId < 0) || (cLoadedSupplyCartId < 0)) {
        return;
    }
    hlSweepCarts();
    for (p = 1; <= hlLastPlayer()) {
        if (hlIsComputer(p)) {
            continue;
        }
        // Both lists first: swaps during the tick must not be seen twice.
        int empties = xsGetPlayerUnitIds(p, cSupplyCartId, gEmptyCarts);
        int loadeds = xsGetPlayerUnitIds(p, cLoadedSupplyCartId, gLoadedCarts);
        int ne = xsArrayGetSize(empties);
        int nl = xsArrayGetSize(loadeds);
        for (c = 0; < ne) {
            hlCartTick(p, xsArrayGetInt(empties, c), false);
        }
        for (c = 0; < nl) {
            hlCartTick(p, xsArrayGetInt(loadeds, c), true);
        }
    }
}

// A player's supplied TCs: finished, with supply left (their active sources,
// from the last hlRebuildSources). A dry TC is outside its owner's control,
// so neither government tech counts it (decision 2026-10-20).
int hlSuppliedTownCenters(int p = -1) {
    return (xsArrayGetInt(gSourceEnd, p) - xsArrayGetInt(gSourceStart, p));
}

// Palace tech incomes, paid every second (palace_techs.py). Each government
// tech replaces the one before it, so only the newest pays: Centralized
// Government +150 gold/min with at most 1 supplied TC; else Decentralized
// Government +20 gold/min per supplied TC; else Feudal Taxation +5 food/min
// per villager.
rule hlPalaceIncome
    active
    minInterval 1
    maxInterval 1
{
    hlBeginTick();
    for (p = 1; <= hlLastPlayer()) {
        if (hlIsComputer(p)) {
            continue;
        }
        if (hlTechDone(p, cCentralizedGovernmentTech)) {
            if (hlSuppliedTownCenters(p) <= cCentralizedMaxTownCenters) {
                xsSetPlayerAttribute(p, cAttributeGold, xsPlayerAttribute(p, cAttributeGold) + cCentralizedGold / 60.0);
            }
        } else if (hlTechDone(p, cDecentralizedGovernmentTech)) {
            float tcs = hlSuppliedTownCenters(p);
            if (tcs > 0.0) {
                xsSetPlayerAttribute(p, cAttributeGold, xsPlayerAttribute(p, cAttributeGold) + tcs * cDecentralizedGoldPerTc / 60.0);
            }
        } else if (hlTechDone(p, cFeudalTaxationTech)) {
            // TODO(test T36): xsGetPlayerUnitIds with a class ID (904 = villagers).
            float villagers = xsArrayGetSize(xsGetPlayerUnitIds(p, cVillagerClassId, gScratch));
            if (villagers > 0.0) {
                xsSetPlayerAttribute(p, cResFood, xsPlayerAttribute(p, cResFood) + villagers * cFeudalTaxationFoodPerVillager / 60.0);
            }
        }
    }
}

// Attrition (decision 2026-10-20): from Castle Age, each non-cavalry military
// unit outside its owner's supply radii (Palace, supplied TCs; hlCoverType)
// and farther than cAttritionCartRadius from one of the owner's loaded Supply
// Carts loses cAttritionPercent of its max HP every 2 s. Garrisoned units are
// sheltered. TODO(test T37): does HP 0 kill the unit? If it is still there
// next tick, it is removed, wherever it stands by then. Needs the data mod
// (Palace and carts); without it no player could ever be supplied.
// Unverified: xsGetGarrisonedInUnitId returns < 0 when not garrisoned.
rule hlAttrition
    active
    minInterval 2
    maxInterval 2
{
    hlBeginTick();
    if ((cPalaceId < 0) || (cLoadedSupplyCartId < 0)) {
        return;
    }
    int classes = xsArrayGetSize(gAttritionClasses);
    for (p = 1; <= hlLastPlayer()) {
        if (hlIsComputer(p) || (hlSupplyRulesOn(p) == false)) {
            continue;
        }
        // Loaded-cart positions once per player, not once per unit.
        int carts = xsGetPlayerUnitIds(p, cLoadedSupplyCartId, gAttritionCarts);
        int nc = xsArrayGetSize(carts);
        if (nc > cMaxTrackedCarts) {
            nc = cMaxTrackedCarts;
        }
        for (c = 0; < nc) {
            xsArraySetVector(gAttritionCartPos, c, xsGetUnitPosition(xsArrayGetInt(carts, c)));
        }
        for (t = 0; < classes) {
            int units = xsGetPlayerUnitIds(p, xsArrayGetInt(gAttritionClasses, t), gAttritionUnits);
            int n = xsArrayGetSize(units);
            for (u = 0; < n) {
                int id = xsArrayGetInt(units, u);
                if (xsGetGarrisonedInUnitId(id) >= 0) {
                    continue;
                }
                float hp = xsGetUnitHitpoints(id);
                if (hp <= 0.0) {
                    // Set to 0 last tick and still here: before the cover and
                    // cart checks, so walking into supply cannot save it.
                    xsRemoveUnit(id);
                    continue;
                }
                vector pos = xsGetUnitPosition(id);
                if (hlCoverType(p, pos, false) != cCoverNone) {
                    continue;
                }
                bool nearCart = false;
                for (c = 0; < nc) {
                    if (dist(xsArrayGetVector(gAttritionCartPos, c), pos) <= cAttritionCartRadius) {
                        nearCart = true;
                        break;
                    }
                }
                if (nearCart) {
                    continue;
                }
                float maxHp = xsGetObjectAttribute(p, xsGetUnitObjectId(id), cHitpoints, 0);
                hp = hp - maxHp * cAttritionPercent / 100.0;
                if (hp < 0.0) {
                    hp = 0.0;
                }
                xsSetUnitHitpoints(id, hp);
            }
        }
    }
}

// Kill a unit by setting its HP to 0; hlSabotage removes it next second if the
// engine did not (TODO(test T37): does HP 0 kill?).
void hlKillUnit(int id = -1) {
    xsSetUnitHitpoints(id, 0.0);
    if (gPendingKillCount < xsArrayGetSize(gPendingKills)) {
        xsArraySetInt(gPendingKills, gPendingKillCount, id);
        gPendingKillCount++;
    }
}

// Tracked building b is an enemy TC that Sabotage can drain: finished, with
// supply left, not inside its owner's Palace radius last tick.
bool hlSabotageTc(int p = -1, int b = -1) {
    if ((xsArrayGetInt(gBuildingIsTc, b) == 0) || (xsArrayGetInt(gBuildingReady, b) == 0)) {
        return (false);
    }
    if ((xsArrayGetInt(gBuildingSupply, b) <= 0) || (xsArrayGetInt(gBuildingCover, b) == cCoverPalace)) {
        return (false);
    }
    int owner = xsGetUnitOwner(xsArrayGetInt(gBuildingIds, b));
    return ((owner != p) && (hlIsComputer(owner) == false) && hlIsEnemy(p, owner));
}

// One use of Sabotage & Subterfuge by player p: kill a random Supply Cart
// (empty or loaded) of p's enemies; if they have none, drain a random enemy
// TC that is not inside its own Palace radius (one there refills at once).
void hlSabotageOnce(int p = -1) {
    int last = hlLastPlayer();
    int total = 0;
    for (q = 1; <= last) {
        if ((q == p) || hlIsComputer(q) || (hlIsEnemy(p, q) == false)) {
            continue;
        }
        total = total + xsArrayGetSize(xsGetPlayerUnitIds(q, cSupplyCartId, gScratch));
        total = total + xsArrayGetSize(xsGetPlayerUnitIds(q, cLoadedSupplyCartId, gScratch));
    }
    if (total > 0) {
        int pick = xsGetRandomNumberMax(total);
        for (q = 1; <= last) {
            if ((q == p) || hlIsComputer(q) || (hlIsEnemy(p, q) == false)) {
                continue;
            }
            for (kind = 0; < 2) {
                int objectId = cSupplyCartId;
                if (kind == 1) {
                    objectId = cLoadedSupplyCartId;
                }
                int carts = xsGetPlayerUnitIds(q, objectId, gScratch);
                int n = xsArrayGetSize(carts);
                if (pick < n) {
                    hlKillUnit(xsArrayGetInt(carts, pick));
                    xsChatData("Sabotage: player " + p + " destroyed a Supply Cart of player " + q, p);
                    return;
                }
                pick = pick - n;
            }
        }
        return;
    }
    int tcs = 0;
    for (b = 0; < gBuildingCount) {
        if (hlSabotageTc(p, b)) {
            tcs++;
        }
    }
    if (tcs == 0) {
        xsChatData("Sabotage: player " + p + " found no enemy cart or Town Center to sabotage", p);
        return;
    }
    int which = xsGetRandomNumberMax(tcs);
    for (b = 0; < gBuildingCount) {
        if (hlSabotageTc(p, b) == false) {
            continue;
        }
        if (which == 0) {
            xsArraySetInt(gBuildingSupply, b, 0);
            xsChatData("Sabotage: player " + p + " drained a Town Center of player " +
                       xsGetUnitOwner(xsArrayGetInt(gBuildingIds, b)), p);
            return;
        }
        which--;
    }
}

// Sabotage & Subterfuge (decision 2026-10-20). Its tech effect adds 1 to
// player resource cSabotageCounterRes per research; each new count is one use.
// After every use, by anyone, the price rises for every player.
// TODO(test T42): repeat research (stacking) and the price change.
rule hlSabotage
    active
    minInterval 1
    maxInterval 1
{
    hlBeginTick();
    for (k = 0; < gPendingKillCount) {
        int victim = xsArrayGetInt(gPendingKills, k);
        if (xsDoesUnitExist(victim)) {
            xsRemoveUnit(victim);
        }
    }
    gPendingKillCount = 0;
    if ((cSabotageTech < 0) || (cSupplyCartId < 0)) {
        return;
    }
    bool priced = false;
    for (p = 1; <= hlLastPlayer()) {
        if (hlIsComputer(p)) {
            continue;
        }
        float used = xsPlayerAttribute(p, cSabotageCounterRes);
        float seen = xsArrayGetFloat(gSabotageSeen, p);
        while (seen < used) {
            hlSabotageOnce(p);
            seen = seen + 1.0;
            gSabotageUses++;
            priced = true;
        }
        xsArraySetFloat(gSabotageSeen, p, seen);
    }
    if (priced) {
        for (p = 1; <= hlLastPlayer()) {
            xsEffectAmount(cModifyTech, cSabotageTech, cAttrSetFoodCost,
                           cSabotageBaseFood + gSabotageUses * cSabotageStepFood, p);
            xsEffectAmount(cModifyTech, cSabotageTech, cAttrSetGoldCost,
                           cSabotageBaseGold + gSabotageUses * cSabotageStepGold, p);
        }
    }
}

// Food upkeep: military pop x rate per second (resources are floats).
// At 0 food the starvation debuff applies to every unit (design section 5).
// TODO(slice 7): starvation debuff once the aura/debuff layer (slice 5) exists.
rule hlFoodUpkeep
    inactive
    minInterval 1
    maxInterval 1
{
    hlBeginTick();
    for (p = 1; <= hlLastPlayer()) {
        if (hlIsComputer(p)) {
            continue;
        }
        float cost = xsPlayerAttribute(p, cResMilitaryPop) * cFoodUpkeepPerUnitPerSecond;
        float food = xsPlayerAttribute(p, cResFood);
        if (food <= cost) {
            xsSetPlayerAttribute(p, cResFood, 0.0);
        } else {
            xsSetPlayerAttribute(p, cResFood, food - cost);
        }
    }
}
