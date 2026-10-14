"""Slice 2 UI: show the TC supply radius as a native aura range circle.

Adds an inert aura task (task 155) to the Town Center. DE draws a range
indicator for auras whose combat_level_flag has the "visible" bit (4); the
circle's radius is the task's work_range (UGC guide, tasks page "155. Aura").
The aura itself does nothing: +0 HP regen to class 19 (carts).

The radius here is the secondary-TC radius. XS widens it on the capital at
runtime (hlSetCapitalAura in main.xs).

Unverified (TECHNICAL_UNKNOWNS.md U9, test T15): whether the circle shows only
while selected (depends on Options > Game > "Building and Aura range
indicator"), whether enemies see it, and whether an inert aura still draws.
"""
import logging

from genieutils.datfile import DatFile

from hinterland import ids as vanilla
from hinterland.datmod.util import clone

NAME = "supply-radius"

# Keep equal to cTownCenterRadius in src/xs/Hinterland/constants.xs (tested).
TC_SUPPLY_RADIUS = 12.0

FLAG_CIRCULAR = 2
FLAG_VISIBLE = 4             # "shows range indicator (is affected by ui settings)"
ATTR_HP_REGEN = 109          # aura attribute, stored in search_wait_time
AURA_VALUE = 0.0             # inert; XS finds the task by this value
DIPLOMACY_SELF_AND_ALLIES = 1


def apply(data: DatFile, new_ids: dict[str, int]) -> None:
    del new_ids  # adds no new object IDs
    count = 0
    for civ in data.civs:
        tc = civ.units[vanilla.TOWN_CENTER]
        if tc is None:
            continue
        tasks = tc.bird.tasks
        template = next(t for t in tasks if t.action_type == vanilla.ACTION_AURA)
        aura = clone(template, data.version)
        aura.id = len(tasks)
        aura.class_id = vanilla.CLASS_TRADE_CART
        aura.unit_id = -1
        aura.work_value_1 = AURA_VALUE
        aura.work_value_2 = 1.0
        aura.work_range = TC_SUPPLY_RADIUS
        aura.search_wait_time = float(ATTR_HP_REGEN)
        aura.combat_level_flag = FLAG_CIRCULAR | FLAG_VISIBLE
        aura.target_diplomacy = DIPLOMACY_SELF_AND_ALLIES
        aura.carry_check = 0
        tasks.append(aura)
        count += 1
    logging.info("Supply radius aura (%.0f tiles) added to the TC in %d civs", TC_SUPPLY_RADIUS, count)
