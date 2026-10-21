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
// Civ techs that upgrade a root type in place, player-wide (effect type 3; the
// unit keeps its root identity, so XS can only tell the variant by the tech).
extern const int cFolwarkTech = 793;            // Poles: Mill 68 -> Folwark
extern const int cThalassocracyTech = 624;      // Malay: Dock 45 -> Harbor
extern const int cFortifiedChurchGeorgiansTech = 930;  // Monastery 104 -> Fortified Church
extern const int cFortifiedChurchArmeniansTech = 941;
extern const int cFortifiedOutpostTech = 1270;  // Outpost 598 -> Fortified Outpost
extern const int cEconomicSatrapyTech = 1195;   // Achaemenids: TC 109 -> 2275
extern const int cMilitarySatrapyTech = 1196;   // TC 109 -> 2277
extern const int cDefensiveSatrapyTech = 1197;  // TC 109 -> 2276

// ---- Resource IDs (UGC guide: general/resources) ----
extern const int cResFood = 0;
extern const int cResMilitaryPop = 40;

// ---- Supply window (design section 4) ----
extern const int cSupplyRefuelSeconds = 90;     // added per cart delivery
extern const int cSupplyCapSeconds = 180;       // full max banked window; players start at cSupplyCapBasePercent of it
// Map size scaling (decision 2026-10-15): refuel and cap scale with map width
// against a Medium map (168 tiles), clamped; new buildings' 20 s does not scale.
// Tiny 120 -> 71%, Normal 200 -> 119%, Giant 240 -> 142%.
extern const int cMapScaleBaseTiles = 168;
extern const int cMapScaleMinPercent = 50;
extern const int cMapScaleMaxPercent = 200;
// Per-building caps in percent of cSupplyCapSeconds (decisions 2026-10-15);
// integers, since XS warns on float-to-int.
extern const int cFortressSupplyCapPercent = 200;  // Castle, Krepost: 360 s
extern const int cDonjonSupplyCapPercent = 150;    // Donjon: 270 s
extern const int cTownCenterSupplyCapPercent = 150; // every TC: 270 s; its outpost's siege clock
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


// ---- Palace technologies (palace_techs.py; decision 2026-10-20) ----
// Incomes are per minute; hlPalaceIncome pays them out in whole units as they
// accrue (hlPayWhole), so the exact per-minute rate holds.
// Decision 2026-10-20: every gold yield halved, so the techs ease the cost of
// supply lines instead of becoming an economic engine of their own.
// Decision 2026-10-20: no decimal numbers in any value the mod adds; any one that
// would be fractional is rounded UP to the next whole number (2.5 -> 3).
extern const float cFeudalTaxationFoodPerVillager = 5.0;      // per minute
extern const float cFeudalTaxationMaxVillagers = 30.0;        // only the first 30 count (2026-10-20): max 150 food/min
extern const float cDecentralizedGoldPerTc = 10.0;            // per minute, per supplied TC outside the Palace radius
// Centralized Government, reworked 2026-10-20 toward upkeep relief: a flat
// +25 gold/min with no TC condition, and the Palace radius +6 tiles (stacks
// with Paved Roads: 20 -> 26, or 30 with both), so fewer buildings need carts.
// Decentralized counts only supplied TCs outside the Palace radius.
extern const float cCentralizedGold = 25.0;                   // per minute
extern const float cCentralizedPalaceRadiusBonus = 6.0;       // tiles
extern const float cProvincialGovernorsGold = 3.0;            // per delivery to a TC (halved 5 -> 2.5, rounded up)
// Colonial Administration: +3 gold per 20 tiles between the Palace and the TC,
// the 20 tiles scaled by map size (hlMapScaled), at most 10 steps (+30).
// Recalibrated 2026-10-20 (playtest: max gold came too close): the full +30
// now needs 200 tiles on Medium, double the old 100. Step size: Tiny 15,
// Medium 20, Giant 29 tiles. Deliveries only reach TCs outside the Palace
// radius (20 tiles), so on Medium a delivery earns at least 1 step (+3), and a
// TC 60 tiles out earns 3 (+9). Only complete steps count. The total profit
// is scaled by the supply a delivery adds and then rounded up.
extern const float cColonialGoldPerStep = 3.0;                // halved 5 -> 2.5, rounded up
extern const int cColonialStepTiles = 20;
extern const float cColonialMaxSteps = 10.0;
extern const float cPavedRoadsRadiusBonus = 4.0;              // tiles, Palace and TCs

