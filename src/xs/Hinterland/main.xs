// Hinterland Supply Lines - entry point.
// The build flattens this into one file and appends it to the game's Effects.xs
// (assemble.py), so it runs on every map without a custom RMS.
//
// Status: slices 1-3 (supply window, carts, Palace network; design sections 3,
// 4, 11). Everything marked TODO(test) depends on an in-game test listed in
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
int gBuildingTries = -1;     // towers: seconds spent emptying the garrison before going dark
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

// Palace (the capital) per player, index = player ID; -1 = none.
int gPalaceIds = -1;
// Last Palace build state XS set per player: -1 unknown, 0 disabled, 1 enabled.
int gPalaceBuildable = -1;

// Active TCs this tick (rebuilt each hlSupplyTick): they cover buildings around them.
int gSourcePos = -1;
int gSourceOwner = -1;
int gSourceCount = 0;

// Scratch array reused by xsGetPlayerUnitIds.
int gScratch = -1;

// One-element array for xsTaskUnits.
int gTaskIds = -1;

// Cart lists per tick (empty and loaded types), kept apart from gScratch.
int gEmptyCarts = -1;
int gLoadedCarts = -1;


// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Supply rules start at Castle Age (design section 3); Dark/Feudal play as normal.
bool hlSupplyRulesOn(int playerId = -1) {
    return (xsPlayerAttribute(playerId, cAttributeCurrentAge) >= cAgeCastle);
}

