// Hinterland Supply Lines - entry point.
// Loaded by the RMS (`#includeXS Hinterland\main.xs`) or by a scenario
// (Map tab > Script Filename = Hinterland\main).
//
// Status: slice 2 skeleton (single-building supply window, generalised to
// arrays). Everything marked TODO(test) depends on an in-game test listed in
// docs/research/TECHNICAL_UNKNOWNS.md.

include "Hinterland\constants.xs";

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

// Tracked forward buildings (parallel arrays, gBuildingCount used entries).
int gBuildingIds = -1;
int gBuildingSupply = -1;    // remaining seconds
int gBuildingLocked = -1;    // 0/1
int gBuildingCount = 0;

// Tracked carts (parallel arrays). gCartLoaded: 1 = carrying supply.
// gCartRoute: building the cart last delivered to; it shuttles there from the capital.
int gCartIds = -1;
int gCartLoaded = -1;
int gCartRoute = -1;
int gCartCount = 0;

// Capital TC unit ID per player (index = player ID).
int gCapitalIds = -1;

// Scratch array reused by xsGetPlayerUnitIds.
int gScratch = -1;

// One-element array for xsTaskUnits.
int gTaskIds = -1;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool hlIsForwardBuildingType(int objectId = -1) {
    if (objectId == cBarracksId) { return (true); }
    if (objectId == cArcheryRangeId) { return (true); }
    if (objectId == cStableId) { return (true); }
    if (objectId == cSiegeWorkshopId) { return (true); }
    if (objectId == cCastleId) { return (true); }
    if (objectId == cMonasteryId) { return (true); }
    if (objectId == cDockId) { return (true); }
    if (objectId == cMarketId) { return (true); }
    if (objectId == cBlacksmithId) { return (true); }
    if (objectId == cUniversityId) { return (true); }
    return (false);
}

// Debug (cDebugSupply): nearest TC seen by the last hlIsCoveredByTc call.
float gDebugDist = -1.0;      // dist() to that TC
float gDebugDistXY = -1.0;    // hand-computed x/y distance, to cross-check dist()
float gDebugRadius = -1.0;