// Max supply (decision 2026-10-20): every cap is halved by default; Supply
// Depots and Military Warehouses each add 25 points back (75%, then 100%).
extern const int cSupplyCapBasePercent = 50;
extern const int cSupplyDepotsPercent = 25;
extern const int cMilitaryWarehousesPercent = 25;
// Star Fortress: a Castle or Krepost whose TC is lost keeps this % of its max.
extern const int cStarFortressPercent = 50;
// Sabotage & Subterfuge: its tech effect adds 1 to this unused player resource
// per research (= SABOTAGE_COUNTER_RESOURCE in palace_techs.py, tested). The
// price starts at the dat cost and rises by the step after every use by anyone.
extern const int cSabotageCounterRes = 10;
extern const int cSabotageBaseFood = 500;
extern const int cSabotageBaseGold = 1000;
extern const int cSabotageStepFood = 250;
extern const int cSabotageStepGold = 500;
extern const int cSabotageMaxUses = 50;           // per player (stacking research cap)
// Diplomacy stance "enemy" from xsGetDiplomacy (UGC constants, Diplomacy: 3).
extern const int cDiplomacyEnemyId = 3;

// ---- Attrition (decision 2026-10-20) ----
// From Castle Age, non-cavalry military units outside every supply radius and
// farther than cAttritionCartRadius from their own loaded Supply Cart lose
// cAttritionPercent of their max HP every 2 s (hlAttrition): ~200 s to die for
// every unit. Exact, not rounded up: the one exception to the whole-number rule
// (decision 2026-10-20; rounding up killed 30-100 HP units 1.5-3.3x faster).
extern const float cAttritionCartRadius = 20.0;               // tiles
extern const float cAttritionPercent = 1.0;
// Unit classes as XS class IDs (900 + dat class; UGC constants, Object Class).
// Cavalry (912), cavalry archers (936), scouts (947), mounted gunpowder (923),
// heroes and the King (959) never suffer attrition; ships are not land units;
// monks carrying a relic (943) are spared too. Only 900/904/906/912 are cited
// in the KB; the rest follow the same 900 + dat class rule (unverified, T37).
extern const int cArcherClassId = 900;
extern const int cInfantryClassId = 906;
extern const int cSiegeClassId = 913;
extern const int cMonkClassId = 918;
extern const int cWarDogClassId = 928;
extern const int cPetardClassId = 935;
extern const int cHandCannoneerClassId = 944;
extern const int cPackedSiegeClassId = 951;
extern const int cUnpackedSiegeClassId = 954;
extern const int cScorpionClassId = 955;
extern const int cVillagerClassId = 904;

// ---- AI players (decision 2026-10-20) ----
// The AI cannot use the Palace or carts, so no XS rule touches computer players
// (xsGetPlayerType; UGC constants, Player Type: 3 = computer).
extern const int cPlayerTypeComputerId = 3;
// Switch: true = computer players are exempt from every mod rule (release
// default). false = the AI is treated like a human (supply, attrition, Siege &
// Starve Out, Bribe and Sabotage targets), for testing techs against it.
// Leave it true here; `python -m hinterland build --dev --ai-affected` flips it
// in the build copy only (assemble.py).
extern const bool cExemptComputerPlayers = true;

// ---- Ages (resource cAttributeCurrentAge; standard values, verify) ----
extern const int cAgeCastle = 2;                // supply rules start here (design section 3)
extern const int cAgeImperial = 3;

// ---- Food upkeep (design section 5) ----
extern const float cFoodUpkeepPerUnitPerSecond = 0.02;

// ---- Engine limits ----
extern const int cMaxPlayers = 9;               // index 0 = Gaia
extern const int cMaxTrackedBuildings = 400;
extern const int cMaxTrackedCarts = 200;
