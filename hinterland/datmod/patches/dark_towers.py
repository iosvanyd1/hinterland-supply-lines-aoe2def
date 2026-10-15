"""Dark towers: inactive twins that out-of-supply towers turn into (design section 4).

Playtest 2026-10-15: towers were not supply recipients, so a tower drop kept
shooting anywhere. XS now tracks towers like other buildings; when one runs out
of supply it swaps it for its dark twin (hlSwapTower) and back once resupplied.
Only Castles keep firing out of supply.

A dark twin is a clone of the tower (same look, HP, class) that cannot attack,
holds no garrison, trains nothing and is never built by villagers. It never
upgrades: XS picks the live type from the Guard Tower / Keep techs when it
swaps back.
"""
import logging

from genieutils.datfile import DatFile

from hinterland import ids as vanilla
from hinterland.datmod.util import clone, set_identity

NAME = "dark-towers"

# XS constant name -> the live tower it shadows (verified in the vanilla dat,
# October 2026: class 52, built by villagers, enabled by a tech or civ bonus).
DARK_TWINS = {
    "cDarkWatchTowerId": vanilla.WATCH_TOWER,
    "cDarkGuardTowerId": vanilla.GUARD_TOWER,
    "cDarkKeepId": vanilla.KEEP,
    "cDarkBombardTowerId": vanilla.BOMBARD_TOWER,
    "cDarkDonjonId": vanilla.DONJON,
}


def _configure(unit, new_id: int) -> None:
    set_identity(unit, new_id)
    unit.name = f"{unit.name}_DARK"[:30]
    unit.enabled = 0
    unit.garrison_capacity = 0
    unit.creatable.train_locations = []
    unit.bird.tasks = [t for t in unit.bird.tasks if t.action_type != vanilla.ACTION_ATTACK]
    for i, task in enumerate(unit.bird.tasks):
        task.id = i
    unit.bird.default_task_id = -1
    attack = unit.type_50
    attack.attacks = []
    attack.displayed_attack = 0
    attack.projectile_unit_id = -1
    attack.max_range = 0.0
    attack.displayed_range = 0.0
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
        logging.info("Dark twin of tower %d added as unit %d", live_id, new_id)