// True if `pos` is inside the radius of any TC owned by `playerId`.
bool hlIsCoveredByTc(int playerId = -1, vector pos = vector(0, 0, 0)) {
    int tcs = xsGetPlayerUnitIds(playerId, cTownCenterId, gScratch);
    int n = xsArrayGetSize(tcs);
    int capital = xsArrayGetInt(gCapitalIds, playerId);
    bool covered = false;
    float bestMargin = 9999.0;
    for (i = 0; < n) {
        int tc = xsArrayGetInt(tcs, i);
        float radius = cTownCenterRadius;
        if (tc == capital) {
            radius = cCapitalRadius;
        }
        vector tcPos = xsGetUnitPosition(tc);
        float d = dist(tcPos, pos);
        if (d <= radius) {
            covered = true;
        }
        if (d - radius < bestMargin) {
            bestMargin = d - radius;
            float dx = xsVectorGetX(tcPos) - xsVectorGetX(pos);
            float dy = xsVectorGetY(tcPos) - xsVectorGetY(pos);
            gDebugDist = d;
            gDebugDistXY = sqrt(dx * dx + dy * dy);
            gDebugRadius = radius;
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

// Lock or unlock training and research at ONE building.
// TODO(test): no per-building API exists. Current stand-in makes the building
// unselectable (no new queue entries). Candidate replacement: swap for a
// data-mod "dark twin" with no train/research buttons. See TECHNICAL_UNKNOWNS.md U6.
void hlSetBuildingLocked(int index = -1, bool locked = false) {
    int id = xsArrayGetInt(gBuildingIds, index);
    if (locked) {
        // Out of supply cancels the queue (decision 2026-10-14, U14). Playtest
        // 2026-10-14: xsStopUnit alone did not clear it; with xsTaskUnits(Stop) added
        // the queue clears and the engine refunds. Which call does it is untested.
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

// Order one cart to walk to a unit (the capital or its route building).
void hlMoveCart(int cart = -1, int target = -1) {
    xsArraySetInt(gTaskIds, 0, cart);
    xsTaskUnits(gTaskIds, cActionTypeMove, xsGetUnitPosition(target), -1, false, false, false, -1);
}

// Covered buildings show no caption. TODO(test): unverified that an empty
// string clears the caption (xs-api.md documents only that the function exists).
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
        text = text + " [d " + gDebugDist + " xy " + gDebugDistXY + " r " + gDebugRadius + "]";
    }
    xsSetUnitCaption(id, text);
}

// Widen one TC's supply-radius circle (inert aura added by the data patch
// supply_radius.py, found by its 0 value) to cCapitalRadius.
// TODO(test T15): xsModifyUnitTasks per unit is documented but untested;
// assumes xsUnitTaskAmount loads task `i` into the xsGetTaskAmount buffer and
// that taskId is the task's index.
void hlSetCapitalAura(int tcId = -1) {
    int n = xsGetUnitTaskCount(tcId);
    for (i = 0; < n) {
        if (xsUnitTaskAmount(tcId, i) == false) {
            continue;
        }
        if (xsGetTaskAmount(cTaskAttrTaskType) != cTaskTypeAura) {
            continue;
        }
        if (xsGetTaskAmount(cTaskAttrWorkValue1) != 0.0) {
            continue;
        }
        xsTaskAmount(cTaskAttrWorkRange, cCapitalRadius);
        xsModifyUnitTasks(tcId, i, true);
        xsChatData("Hinterland: capital radius set on task " + i, i);
        return;
    }
    xsChatData("Hinterland: supply-radius aura not found on TC " + tcId + ", tasks " + n, tcId);
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
    gBuildingIds = xsArrayCreateInt(cMaxTrackedBuildings, -1, "hlBuildingIds");
    gBuildingSupply = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingSupply");
    gBuildingLocked = xsArrayCreateInt(cMaxTrackedBuildings, 0, "hlBuildingLocked");
    gCartIds = xsArrayCreateInt(cMaxTrackedCarts, -1, "hlCartIds");
    gCartLoaded = xsArrayCreateInt(cMaxTrackedCarts, 0, "hlCartLoaded");
    gCartRoute = xsArrayCreateInt(cMaxTrackedCarts, -1, "hlCartRoute");
    gCapitalIds = xsArrayCreateInt(cMaxPlayers, -1, "hlCapitalIds");
    gScratch = xsArrayCreateInt(1, -1, "hlScratch");
    gTaskIds = xsArrayCreateInt(1, -1, "hlTaskIds");
}

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

// Capital = first TC found per player until "make capital" exists (slice 3).
rule hlAssignCapitals
    active
    minInterval 2
    maxInterval 2
{
    for (p = 1; < xsGetNumPlayers()) {
        int current = xsArrayGetInt(gCapitalIds, p);
        if ((current >= 0) && xsDoesUnitExist(current)) {
            continue;
        }
        int tcs = xsGetPlayerUnitIds(p, cTownCenterId, gScratch);
        if (xsArrayGetSize(tcs) > 0) {
            xsArraySetInt(gCapitalIds, p, xsArrayGetInt(tcs, 0));
            hlSetCapitalAura(xsArrayGetInt(tcs, 0));
        }
    }
}

// Register new forward buildings. New buildings start with a full window.
rule hlRegisterBuildings
    active
    minInterval 5
    maxInterval 5
{
    int types = 10;
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
                gBuildingCount++;
            }
        }
    }
}