// What covers `pos`: the owner's Palace radius first, then (for anything but a
// TC) the radius of one of the owner's active TCs. TCs do not chain: a TC is
// active only through the Palace or its own supply (design section 11).
int hlCoverType(int playerId = -1, vector pos = vector(0, 0, 0), bool isTc = false) {
    int palace = xsArrayGetInt(gPalaceIds, playerId);
    if ((palace >= 0) && (dist(xsGetUnitPosition(palace), pos) <= cPalaceRadius)) {
        return (cCoverPalace);
    }
    if (isTc) {
        return (cCoverNone);
    }
    for (i = 0; < gSourceCount) {
        if (xsArrayGetInt(gSourceOwner, i) != playerId) {
            continue;
        }
        if (dist(xsArrayGetVector(gSourcePos, i), pos) <= cTownCenterRadius) {
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

int hlFindBuilding(int unitId = -1) {
    for (i = 0; < gBuildingCount) {
        if (xsArrayGetInt(gBuildingIds, i) == unitId) {
            return (i);
        }
    }
    return (-1);
}

int hlFindCart(int unitId = -1) {
    for (i = 0; < gCartCount) {
        if (xsArrayGetInt(gCartIds, i) == unitId) {
            return (i);
        }
    }
    return (-1);
}

bool hlIsTowerType(int objectId = -1) {
    return ((objectId == cWatchTowerId) || (objectId == cGuardTowerId) || (objectId == cKeepId) ||
        (objectId == cBombardTowerId) || (objectId == cDonjonId));
}

// What a tower registered as `objectId` is today: Guard Tower and Keep upgrade
// towers in place, and a dark twin never upgrades, so go by the techs.
int hlLiveTowerType(int playerId = -1, int objectId = -1) {
    if ((objectId != cWatchTowerId) && (objectId != cGuardTowerId)) {
        return (objectId);
    }
    if (xsGetTechState(cKeepTech, playerId) == cTechStateDone) {
        return (cKeepId);
    }
    if (xsGetTechState(cGuardTowerTech, playerId) == cTechStateDone) {
        return (cGuardTowerId);
    }
    return (objectId);
}

// The data-mod twin that cannot attack (dark_towers.py); -1 before the dat is built.
int hlDarkTowerType(int liveId = -1) {
    if (liveId == cWatchTowerId) { return (cDarkWatchTowerId); }
    if (liveId == cGuardTowerId) { return (cDarkGuardTowerId); }
    if (liveId == cKeepId) { return (cDarkKeepId); }
    if (liveId == cBombardTowerId) { return (cDarkBombardTowerId); }
    if (liveId == cDonjonId) { return (cDarkDonjonId); }
    return (-1);
}

// Cancel ONE building's queue with refund: xsTaskUnits(Stop) + xsStopUnit
// (U14, T8 passed 2026-10-14; which of the two calls does it is untested).
void hlCancelQueue(int id = -1) {
    xsArraySetInt(gTaskIds, 0, id);
    xsTaskUnits(gTaskIds, cActionTypeStop, vector(-1, -1, -1), -1, false, false, false, -1);
    xsStopUnit(id);
}

// Swap a tracked tower in place between its live type and its dark twin,
// keeping HP; the tracked slot and cart routes follow the new unit ID. Like the
// cart swap (T17), the tower leaves the player's selection. Does nothing when
// there is no dark twin (dat not built). Playtested (T23).
void hlSwapTower(int index = -1, bool dark = false) {
    int id = xsArrayGetInt(gBuildingIds, index);
    int owner = xsGetUnitOwner(id);
    int objectId = hlLiveTowerType(owner, xsArrayGetInt(gBuildingType, index));
    if (dark) {
        objectId = hlDarkTowerType(objectId);
    }
    if (objectId < 0) {
        return;
    }
    vector pos = xsGetUnitPosition(id);
    float hp = xsGetUnitHitpoints(id);
    xsRemoveUnit(id);
    int nid = xsCreateUnit(objectId, owner, pos, false, false, false);
    xsSetUnitHitpoints(nid, hp);
    xsArraySetInt(gBuildingIds, index, nid);
    for (c = 0; < gCartCount) {
        if (xsArrayGetInt(gCartRoute, c) == id) {
            xsArraySetInt(gCartRoute, c, nid);
        }
    }
}

// Lock or unlock training and research at ONE building (TCs included).
// Unselectable = no new queue entries (U6, T7 passed); locking also cancels the
// queue. Towers instead go dark: they turn into a twin that cannot shoot.
void hlSetBuildingLocked(int index = -1, bool locked = false) {
    int id = xsArrayGetInt(gBuildingIds, index);
    bool tower = hlIsTowerType(xsArrayGetInt(gBuildingType, index));
    if (locked) {
        if (tower) {
            // Empty it first (T23 passed): the dark twin holds no garrison.
            // Retried each second, then it goes dark anyway.
            int tries = xsArrayGetInt(gBuildingTries, index);
            int garrison = xsGetGarrisonedUnitIds(id);
            if ((xsArrayGetSize(garrison) > 0) && (tries < cTowerUngarrisonTicks)) {
                xsArraySetInt(gTaskIds, 0, id);
                xsTaskUnits(gTaskIds, cActionTypeUngarrison, xsGetUnitPosition(id), -1, false, false, false, -1);
                xsArraySetInt(gBuildingTries, index, tries + 1);
                return;
            }
            xsArraySetInt(gBuildingTries, index, 0);
            hlSwapTower(index, true);
            id = xsArrayGetInt(gBuildingIds, index);
        } else {
            hlCancelQueue(id);
        }
        xsSetUnitProperty(id, cUnitSelectable, 0);
        xsArraySetInt(gBuildingLocked, index, 1);
    } else {
        if (tower) {
            hlSwapTower(index, false);
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

// Covered buildings show no caption.
void hlUpdateCaption(int index = -1, bool covered = false) {
    int id = xsArrayGetInt(gBuildingIds, index);
    int s = xsArrayGetInt(gBuildingSupply, index);
    string text = "Supply " + s + "s";
    if (covered) {
        text = "";
    } else if (s <= 0) {
        text = "OUT OF SUPPLY";
    }
    xsSetUnitCaption(id, text);
}

// Active TCs this tick: finished, and inside their Palace radius or with supply
// left. Before Castle Age every finished TC is active.
void hlRebuildSources() {
    gSourceCount = 0;
    for (i = 0; < gBuildingCount) {
        if (xsArrayGetInt(gBuildingIsTc, i) == 0) {
            continue;
        }
        if (xsArrayGetInt(gBuildingSupply, i) <= 0) {
            continue;
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
    gBuildingIds = xsArrayCreateInt(cMaxTrackedBuildings, -1, "hlBuildingIds");
    gBuildingSupply = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingSupply");
    gBuildingLocked = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingLocked");
    gBuildingIsTc = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingIsTc");
    gBuildingType = xsArrayCreateInt(cMaxTrackedBuildings, -1, "hlBuildingType");
    gBuildingReady = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingReady");
    gBuildingCover = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingCover");
    gBuildingTries = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingTries");
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
    hlEnsureInit();
    if (cPalaceId < 0) {
        return;
    }
    for (p = 1; < xsGetNumPlayers()) {
        int palaces = xsGetPlayerUnitIds(p, cPalaceId, gScratch);
        int n = xsArrayGetSize(palaces);
        int palace = -1;
        if (n > 0) {
            palace = xsArrayGetInt(palaces, 0);
        }
        xsArraySetInt(gPalaceIds, p, palace);

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
// Towers too (playtest 2026-10-15: tower drops kept shooting anywhere); Keeps and
// Guard Towers come before Watch Towers so a tower registers as its own type.
rule hlRegisterBuildings
    active
    minInterval 5
    maxInterval 5
{
    hlEnsureInit();
    int types = 16;
    for (p = 1; < xsGetNumPlayers()) {
        for (t = 0; < types) {
            int objectId = cBarracksId;
            if (t == 1) { objectId = cArcheryRangeId; }
            if (t == 2) { objectId = cStableId; }
            if (t == 3) { objectId = cSiegeWorkshopId; }
            if (t == 4) { objectId = cCastleId; }
            if (t == 5) { objectId = cMonasteryId; }
            if (t == 6) { objectId = cDockId; }
            if (t == 7) { objectId = cMarketId; }
            if (t == 8) { objectId = cBlacksmithId; }
            if (t == 9) { objectId = cUniversityId; }
            if (t == 10) { objectId = cTownCenterId; }
            if (t == 11) { objectId = cKeepId; }
            if (t == 12) { objectId = cGuardTowerId; }
            if (t == 13) { objectId = cWatchTowerId; }
            if (t == 14) { objectId = cBombardTowerId; }
            if (t == 15) { objectId = cDonjonId; }
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
                xsArraySetInt(gBuildingSupply, gBuildingCount, cNewBuildingSupplySeconds);
                xsArraySetInt(gBuildingLocked, gBuildingCount, 0);
                xsArraySetInt(gBuildingIsTc, gBuildingCount, 0);
                xsArraySetInt(gBuildingType, gBuildingCount, objectId);
                xsArraySetInt(gBuildingReady, gBuildingCount, 0);
                xsArraySetInt(gBuildingCover, gBuildingCount, cCoverNone);
                xsArraySetInt(gBuildingTries, gBuildingCount, 0);
                if (objectId == cTownCenterId) {
                    xsArraySetInt(gBuildingIsTc, gBuildingCount, 1);
                }
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
    hlEnsureInit();
    hlRebuildSources();
    int i = 0;
    while (i < gBuildingCount) {
        int id = xsArrayGetInt(gBuildingIds, i);
        if (xsDoesUnitExist(id) == false) {
            // Swap-remove.
            int last = gBuildingCount - 1;
            xsArraySetInt(gBuildingIds, i, xsArrayGetInt(gBuildingIds, last));
            xsArraySetInt(gBuildingSupply, i, xsArrayGetInt(gBuildingSupply, last));
            xsArraySetInt(gBuildingLocked, i, xsArrayGetInt(gBuildingLocked, last));
            xsArraySetInt(gBuildingIsTc, i, xsArrayGetInt(gBuildingIsTc, last));
            xsArraySetInt(gBuildingType, i, xsArrayGetInt(gBuildingType, last));
            xsArraySetInt(gBuildingReady, i, xsArrayGetInt(gBuildingReady, last));
            xsArraySetInt(gBuildingCover, i, xsArrayGetInt(gBuildingCover, last));
            xsArraySetInt(gBuildingTries, i, xsArrayGetInt(gBuildingTries, last));
            gBuildingCount--;
            continue;
        }
        int owner = xsGetUnitOwner(id);
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
            s = cSupplyCapSeconds;
        } else if (xsArrayGetInt(gBuildingCover, i) == cCoverTc) {
            s = 0;      // its TC was lost or ran dry: the outpost goes dark at once
        } else if (s > 0) {
            s--;
        }
        xsArraySetInt(gBuildingCover, i, cover);
        xsArraySetInt(gBuildingSupply, i, s);

        bool locked = (xsArrayGetInt(gBuildingLocked, i) == 1);
        if ((s <= 0) && (locked == false)) {
            hlSetBuildingLocked(i, true);
        } else if ((s > 0) && locked) {
            hlSetBuildingLocked(i, false);
        } else if (locked && (hlIsTowerType(xsArrayGetInt(gBuildingType, i)) == false)) {
            // Unselectable does not drop a building the player already has
            // selected (playtest 2026-10-15): its panel still queues units and
            // techs. No XS call deselects one building, so cancel (and refund)
            // anything queued every second while locked (T24 passed).
            hlCancelQueue(id);
        }
        if (hlSupplyRulesOn(owner)) {
            hlUpdateCaption(i, covered);
        }
        i++;
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
    // full ones (every covered building) never do.
    int target = -1;
    float targetDist = 9999.0;
    for (b = 0; < gBuildingCount) {
        int building = xsArrayGetInt(gBuildingIds, b);
        if (xsGetUnitOwner(building) != p) {
            continue;
        }
        float toBuilding = dist(cartPos, xsGetUnitPosition(building));
        if ((toBuilding > cCartDeliveryRange) || (toBuilding >= targetDist)) {
            continue;
        }
        if (xsArrayGetInt(gBuildingSupply, b) >= cSupplyCapSeconds) {
            continue;
        }
        target = b;
        targetDist = toBuilding;
    }
    if ((stopped == false) || (target < 0)) {
        return;
    }
    int s = xsArrayGetInt(gBuildingSupply, target) + cSupplyRefuelSeconds;
    if (s > cSupplyCapSeconds) {
        s = cSupplyCapSeconds;
    }
    xsArraySetInt(gBuildingSupply, target, s);
    // No gold here: removing the loaded cart in hlSwapCart fires its task 161
    // refund with no killer, which pays its current owner cCartGold (playtest
    // 2026-10-14: an XS refund on top paid 2x).
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
    hlEnsureInit();
    if ((cSupplyCartId < 0) || (cLoadedSupplyCartId < 0)) {
        return;
    }
    for (p = 1; < xsGetNumPlayers()) {
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

// Food upkeep: military pop x rate per second (resources are floats).
// At 0 food the starvation debuff applies to every unit (design section 5).
// TODO(slice 7): starvation debuff once the aura/debuff layer (slice 5) exists.
rule hlFoodUpkeep
    inactive
    minInterval 1
    maxInterval 1
{
    hlEnsureInit();
    for (p = 1; < xsGetNumPlayers()) {
        float cost = xsPlayerAttribute(p, cResMilitaryPop) * cFoodUpkeepPerUnitPerSecond;
        float food = xsPlayerAttribute(p, cResFood);
        if (food <= cost) {
            xsSetPlayerAttribute(p, cResFood, 0.0);
        } else {
            xsSetPlayerAttribute(p, cResFood, food - cost);
        }
    }
}
