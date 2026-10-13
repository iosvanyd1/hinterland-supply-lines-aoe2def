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

// ---- Resource IDs (UGC guide: general/resources) ----
extern const int cResFood = 0;
extern const int cResMilitaryPop = 40;

// ---- Supply window (design section 4) ----
extern const int cSupplyRefuelSeconds = 90;     // added per cart delivery
extern const int cSupplyCapSeconds = 180;       // max banked window
extern const float cCartDeliveryRange = 4.0;    // tiles from building centre

// ---- Coverage (design sections 6, 11, 13) ----
extern const float cCapitalRadius = 20.0;       // tiles
extern const float cTownCenterRadius = 12.0;    // tiles, secondary TCs

// ---- Food upkeep (design section 5) ----
extern const float cFoodUpkeepPerUnitPerSecond = 0.02;

// ---- Engine limits ----
extern const int cMaxPlayers = 9;               // index 0 = Gaia
extern const int cMaxTrackedBuildings = 400;
extern const int cMaxTrackedCarts = 200;