// Drain 1s per second outside TC coverage; refill inside; lock at 0.
rule hlSupplyTick
    active
    minInterval 1
    maxInterval 1
{
    int i = 0;
    while (i < gBuildingCount) {
        int id = xsArrayGetInt(gBuildingIds, i);
        if (xsDoesUnitExist(id) == false) {
            // Swap-remove.
            int last = gBuildingCount - 1;
            xsArraySetInt(gBuildingIds, i, xsArrayGetInt(gBuildingIds, last));
            xsArraySetInt(gBuildingSupply, i, xsArrayGetInt(gBuildingSupply, last));
            xsArraySetInt(gBuildingLocked, i, xsArrayGetInt(gBuildingLocked, last));
            gBuildingCount--;
            continue;
        }
        int owner = xsGetUnitOwner(id);
        int s = xsArrayGetInt(gBuildingSupply, i);
        bool covered = hlIsCoveredByTc(owner, xsGetUnitPosition(id));
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
        hlUpdateCaption(i, covered);
        i++;
    }
}

// Cart logistics: load at capital, deliver to the nearest forward building in range.
// Load at the capital, deliver to the nearest non-full forward building in range.
// A cart's first delivery sets its route; after that XS shuttles it between the
// capital and that building with Move orders (U5 fallback to the trade task).
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
        int capital = xsArrayGetInt(gCapitalIds, p);
        for (c = 0; < n) {
            int cart = xsArrayGetInt(carts, c);
            int ci = hlFindCart(cart);
            if (ci < 0) {
                if (gCartCount >= cMaxTrackedCarts) {
                    continue;
                }
                ci = gCartCount;
                xsArraySetInt(gCartIds, ci, cart);
                xsArraySetInt(gCartLoaded, ci, 1);   // trained at the capital = loaded
                xsArraySetInt(gCartRoute, ci, -1);
                gCartCount++;
            }
            vector cartPos = xsGetUnitPosition(cart);
            if (xsArrayGetInt(gCartLoaded, ci) == 0) {
                float toCapital = -1.0;
                if (capital >= 0) {
                    toCapital = dist(cartPos, xsGetUnitPosition(capital));
                }
                if ((capital >= 0) && (toCapital <= cCartDeliveryRange + 2.0)) {
                    xsArraySetInt(gCartLoaded, ci, 1);
                    int route = xsArrayGetInt(gCartRoute, ci);
                    if ((route >= 0) && xsDoesUnitExist(route) && (xsGetUnitOwner(route) == p)) {
                        hlMoveCart(cart, route);
                    } else {
                        xsArraySetInt(gCartRoute, ci, -1);
                    }
                }
                string emptyText = "Empty: return to capital";
                if (cDebugSupply) {
                    emptyText = emptyText + " [cap " + capital + " d " + toCapital + "]";
                }
                xsSetUnitCaption(cart, emptyText);
                continue;
            }
            string loadedText = "Loaded";
            if (cDebugSupply) {
                loadedText = loadedText + " [tracked " + gBuildingCount + "]";
            }
            xsSetUnitCaption(cart, loadedText);
            for (b = 0; < gBuildingCount) {
                int building = xsArrayGetInt(gBuildingIds, b);
                if (xsGetUnitOwner(building) != p) {
                    continue;
                }
                float toBuilding = dist(cartPos, xsGetUnitPosition(building));
                if (cDebugSupply && (toBuilding < 10.0)) {
                    xsSetUnitCaption(cart, loadedText + " [near " + building + " d " + toBuilding + "]");
                }
                if (toBuilding > cCartDeliveryRange) {
                    continue;
                }
                // Full buildings (including every TC-covered one) do not take the
                // load; otherwise carts unload into buildings next to the capital.
                if (xsArrayGetInt(gBuildingSupply, b) >= cSupplyCapSeconds) {
                    continue;
                }
                int s = xsArrayGetInt(gBuildingSupply, b) + cSupplyRefuelSeconds;
                if (s > cSupplyCapSeconds) {
                    s = cSupplyCapSeconds;
                }
                xsArraySetInt(gBuildingSupply, b, s);
                xsArraySetInt(gCartLoaded, ci, 0);
                // First delivery sets the route; the cart now shuttles like a Trade
                // Cart (design section 3). TODO(test): xsTaskUnits Move on carts.
                xsArraySetInt(gCartRoute, ci, building);
                if (capital >= 0) {
                    hlMoveCart(cart, capital);
                }
                break;
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
