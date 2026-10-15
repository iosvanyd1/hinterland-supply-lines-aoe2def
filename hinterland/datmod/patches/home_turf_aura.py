"""Home-turf aura on the Palace and every TC (design section 13, 2026-10-14).

Friendly military units inside a Palace (20 tiles) or TC (12 tiles) radius get
+1 melee / +1 pierce armor and +10% speed. There is no penalty anywhere.

- Auras run only while bit 32 of Combat Ability is set (UGC XS tricks, "Adding
  auras"). In genieutils, Combat Ability is `type_50.break_off_combat`
  (vanilla aura units: Caravanserai 34, Centurion 32), not `combat_level`.
- Palace: on as soon as it stands (buildable from Feudal Age).
- TCs: age-ups replace the TC's data (109 Dark -> 71 Feudal -> 141 Castle ->
  142 Imperial), so all four variants carry the aura tasks; only the Castle and
  Imperial variants have bit 32, so TC auras start with the Castle Age upgrade.
  The TCs' dormant vanilla regen auras are removed (bit 32 would wake them).
- Aura attributes 116/117 are melee/pierce armor (verified in game, T19).
- A TC that ran out of supply keeps its aura (home turf is about standing).
Ships, villagers, trade units and carts are not military classes here.
"""
import logging

from genieutils.datfile import DatFile

from hinterland import ids as vanilla
from hinterland.datmod.util import clone

NAME = "home-turf-aura"

# Keep equal to cPalaceRadius / cTownCenterRadius in constants.xs (tested).
PALACE_RADIUS = 20.0
TC_RADIUS = 12.0

SPEED_BONUS = 1.10              # +10% speed
ARMOR_BONUS = 1                 # +1 melee, +1 pierce

ATTR_SPEED = 5
AURA_ATTR_MELEE_ARMOR = 116
AURA_ATTR_PIERCE_ARMOR = 117

AURA_MULTIPLY = 1
AURA_CIRCULAR = 2
AURA_ENABLED_BIT = 32           # Combat Ability bit that switches auras on
DIPLOMACY_FRIENDLY = 4          # gaia, you and allies

TC_VARIANTS = (vanilla.TOWN_CENTER, vanilla.TOWN_CENTER_FEUDAL,
               vanilla.TOWN_CENTER_CASTLE, vanilla.TOWN_CENTER_IMPERIAL)
TC_VARIANTS_WITH_AURA_ON = (vanilla.TOWN_CENTER_CASTLE, vanilla.TOWN_CENTER_IMPERIAL)


def _aura(template, version: str, class_id: int, attribute: int, value: float,
          flags: int, radius: float):
    task = clone(template, version)
    task.task_type = 1
    task.action_type = vanilla.ACTION_AURA
    task.is_default = 0
    task.class_id = class_id
    task.unit_id = -1
    task.work_value_1 = value
    task.work_value_2 = 1.0           # one unit in range turns it on
    task.work_range = radius
    task.search_wait_time = float(attribute)
    task.combat_level_flag = flags
    task.target_diplomacy = DIPLOMACY_FRIENDLY
    task.carry_check = 0
    task.gather_type = 0
    task.enabled = -1
    return task


def _add_home_turf(unit, template, radius: float, version: str, on: bool) -> None:
    unit.bird.tasks = [t for t in unit.bird.tasks if t.action_type != vanilla.ACTION_AURA]
    for class_id in vanilla.MILITARY_CLASSES:
        unit.bird.tasks.append(_aura(template, version, class_id, ATTR_SPEED,
                                     SPEED_BONUS, AURA_MULTIPLY | AURA_CIRCULAR, radius))
        for attribute in (AURA_ATTR_MELEE_ARMOR, AURA_ATTR_PIERCE_ARMOR):
            unit.bird.tasks.append(_aura(template, version, class_id, attribute,
                                         float(ARMOR_BONUS), AURA_CIRCULAR, radius))
    for i, task in enumerate(unit.bird.tasks):
        task.id = i
    if on:
        unit.type_50.break_off_combat |= AURA_ENABLED_BIT


def apply(data: DatFile, new_ids: dict[str, int]) -> None:
    palace_id = new_ids["cPalaceId"]
    # A vanilla aura task as template: the TC's dormant regen aura.
    template = clone(next(
        t for t in data.civs[0].units[vanilla.TOWN_CENTER].bird.tasks
        if t.action_type == vanilla.ACTION_AURA
    ), data.version)
    for civ in data.civs:
        palace = civ.units[palace_id]
        if palace is not None:
            _add_home_turf(palace, template, PALACE_RADIUS, data.version, on=True)
        for tc_id in TC_VARIANTS:
            tc = civ.units[tc_id]
            if tc is not None:
                _add_home_turf(tc, template, TC_RADIUS, data.version,
                               on=tc_id in TC_VARIANTS_WITH_AURA_ON)
    logging.info(
        "Home-turf aura (+%d/+%d armor, x%.2f speed, %d military classes): Palace %.0f tiles, "
        "TCs %.0f tiles from Castle Age",
        ARMOR_BONUS, ARMOR_BONUS, SPEED_BONUS, len(vanilla.MILITARY_CLASSES), PALACE_RADIUS, TC_RADIUS,
    )
