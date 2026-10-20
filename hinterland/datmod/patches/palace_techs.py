"""Palace technologies (decision 2026-10-20).

Six techs researched at the Palace. The data only defines them (cost, time,
button, prerequisites, strings); each has an empty effect and XS applies what
it does once `xsGetTechState` reads it as researched:

| Tech | Age | What XS does |
|---|---|---|
| Feudal Taxation | Feudal | +5 food per villager per minute |
| Provincial Governors | Castle | +5 gold per cart delivery to a TC |
| Paved Roads | Castle | Palace and TC supply radius +4 tiles |
| Decentralized Government | Castle | replaces Feudal Taxation: +20 gold per minute per supplied TC |
| Colonial Administration | Imperial | +5 gold per 10 tiles (map-scaled) between the Palace and the TC a cart delivers to |
| Centralized Government | Imperial | replaces Decentralized Government: +150 gold per minute with at most 1 TC |

"Replaces" is an upgrade line on one button, like Wheelbarrow -> Hand Cart:
each government tech needs the previous one, and XS pays only the newest.

Costs and times are first-pass tuning. Strings follow the vanilla tech pattern
(Wheelbarrow: name 7211, "Research" 8211, help 107211 shown from 28211, tech
tree 157211); bases 5973-5978 are free in every vanilla string file and the dat.
"""
import logging
from dataclasses import dataclass

from genieutils.datfile import DatFile
from genieutils.effect import Effect

from hinterland import ids as vanilla
from hinterland.datmod.util import clone

NAME = "palace-techs"

HELP_ID_OFFSET = 79000          # language_dll_help = STRING_HELP + 79000
TECH_TREE_OFFSET = 150000       # language_dll_tech_tree = name + 150000

RES_FOOD = 0
RES_WOOD = 1
RES_GOLD = 3


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

    @property
    def string_creation(self) -> int:
        return self.string_name + 1000

    @property
    def string_help(self) -> int:
        return self.string_name + 21000


# Palace buttons: 1 is the Supply Cart; the techs take the second row.
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
        data.effects.append(Effect(name=spec.name, effect_commands=[]))   # XS applies it
        required = (spec.age,) if spec.requires is None else (spec.age, new_ids[spec.requires])
        tech = clone(template, data.version)
        _configure(tech, spec, palace_id, effect_id, required)
        data.techs.append(tech)
        new_ids[spec.key] = tech_id
        logging.info("Palace tech %s added as tech %d (button %d)", spec.name, tech_id, spec.button)
