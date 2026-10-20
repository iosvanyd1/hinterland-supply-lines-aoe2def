"""Dark buildings: inactive twins that out-of-supply shooting buildings turn into
(design section 4).

Playtest 2026-10-15: towers were not supply recipients, so a tower drop kept
shooting anywhere. XS tracks towers like other buildings; when one runs out of
supply it swaps it for its dark twin (hlSwapBuilding) and back once resupplied
(T23 passed). Decision 2026-10-15: Town Centers, the Krepost, Harbor, Fortified
Church and Fortified Outposts go dark the same way. Castles and Kreposts keep firing
out of supply until an enemy researches Siege & Starve (decision 2026-10-20).
Decision 2026-10-15: gathering needs supply too, so drop sites
(Dock, Mill, Lumber Camp, Mining Camp and their civ variants, Mule Cart) go
dark: villagers cannot drop resources at a dark twin (playtest 2026-10-15,
dark TC), since drop-site lists name the base ID.

A dark twin is a clone of the building (same look, HP, class, pop space) that
cannot attack, projects no aura, holds no garrison, trains and researches
nothing and is never built by villagers. It never upgrades: XS works out the
live type to swap back to (towers from the Guard Tower / Keep techs, TCs and
drop sites from the age).
"""
import logging

from genieutils.datfile import DatFile

from hinterland import ids as vanilla
from hinterland.datmod.util import clone, set_identity

NAME = "dark-buildings"

AURA_ENABLED_BIT = 32      # Combat Ability bit that switches auras on

# XS constant name -> the live building it shadows (vanilla dat, October 2026).
# TCs: only the Castle and Imperial variants, since supply rules start in
# Castle Age; 2275-2277 replace TC 109 for good once chosen.
DARK_TWINS = {
    "cDarkWatchTowerId": vanilla.WATCH_TOWER,
    "cDarkGuardTowerId": vanilla.GUARD_TOWER,
    "cDarkKeepId": vanilla.KEEP,
    "cDarkBombardTowerId": vanilla.BOMBARD_TOWER,
    "cDarkDonjonId": vanilla.DONJON,
    "cDarkTownCenterCastleId": vanilla.TOWN_CENTER_CASTLE,
    "cDarkTownCenterImperialId": vanilla.TOWN_CENTER_IMPERIAL,
    "cDarkEconomicTownCenterId": vanilla.ECONOMIC_TOWN_CENTER,
    "cDarkDefensiveTownCenterId": vanilla.DEFENSIVE_TOWN_CENTER,
    "cDarkMilitaryTownCenterId": vanilla.MILITARY_TOWN_CENTER,
    "cDarkKrepostId": vanilla.KREPOST,
    # Castles (and, since 2026-10-20, Kreposts) go dark only once an enemy has
    # researched Siege & Starve; XS decides when (hlDarkableType).
    "cDarkCastleId": vanilla.CASTLE,
    "cDarkHarborId": vanilla.HARBOR,
    "cDarkFortifiedChurchId": vanilla.FORTIFIED_CHURCH,
    "cDarkFortifiedOutpostId": vanilla.FORTIFIED_OUTPOST,
    "cDarkFortifiedOutpost2Id": vanilla.FORTIFIED_OUTPOST_2,
    # Drop sites: a dark one takes no drop-offs. Castle and Imperial variants only.
    "cDarkDockCastleId": vanilla.DOCK_CHAIN[2],
    "cDarkDockImperialId": vanilla.DOCK_CHAIN[3],
    "cDarkMillCastleId": vanilla.MILL_CHAIN[2],
    "cDarkMillImperialId": vanilla.MILL_CHAIN[3],
    "cDarkLumberCampCastleId": vanilla.LUMBER_CAMP_CHAIN[2],
    "cDarkLumberCampImperialId": vanilla.LUMBER_CAMP_CHAIN[3],
    "cDarkMiningCampCastleId": vanilla.MINING_CAMP_CHAIN[2],
    "cDarkMiningCampImperialId": vanilla.MINING_CAMP_CHAIN[3],
    "cDarkShipyardCastleId": vanilla.SHIPYARD_CHAIN[2],
    "cDarkShipyardImperialId": vanilla.SHIPYARD_CHAIN[3],
    "cDarkPortCastleId": vanilla.PORT_CHAIN[2],
    "cDarkPortImperialId": vanilla.PORT_CHAIN[3],
    "cDarkFolwarkId": vanilla.FOLWARK_CHAIN[2],
    "cDarkSettlementId": vanilla.SETTLEMENT_CHAIN[2],
    "cDarkMuleCartId": vanilla.MULE_CART,
}

DROPPED_ACTIONS = (vanilla.ACTION_ATTACK, vanilla.ACTION_AURA)


def _configure(unit, new_id: int) -> None:
    set_identity(unit, new_id)
    unit.name = f"{unit.name}_DARK"[:30]
    unit.enabled = 0
    unit.garrison_capacity = 0
    unit.creatable.train_locations = []
    unit.bird.tasks = [t for t in unit.bird.tasks if t.action_type not in DROPPED_ACTIONS]
    for i, task in enumerate(unit.bird.tasks):
        task.id = i
    unit.bird.default_task_id = -1
    attack = unit.type_50
    attack.attacks = []
    attack.displayed_attack = 0
    attack.projectile_unit_id = -1
    attack.max_range = 0.0
    attack.displayed_range = 0.0
    attack.break_off_combat &= ~AURA_ENABLED_BIT
    unit.creatable.secondary_projectile_unit = -1
    unit.creatable.total_projectiles = 0.0
    unit.creatable.max_total_projectiles = 0


def apply(data: DatFile, new_ids: dict[str, int]) -> None:
    for key, live_id in DARK_TWINS.items():
        new_id = len(data.civs[0].units)
        template = data.civs[0].units[live_id]
        for civ in data.civs:
            source = civ.units[live_id] or template
            dark = clone(source, data.version)
            _configure(dark, new_id)
            civ.units.append(dark)
        new_ids[key] = new_id
        logging.info("Dark twin of building %d added as unit %d", live_id, new_id)
