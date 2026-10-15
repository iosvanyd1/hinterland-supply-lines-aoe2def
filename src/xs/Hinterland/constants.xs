// Hinterland Supply Lines - tuning constants and vanilla IDs.
// Vanilla IDs marked "verify" must be checked against the current .dat
// (Advanced Genie Editor) after every game patch.

include "Hinterland\generated_ids.xs";

// ---- Vanilla object IDs (verify) ----
extern const int cTownCenterId = 109;
extern const int cBarracksId = 12;
extern const int cArcheryRangeId = 87;
extern const int cStableId = 101;
extern const int cSiegeWorkshopId = 49;
extern const int cCastleId = 82;
extern const int cMonasteryId = 104;
extern const int cDockId = 45;
extern const int cMarketId = 84;
extern const int cBlacksmithId = 103;
extern const int cUniversityId = 209;
// Towers (class 52; vanilla dat October 2026). Guard Tower (tech 140) upgrades
// 79 -> 234, Keep (tech 63) upgrades 79 and 234 -> 235, in place.
extern const int cWatchTowerId = 79;
extern const int cGuardTowerId = 234;
extern const int cKeepId = 235;
extern const int cBombardTowerId = 236;
extern const int cDonjonId = 1665;
extern const int cGuardTowerTech = 140;
extern const int cKeepTech = 63;

// ---- Resource IDs (UGC guide: general/resources) ----
extern const int cResFood = 0;
extern const int cResMilitaryPop = 40;

// ---- Supply window (design section 4) ----
extern const int cSupplyRefuelSeconds = 90;     // added per cart delivery
extern const int cSupplyCapSeconds = 180;       // max banked window
extern const int cNewBuildingSupplySeconds = 20; // a new building's window, so it needs carts at once
extern const float cCartDeliveryRange = 4.0;    // tiles from building centre
extern const float cCartLoadRange = 6.5;        // tiles from the Palace centre (5x5 footprint)
extern const int cCartGold = 50;                 // taken at loading, returned on delivery, a raider's prize; = CART_GOLD in supply_cart.py (tested)
extern const float cCartStoppedEpsilon = 0.05;  // tiles moved per second below which a cart counts as stopped
extern const int cTowerUngarrisonTicks = 3;     // seconds a dry tower tries to empty itself before it goes dark anyway

// ---- Debug ----
// Shows distance and radius to the nearest supply source in captions. Turn off before release.
extern const bool cDebugSupply = false;

// ---- Coverage (design sections 6, 11, 13) ----
// Keep equal to PALACE_RADIUS / TC_RADIUS in home_turf_aura.py (tested).
extern const float cPalaceRadius = 20.0;        // tiles
extern const float cTownCenterRadius = 12.0;    // tiles, every TC


// ---- Ages (resource cAttributeCurrentAge; standard values, verify) ----
extern const int cAgeCastle = 2;                // supply rules start here (design section 3)

// ---- Food upkeep (design section 5) ----
extern const float cFoodUpkeepPerUnitPerSecond = 0.02;

// ---- Engine limits ----
extern const int cMaxPlayers = 9;               // index 0 = Gaia
extern const int cMaxTrackedBuildings = 400;
extern const int cMaxTrackedCarts = 200;
