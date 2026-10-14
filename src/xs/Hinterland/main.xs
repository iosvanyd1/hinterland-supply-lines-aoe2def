// Hinterland Supply Lines - entry point.
// Loaded by the RMS (`#includeXS Hinterland\main.xs`) or by a scenario
// (Map tab > Script Filename = Hinterland\main).
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
int gBuildingCount = 0;

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

// Debug (cDebugSupply): nearest supply source seen by the last hlIsCovered call.
float gDebugDist = -1.0;
float gDebugRadius = -1.0;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Supply rules start at Castle Age (design section 3); Dark/Feudal play as normal.
bool hlSupplyRulesOn(int playerId = -1) {
    return (xsPlayerAttribute(playerId, cAttributeCurrentAge) >= cAgeCastle);
}

void hlNoteSource(float d = 0.0, float radius = 0.0) {
    if ((gDebugDist < 0.0) || (d - radius < gDebugDist - gDebugRadius)) {
        gDebugDist = d;
        gDebugRadius = radius;
    }
}

// True if `pos` is inside the owner's Palace radius or, for anything but a TC,
// inside the radius of one of the owner's active TCs. TCs do not chain: a TC is
// active only through the Palace or its own supply (design section 11).
bool hlIsCovered(int playerId = -1, vector pos = vector(0, 0, 0), bool isTc = false) {
    gDebugDist = -1.0;
    gDebugRadius = -1.0;
    bool covered = false;
    int palace = xsArrayGetInt(gPalaceIds, playerId);
    if (palace >= 0) {
        float dp = dist(xsGetUnitPosition(palace), pos);
        hlNoteSource(dp, cPalaceRadius);
        if (dp <= cPalaceRadius) {
            covered = true;
        }
    }
    if (isTc) {
        return (covered);
    }
    for (i = 0; < gSourceCount) {
        if (xsArrayGetInt(gSourceOwner, i) != playerId) {
            continue;
        }
        float d = dist(xsArrayGetVector(gSourcePos, i), pos);
        hlNoteSource(d, cTownCenterRadius);
        if (d <= cTownCenterRadius) {
            covered = true;
        }
    }
    return (covered);
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

// Lock or unlock training and research at ONE building (TCs included).
// Unselectable = no new queue entries (U6, T7 passed). Locking also cancels the
// queue: xsTaskUnits(Stop) + xsStopUnit clears it and the engine refunds
// (U14, T8 passed 2026-10-14; which of the two calls does it is untested).
void hlSetBuildingLocked(int index = -1, bool locked = false) {
    int id = xsArrayGetInt(gBuildingIds, index);
    if (locked) {
        xsArraySetInt(gTaskIds, 0, id);
        xsTaskUnits(gTaskIds, cActionTypeStop, vector(-1, -1, -1), -1, false, false, false, -1);
        xsStopUnit(id);
        xsSetUnitProperty(id, cUnitSelectable, 0);
        xsArraySetInt(gBuildingLocked, index, 1);
    } else {
        xsSetUnitProperty(id, cUnitSelectable, 1);
        xsArraySetInt(gBuildingLocked, index, 0);
    }
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
    if (cDebugSupply) {
        text = text + " [d " + gDebugDist + " r " + gDebugRadius + "]";
    }
    xsSetUnitCaption(id, text);
}

// Active TCs this tick: inside their Palace radius, or with supply left.
// Before Castle Age every TC is active.
void hlRebuildSources() {
    gSourceCount = 0;
    for (i = 0; < gBuildingCount) {
        if (xsArrayGetInt(gBuildingIsTc, i) == 0) {
            continue;
        }
        if (xsArrayGetInt(gBuildingSupply, i) <= 0) {
            continue;
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
// Entry point
// ---------------------------------------------------------------------------

void main() {
    gBuildingIds = xsArrayCreateInt(cMaxTrackedBuildings, -1, "hlBuildingIds");
    gBuildingSupply = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingSupply");
    gBuildingLocked = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingLocked");
    gBuildingIsTc = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingIsTc");
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

// Register new supply recipients. New ones start with a full window.
rule hlRegisterBuildings
    active
    minInterval 5
    maxInterval 5
{
    int types = 11;
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
                xsArraySetInt(gBuildingSupply, gBuildingCount, cSupplyCapSeconds);
                xsArraySetInt(gBuildingLocked, gBuildingCount, 0);
                xsArraySetInt(gBuildingIsTc, gBuildingCount, 0);
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
            gBuildingCount--;
            continue;
        }
        int owner = xsGetUnitOwner(id);
        int s = xsArrayGetInt(gBuildingSupply, i);
        bool covered = true;
        if (hlSupplyRulesOn(owner)) {
            bool isTc = (xsArrayGetInt(gBuildingIsTc, i) == 1);
            covered = hlIsCovered(owner, xsGetUnitPosition(id), isTc);
        }
        if (covered) {
            s = cSupplyCapSeconds;
        } else if (s > 0) {
            s--;
        }
        xsArraySetInt(gBuildingSupply, i, s);

        bool locked = (xsArrayGetInt(gBuildingLocked, i) == 1);
        if ((s <= 0) && (locked == false)) {
            hlSetBuildingLocked(i, true);
        } else if ((s > 0) && locked) {
            hlSetBuildingLocked(i, false);
        }
        if (hlSupplyRulesOn(owner)) {
            hlUpdateCaption(i, covered);
        }
        i++;
    }
}

// Load at the Palace, deliver to the nearest non-full recipient where the cart
// stopped. A delivery sets the cart's route; XS then shuttles it between the
// Palace and that building with Move orders (U5 fallback to the trade task).
// Without a Palace, carts already loaded still deliver; they just cannot reload.
rule hlCartLogistics
    active
    minInterval 1
    maxInterval 1
{
    if (cSupplyCartId < 0) {
        return;
    }
    for (p = 1; < xsGetNumPlayers()) {
        int carts = xsGetPlayerUnitIds(p, cSupplyCartId, gScratch);
        int n = xsArrayGetSize(carts);
        int palace = xsArrayGetInt(gPalaceIds, p);
        for (c = 0; < n) {
            int cart = xsArrayGetInt(carts, c);
            int ci = hlFindCart(cart);
            if (ci < 0) {
                if (gCartCount >= cMaxTrackedCarts) {
                    continue;
                }
                ci = gCartCount;
                xsArraySetInt(gCartIds, ci, cart);
                xsArraySetInt(gCartLoaded, ci, 0);   // trained empty: load at the Palace
                xsArraySetInt(gCartRoute, ci, -1);
                xsArraySetVector(gCartLastPos, ci, vector(-1, -1, -1));
                gCartCount++;
            }
            vector cartPos = xsGetUnitPosition(cart);
            bool stopped = (dist(cartPos, xsArrayGetVector(gCartLastPos, ci)) < cCartStoppedEpsilon);
            xsArraySetVector(gCartLastPos, ci, cartPos);

            if (xsArrayGetInt(gCartLoaded, ci) == 0) {
                if (palace < 0) {
                    xsSetUnitCaption(cart, "Empty: no Palace");
                    continue;
                }
                float toPalace = dist(cartPos, xsGetUnitPosition(palace));
                if (toPalace <= cCartLoadRange) {
                    xsArraySetInt(gCartLoaded, ci, 1);
                    int route = xsArrayGetInt(gCartRoute, ci);
                    if ((route >= 0) && xsDoesUnitExist(route) && (xsGetUnitOwner(route) == p)) {
                        hlMoveCart(cart, route);
                    } else {
                        xsArraySetInt(gCartRoute, ci, -1);
                    }
                    continue;
                }
                string emptyText = "Empty: return to Palace";
                if (cDebugSupply) {
                    emptyText = emptyText + " [d " + toPalace + "]";
                }
                xsSetUnitCaption(cart, emptyText);
                continue;
            }

            string loadedText = "Loaded";
            xsSetUnitCaption(cart, loadedText);
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
                if (cDebugSupply && (toBuilding < 10.0)) {
                    xsSetUnitCaption(cart, loadedText + " [near " + building + " d " + toBuilding + "]");
                }
                if ((toBuilding > cCartDeliveryRange) || (toBuilding >= targetDist)) {
                    continue;
                }
                if (xsArrayGetInt(gBuildingSupply, b) >= cSupplyCapSeconds) {
                    continue;
                }
                target = b;
                targetDist = toBuilding;
            }
            if (stopped && (target >= 0)) {
                int s = xsArrayGetInt(gBuildingSupply, target) + cSupplyRefuelSeconds;
                if (s > cSupplyCapSeconds) {
                    s = cSupplyCapSeconds;
                }
                xsArraySetInt(gBuildingSupply, target, s);
                xsArraySetInt(gCartLoaded, ci, 0);
                xsArraySetInt(gCartRoute, ci, xsArrayGetInt(gBuildingIds, target));
                if (palace >= 0) {
                    hlMoveCart(cart, palace);
                }
            }
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
