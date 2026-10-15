"""Slice 1: custom Supply Cart unit (design section 3).

Clones the Trade Cart into every civ, trains it at the Town Center, and
enables it with Castle Age. Values are first-pass tuning, see design section 9.

Looks like the vanilla Ox Cart. A second unit, the Loaded Supply Cart, looks
like the Ox Wagon; XS swaps a cart to it when it loads at the Palace and back
when it delivers (playtest 2026-10-14: a carrying graphic on a trade task never
showed, since XS moves carts with Move orders). Neither has a trade task.
XS routes the carts (U5).

Raiding (slice 6, decision 2026-10-14): a loading cart takes CART_GOLD from its
owner (XS). The Loaded Supply Cart carries task 161 "Unit refund" with work
range > 0: whoever kills a loaded cart gets CART_GOLD gold. When XS removes the
loaded cart at delivery (the swap), the refund fires with no killer and pays the
cart's current owner (playtest 2026-10-14), which returns the gold. Empty carts
are worth nothing. Unverified (T22): Heresy deaths.
"""
import logging

from genieutils.datfile import DatFile
from genieutils.effect import EffectCommand

from hinterland import ids as vanilla
from hinterland.datmod.util import clone, set_identity

NAME = "supply-cart"

HIT_POINTS = 100
TRAIN_TIME = 40
COST_FOOD = 50
COST_WOOD = 100
TC_BUTTON_ID = 10          # unverified: must be a free slot on the TC panel

# Look: the vanilla Ox Cart, so the Supply Cart is not mistaken for a Trade Cart.
LOOK_UNIT = 1271           # OXCART (idle/walk/death graphics, icon 263)
LOOK_CORPSE = 1272         # OXCART_D
LOADED_LOOK_UNIT = 1273    # OXWAGON: the Loaded Supply Cart's look
LOADED_LOOK_CORPSE = 1274  # OXWAGON_D
LOADED_STRING_NAME = 5997  # "Supply Cart (Loaded)"; free in vanilla strings and dat

# Gold a loaded cart carries; keep equal to cCartGold in constants.xs (tested).
CART_GOLD = 50
ACTION_UNIT_REFUND = 161   # task: resource granted on death

# Strings: same vanilla pattern and reasoning as palace.py; base 5998.
STRING_NAME = 5998
STRING_CREATION = STRING_NAME + 1000
STRING_HELP = STRING_NAME + 21000          # the string the tooltip shows
HELP_ID_OFFSET = 79000                     # language_dll_help = STRING_HELP + 79000

RES_FOOD = 0
RES_WOOD = 1
RES_GOLD = 3


def _apply_look(unit, look, corpse: int) -> None:
    unit.standing_graphic = look.standing_graphic
    unit.dying_graphic = look.dying_graphic
    unit.dead_fish.walking_graphic = look.dead_fish.walking_graphic
    unit.icon_id = look.icon_id
    unit.dead_unit_id = corpse


def _raid_refund_task(template, version: str):
    """Task 161: CART_GOLD gold to the player who kills the unit (UGC tasks page)."""
    task = clone(template, version)
    task.task_type = 1
    task.action_type = ACTION_UNIT_REFUND
    task.is_default = 0
    task.class_id = -1
    task.unit_id = -1
    task.work_value_1 = float(CART_GOLD)   # flat amount
    task.work_value_2 = 0.0
    task.work_range = 1.0                  # > 0: grant to the killer, not the owner
    task.combat_level_flag = 0             # 0: Work Value 1 is flat, not a cost fraction
    task.resource_multiplier = -1          # productivity resource: none
    task.resource_in = -1
    task.resource_out = RES_GOLD
    task.enabled = -1
    return task


def _configure_loaded(unit, new_id: int, version: str) -> None:
    """The Loaded Supply Cart: same stats, Ox Wagon look, never trained, raid gold."""
    set_identity(unit, new_id)
    unit.name = "SUPPLYCART_LOADED"
    unit.language_dll_name = LOADED_STRING_NAME
    unit.creatable.train_locations = []
    unit.bird.tasks.append(_raid_refund_task(unit.bird.tasks[0], version))
    for i, task in enumerate(unit.bird.tasks):
        task.id = i


def _configure(unit, new_id: int) -> None:
    set_identity(unit, new_id)
    unit.name = "SUPPLYCART"
    unit.language_dll_name = STRING_NAME
    unit.language_dll_creation = STRING_CREATION
    unit.language_dll_help = STRING_HELP + HELP_ID_OFFSET
    unit.hit_points = HIT_POINTS
    unit.enabled = 0                       # enabled by Castle Age below

    creatable = unit.creatable
    location = creatable.train_locations[0]
    location.unit_id = vanilla.TOWN_CENTER
    location.train_time = TRAIN_TIME
    location.button_id = TC_BUTTON_ID
    creatable.train_locations = [location]

    costs = creatable.resource_costs
    costs[0].type, costs[0].amount, costs[0].flag = RES_FOOD, COST_FOOD, 1
    costs[1].type, costs[1].amount, costs[1].flag = RES_WOOD, COST_WOOD, 1
    costs[2].type, costs[2].amount, costs[2].flag = -1, 0, 0

    unit.bird.tasks = [t for t in unit.bird.tasks if t.action_type != vanilla.ACTION_TRADE]
    for i, task in enumerate(unit.bird.tasks):
        task.id = i


def apply(data: DatFile, new_ids: dict[str, int]) -> None:
    new_id = len(data.civs[0].units)
    loaded_id = new_id + 1
    template = data.civs[0].units[vanilla.TRADE_CART]
    for civ in data.civs:
        source = civ.units[vanilla.TRADE_CART] or template
        cart = clone(source, data.version)
        _configure(cart, new_id)
        _apply_look(cart, civ.units[LOOK_UNIT] or data.civs[0].units[LOOK_UNIT], LOOK_CORPSE)
        loaded = clone(cart, data.version)
        _configure_loaded(loaded, loaded_id, data.version)
        _apply_look(
            loaded, civ.units[LOADED_LOOK_UNIT] or data.civs[0].units[LOADED_LOOK_UNIT], LOADED_LOOK_CORPSE
        )
        civ.units.append(cart)
        civ.units.append(loaded)
    logging.info("Supply Cart cloned as units %d (empty) and %d (loaded) in %d civs",
                 new_id, loaded_id, len(data.civs))

    castle_age = data.techs[vanilla.CASTLE_AGE]
    data.effects[castle_age.effect_id].effect_commands.append(
        EffectCommand(type=vanilla.EFFECT_ENABLE_DISABLE_UNIT, a=new_id, b=1, c=-1, d=0.0)
    )
    new_ids["cSupplyCartId"] = new_id
    new_ids["cLoadedSupplyCartId"] = loaded_id
