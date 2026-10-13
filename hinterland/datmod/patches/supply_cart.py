"""Slice 1: custom Supply Cart unit (design section 3).

Clones the Trade Cart into every civ, trains it at the Town Center, and
enables it with Castle Age. Values are first-pass tuning, see design section 9.

Unverified (TECHNICAL_UNKNOWNS.md U4, U5): TC button slot, and whether the
trade task can target a TC. By default the trade task is removed so the cart
is a plain unit the XS handles; set EXPERIMENTAL_TRADE_TO_TC to try the
native trade-path approach.
"""
import logging

from genieutils.datfile import DatFile
from genieutils.effect import EffectCommand

from hinterland import ids as vanilla
from hinterland.datmod.util import clone

NAME = "supply-cart"

HIT_POINTS = 100
TRAIN_TIME = 40
COST_FOOD = 50
COST_WOOD = 100
TC_BUTTON_ID = 10          # unverified: must be a free slot on the TC panel
EXPERIMENTAL_TRADE_TO_TC = False

RES_FOOD = 0
RES_WOOD = 1
RES_GOLD = 3


def _configure(unit, new_id: int) -> None:
    unit.id = new_id
    unit.name = "SUPPLYCART"
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

    tasks = unit.bird.tasks
    if EXPERIMENTAL_TRADE_TO_TC:
        for task in tasks:
            if task.action_type == vanilla.ACTION_TRADE:
                task.unit_id = vanilla.TOWN_CENTER
                task.class_id = -1
        unit.bird.drop_sites = [vanilla.TOWN_CENTER]
    else:
        unit.bird.tasks = [t for t in tasks if t.action_type != vanilla.ACTION_TRADE]


def apply(data: DatFile, new_ids: dict[str, int]) -> None:
    new_id = len(data.civs[0].units)
    template = data.civs[0].units[vanilla.TRADE_CART]
    for civ in data.civs:
        source = civ.units[vanilla.TRADE_CART] or template
        cart = clone(source, data.version)
        _configure(cart, new_id)
        civ.units.append(cart)
    logging.info("Supply Cart cloned as unit %d in %d civs", new_id, len(data.civs))

    castle_age = data.techs[vanilla.CASTLE_AGE]
    data.effects[castle_age.effect_id].effect_commands.append(
        EffectCommand(type=vanilla.EFFECT_ENABLE_DISABLE_UNIT, a=new_id, b=1, c=-1, d=0.0)
    )
    new_ids["cSupplyCartId"] = new_id
