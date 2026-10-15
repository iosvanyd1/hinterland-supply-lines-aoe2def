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
// Other shooting buildings that go dark out of supply (decision 2026-10-15).
// Upgrades in place: Dock -> Harbor, Monastery -> Fortified Church, Outpost ->
// Fortified Outpost, TC 109 -> Economic / Defensive / Military TC, and the
// age-ups TC 141 (Castle) -> 142 (Imperial).
extern const int cTownCenterCastleId = 141;
extern const int cTownCenterImperialId = 142;
extern const int cEconomicTownCenterId = 2275;
extern const int cDefensiveTownCenterId = 2276;
extern const int cMilitaryTownCenterId = 2277;
extern const int cKrepostId = 1251;
extern const int cHarborId = 1189;
extern const int cFortifiedChurchId = 1806;
extern const int cFortifiedOutpostId = 2415;
extern const int cFortifiedOutpost2Id = 2417;
// Drop sites (decision 2026-10-15: gathering needs supply). Age-ups upgrade
// them in place: Dark, Feudal, Castle, Imperial variant. Folwark and Settlement
// have their own Feudal/Castle upgrade techs and no Imperial variant.
extern const int cMillId = 68;
extern const int cMillFeudalId = 129;
extern const int cMillCastleId = 130;
extern const int cMillImperialId = 131;
extern const int cLumberCampId = 562;
extern const int cLumberCampFeudalId = 563;
extern const int cLumberCampCastleId = 564;
extern const int cLumberCampImperialId = 565;
extern const int cMiningCampId = 584;
extern const int cMiningCampFeudalId = 585;
extern const int cMiningCampCastleId = 586;
extern const int cMiningCampImperialId = 587;
extern const int cDockFeudalId = 133;
extern const int cDockCastleId = 47;
extern const int cDockImperialId = 51;
extern const int cShipyardId = 2119;
extern const int cShipyardCastleId = 2117;
extern const int cShipyardImperialId = 2118;
extern const int cPortId = 2172;
extern const int cPortFeudalId = 2143;
extern const int cPortCastleId = 2142;
extern const int cPortImperialId = 2141;
extern const int cFolwarkId = 1734;
extern const int cFolwarkFeudalId = 1711;
extern const int cFolwarkCastleId = 1720;
extern const int cSettlementId = 2556;
extern const int cSettlementFeudalId = 2558;
extern const int cSettlementCastleId = 2560;
extern const int cMuleCartId = 1808;
extern const int cTownCenterFeudalId = 71;
extern const int cMonasteryFeudalId = 30;       // 104 -> 30 -> 31 -> 32 by age
extern const int cMonasteryCastleId = 31;
extern const int cMonasteryImperialId = 32;
extern const int cOutpostId = 598;              // -> Fortified Outpost 2415 by tech

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
extern const int cDarkUngarrisonTicks = 3;      // seconds a dry building tries to empty itself before it goes dark anyway

// ---- Debug ----
// Shows distance and radius to the nearest supply source in captions. Turn off before release.
extern const bool cDebugSupply = false;

// ---- Coverage (design sections 6, 11, 13) ----
// Keep equal to PALACE_RADIUS / TC_RADIUS in home_turf_aura.py (tested).
extern const float cPalaceRadius = 20.0;        // tiles
extern const float cTownCenterRadius = 12.0;    // tiles, every TC


// ---- Ages (resource cAttributeCurrentAge; standard values, verify) ----
extern const int cAgeCastle = 2;                // supply rules start here (design section 3)
extern const int cAgeImperial = 3;

// ---- Food upkeep (design section 5) ----
extern const float cFoodUpkeepPerUnitPerSecond = 0.02;

// ---- Engine limits ----
extern const int cMaxPlayers = 9;               // index 0 = Gaia
extern const int cMaxTrackedBuildings = 400;
extern const int cMaxTrackedCarts = 200;
