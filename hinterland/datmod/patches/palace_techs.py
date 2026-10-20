"""Palace technologies (decisions 2026-10-20).

Twelve techs researched at the Palace. The data only defines them (cost, time,
button, prerequisites, strings); XS applies what they do once
`xsGetTechState` reads them as researched. Their effects are empty, except
Sabotage & Subterfuge's, which adds 1 to an unused player resource each time
it is researched so XS can count repeats.

| Tech | Age | What XS does |
|---|---|---|
| Feudal Taxation | Feudal | +5 food per villager per minute, first 30 villagers only |
| Provincial Governors | Castle | +2.5 gold per cart delivery to a TC |
| Paved Roads | Castle | Palace and TC supply radius +4 tiles |
| Decentralized Government | Castle | replaces Feudal Taxation: +10 gold per minute per supplied TC outside the Palace radius |
| Supply Depots | Castle | max supply +25 points (50% -> 75% of the base caps) |
| Colonial Administration | Imperial | +2.5 gold per 20 tiles (map-scaled) between the Palace and the TC a cart delivers to |
| Centralized Government | Imperial | replaces Decentralized Government: +25 gold per minute and Palace supply radius +6 |
| Military Warehouses | Imperial | after Supply Depots: max supply +25 points more (100%) |
| Star Fortress | Imperial | a Castle or Krepost whose TC is lost keeps 50% of its max supply |
| Siege & Starve Out | Imperial | enemy Castles and Kreposts out of supply stop firing |
| Bribe Officials | Imperial | a loaded cart stopped at an out-of-supply enemy building converts it |
| Sabotage & Subterfuge | Imperial | repeatable: kills a random enemy cart, else drains a random enemy TC; dearer after every use by anyone |

"Replaces" / "after" is an upgrade line on one button, like Wheelbarrow ->
Hand Cart: the later tech needs the earlier one.

Costs and times are first-pass tuning. Strings follow the vanilla tech pattern
(Wheelbarrow: name 7211, "Research" 8211, help 107211 shown from 28211, tech
tree 157211); every base used here is free in every vanilla string file and the
dat (checked 2026-10-20).
"""
import logging
from dataclasses import dataclass

from genieutils.datfile import DatFile
from genieutils.effect import Effect, EffectCommand

from hinterland import ids as vanilla
from hinterland.datmod.util import clone

NAME = "palace-techs"

HELP_ID_OFFSET = 79000          # language_dll_help = STRING_HELP + 79000
TECH_TREE_OFFSET = 150000       # language_dll_tech_tree = name + 150000

RES_FOOD = 0
RES_WOOD = 1
RES_STONE = 2
RES_GOLD = 3

# Sabotage & Subterfuge's use counter: player resource 10 ("Trade Production",
# unused in DE: no effect, civ start value, task or cost touches it in the
# vanilla dat). Keep equal to cSabotageCounterRes in constants.xs (tested).
SABOTAGE_COUNTER_RESOURCE = 10
EFFECT_RESOURCE_MODIFIER = 1    # effect command: a = resource, b = 1 add, d = amount


@dataclass(frozen=True)
class PalaceTech:
    key: str                    # XS constant name
    name: str
    string_name: int
    age: int                    # age tech that unlocks it
    requires: str | None        # XS key of the tech it replaces, if any (listed earlier in TECHS)
    button: int
    time: int
    costs: tuple[tuple[int, int], ...]
    icon: int                   # a vanilla tech icon
    counter_resource: int | None = None   # the effect adds 1 to it (repeatable techs)

    @property
    def string_creation(self) -> int:
        return self.string_name + 1000

    @property
    def string_help(self) -> int:
        return self.string_name + 21000


