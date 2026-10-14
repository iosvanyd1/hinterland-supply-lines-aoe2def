"""Palace: the capital building (design section 11).

Clones each civ's Wonder (so every civ's Palace looks like its own Wonder),
buildable by villagers from Feudal Age. It is the only place Supply Carts load.
One per player is enforced in XS (hlTrackPalaces), not in the data.

The Palace replaces the Wonder (decision 2026-10-14): it takes the Wonder's
build slot and the Wonder is no longer enabled, so there is no Wonder victory.

Playtest 2026-10-14: a plain Wonder clone still started the Wonder victory
countdown. The Wonder's only task is action 120 "Generate Wonder Victory"; the
Palace drops it.
Cost, HP and build time are first-pass tuning (design section 9).
"""
import logging

from genieutils.datfile import DatFile
from genieutils.effect import EffectCommand

from hinterland import ids as vanilla
from hinterland.datmod.util import clone, set_identity

NAME = "palace"

HIT_POINTS = 3000
BUILD_TIME = 120
COST_WOOD = 300
COST_STONE = 300
COST_GOLD = 200
# The Wonder's slot. Playtest 2026-10-14: slot 14 is the "more buildings" arrow
# and 1-13 are taken on both build pages, so the Palace replaces the Wonder.
BUILD_BUTTON_ID = 12

# Strings follow the vanilla unit pattern (Trade Cart: name 5100, "Build" 6100,
# help 105100 shown from string 26100). Base 5999 is free in every vanilla string
# file and unused in the dat. Texts: src/strings/en/, shipped in the strings-only
# mod. Playtest 2026-10-14: IDs in the 31 million range never showed.
STRING_NAME = 5999
STRING_CREATION = STRING_NAME + 1000
STRING_HELP = STRING_NAME + 21000          # the string the tooltip shows
HELP_ID_OFFSET = 79000                     # language_dll_help = STRING_HELP + 79000

RES_WOOD = 1
RES_STONE = 2
RES_GOLD = 3


def _configure(unit, new_id: int) -> None:
    set_identity(unit, new_id)
    unit.name = "PALACE"
    unit.language_dll_name = STRING_NAME
    unit.language_dll_creation = STRING_CREATION
    unit.language_dll_help = STRING_HELP + HELP_ID_OFFSET
    unit.hit_points = HIT_POINTS
    unit.enabled = 0                       # enabled by Feudal Age below
    unit.bird.tasks = [t for t in unit.bird.tasks if t.action_type != vanilla.ACTION_WONDER_VICTORY]
    unit.bird.default_task_id = -1

    location = unit.creatable.train_locations[0]
    location.train_time = BUILD_TIME
    location.button_id = BUILD_BUTTON_ID
    unit.creatable.train_locations = [location]

    costs = unit.creatable.resource_costs
    costs[0].type, costs[0].amount, costs[0].flag = RES_WOOD, COST_WOOD, 1
    costs[1].type, costs[1].amount, costs[1].flag = RES_STONE, COST_STONE, 1
    costs[2].type, costs[2].amount, costs[2].flag = RES_GOLD, COST_GOLD, 1


def apply(data: DatFile, new_ids: dict[str, int]) -> None:
    new_id = len(data.civs[0].units)
    template = data.civs[0].units[vanilla.WONDER]
    for civ in data.civs:
        source = civ.units[vanilla.WONDER] or template
        palace = clone(source, data.version)
        _configure(palace, new_id)
        civ.units.append(palace)
    logging.info("Palace cloned from the Wonder as unit %d in %d civs", new_id, len(data.civs))

    # No Wonder: off the build menu (slot 12 is the Palace's now) and never enabled
    # (only "Wonder Plans" enables it in vanilla).
    for civ in data.civs:
        for wonder_id in vanilla.WONDER_VARIANTS:
            wonder = civ.units[wonder_id] if wonder_id < len(civ.units) else None
            if wonder is not None and wonder.creatable is not None:
                wonder.creatable.train_locations = []
    for effect in data.effects:
        effect.effect_commands = [
            c for c in effect.effect_commands
            if not (c.type == vanilla.EFFECT_ENABLE_DISABLE_UNIT and c.a == vanilla.WONDER and c.b == 1)
        ]

    feudal_age = data.techs[vanilla.FEUDAL_AGE]
    data.effects[feudal_age.effect_id].effect_commands.append(
        EffectCommand(type=vanilla.EFFECT_ENABLE_DISABLE_UNIT, a=new_id, b=1, c=-1, d=0.0)
    )
    new_ids["cPalaceId"] = new_id