# Palace buttons: 1 is the Supply Cart; techs take the second and third rows.
TECHS = (
    PalaceTech("cFeudalTaxationTech", "Feudal Taxation", 5973, vanilla.FEUDAL_AGE, None,
               6, 60, ((RES_FOOD, 350), (RES_GOLD, 200)), 7),            # Coinage icon; dearer (rebalance 2026-10-20)
    PalaceTech("cProvincialGovernorsTech", "Provincial Governors", 5974, vanilla.CASTLE_AGE, None,
               7, 50, ((RES_FOOD, 250), (RES_GOLD, 150)), 113),          # Caravan icon
    PalaceTech("cPavedRoadsTech", "Paved Roads", 5975, vanilla.CASTLE_AGE, None,
               8, 60, ((RES_WOOD, 250), (RES_GOLD, 150)), 10),           # Husbandry icon
    PalaceTech("cDecentralizedGovernmentTech", "Decentralized Government", 5976, vanilla.CASTLE_AGE,
               "cFeudalTaxationTech", 6, 60, ((RES_FOOD, 400), (RES_GOLD, 250)), 3),     # Banking icon
    PalaceTech("cColonialAdministrationTech", "Colonial Administration", 5977, vanilla.IMPERIAL_AGE, None,
               9, 75, ((RES_FOOD, 500), (RES_GOLD, 400)), 58),           # Guilds icon
    PalaceTech("cCentralizedGovernmentTech", "Centralized Government", 5978, vanilla.IMPERIAL_AGE,
               "cDecentralizedGovernmentTech", 6, 90, ((RES_FOOD, 600), (RES_GOLD, 500)), 14),  # Architecture icon
    PalaceTech("cSupplyDepotsTech", "Supply Depots", 5979, vanilla.CASTLE_AGE, None,
               10, 50, ((RES_WOOD, 300), (RES_GOLD, 200)), 79),          # Wheelbarrow icon
    PalaceTech("cMilitaryWarehousesTech", "Military Warehouses", 5993, vanilla.IMPERIAL_AGE,
               "cSupplyDepotsTech", 10, 70, ((RES_WOOD, 500), (RES_GOLD, 350)), 42),     # Hand Cart icon
    PalaceTech("cStarFortressTech", "Star Fortress", 5994, vanilla.IMPERIAL_AGE, None,
               11, 60, ((RES_STONE, 400), (RES_GOLD, 300)), 103),        # Hoardings icon
    PalaceTech("cSiegeAndStarveTech", "Siege & Starve Out", 5995, vanilla.IMPERIAL_AGE, None,
               12, 70, ((RES_FOOD, 600), (RES_GOLD, 400)), 5),           # Sappers icon
    PalaceTech("cBribeOfficialsTech", "Bribe Officials", 5996, vanilla.IMPERIAL_AGE, None,
               13, 60, ((RES_FOOD, 300), (RES_GOLD, 600)), 109),         # Theocracy icon
    # Base cost; XS raises it for every player after each use (hlSabotage).
    PalaceTech("cSabotageTech", "Sabotage & Subterfuge", 5959, vanilla.IMPERIAL_AGE, None,
               14, 60, ((RES_FOOD, 500), (RES_GOLD, 1000)), 108,         # Heresy icon
               counter_resource=SABOTAGE_COUNTER_RESOURCE),
)


def _configure(tech, spec: PalaceTech, palace_id: int, effect_id: int, required: tuple[int, ...]) -> None:
    tech.name = spec.name
    tech.required_techs = tuple(list(required) + [-1] * (6 - len(required)))
    tech.required_tech_count = len(required)
    tech.civ = -1
    tech.full_tech_mode = 0
    tech.type = 0
    tech.effect_id = effect_id
    tech.icon_id = spec.icon
    tech.language_dll_name = spec.string_name
    tech.language_dll_description = spec.string_creation
    tech.language_dll_help = spec.string_help + HELP_ID_OFFSET
    tech.language_dll_tech_tree = spec.string_name + TECH_TREE_OFFSET
    if spec.counter_resource is not None:
        tech.repeatable = 1     # cosmetic: 1188 vanilla techs set it (Loom too); repeats come only from XS stacking (T42)
    costs = list(spec.costs) + [(-1, 0)] * (3 - len(spec.costs))
    for slot, (res, amount) in zip(tech.resource_costs, costs):
        slot.type, slot.amount, slot.flag = res, amount, 1 if res >= 0 else 0
    location = tech.research_locations[0]
    location.location_id = palace_id
    location.research_time = spec.time
    location.button_id = spec.button
    location.hot_key_id = -1
    tech.research_locations = [location]


def apply(data: DatFile, new_ids: dict[str, int]) -> None:
    palace_id = new_ids["cPalaceId"]
    template = data.techs[vanilla.COINAGE]
    for spec in TECHS:
        tech_id = len(data.techs)
        effect_id = len(data.effects)
        commands = []
        if spec.counter_resource is not None:
            commands.append(EffectCommand(type=EFFECT_RESOURCE_MODIFIER, a=spec.counter_resource,
                                          b=1, c=-1, d=1.0))
        data.effects.append(Effect(name=spec.name, effect_commands=commands))
        required = (spec.age,) if spec.requires is None else (spec.age, new_ids[spec.requires])
        tech = clone(template, data.version)
        _configure(tech, spec, palace_id, effect_id, required)
        data.techs.append(tech)
        new_ids[spec.key] = tech_id
        logging.info("Palace tech %s added as tech %d (button %d)", spec.name, tech_id, spec.button)
