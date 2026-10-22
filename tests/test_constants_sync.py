import re

from hinterland import SRC_XS


def _xs_float(name: str) -> float:
    xs = (SRC_XS / "Hinterland" / "constants.xs").read_text(encoding="utf-8")
    m = re.search(rf"{name}\s*=\s*([\d.]+)", xs)
    assert m, f"{name} not found in constants.xs"
    return float(m.group(1))


def test_aura_radii_match_xs_supply_radii():
    from hinterland.datmod.patches import home_turf_aura as ht

    assert _xs_float("cPalaceRadius") == ht.PALACE_RADIUS
    assert _xs_float("cTownCenterRadius") == ht.TC_RADIUS


def test_cart_gold_matches_xs():
    from hinterland.datmod.patches import supply_cart

    assert _xs_float("cCartGold") == supply_cart.CART_GOLD


def _xs_int(name: str) -> int:
    xs = (SRC_XS / "Hinterland" / "constants.xs").read_text(encoding="utf-8")
    m = re.search(rf"{name}\s*=\s*(-?\d+);", xs)
    assert m, f"{name} not found in constants.xs"
    return int(m.group(1))


def test_sabotage_counter_and_base_cost_match_xs():
    from hinterland.datmod.patches import palace_techs

    assert _xs_int("cSabotageCounterRes") == palace_techs.SABOTAGE_COUNTER_RESOURCE
    sabotage = next(s for s in palace_techs.TECHS if s.key == "cSabotageTech")
    costs = dict(sabotage.costs)
    assert costs[palace_techs.RES_FOOD] == _xs_int("cSabotageBaseFood")
    assert costs[palace_techs.RES_GOLD] == _xs_int("cSabotageBaseGold")


def test_supply_cap_techs_reach_full_cap():
    assert _xs_int("cSupplyCapBasePercent") + _xs_int("cSupplyDepotsPercent") \
        + _xs_int("cMilitaryWarehousesPercent") == 100


def test_no_decimal_numbers_in_tooltips():
    """Decision 2026-10-20: no decimal numbers in any value the mod adds (round up)."""
    from hinterland import SRC_STRINGS

    strings = (SRC_STRINGS / "en" / "key-value-modded-strings-utf8.txt").read_text(encoding="utf-8")
    for line in strings.splitlines():
        if line.startswith("//"):
            continue
        assert not re.search(r"\d\.\d", line), line


def test_palace_tech_yields_are_whole_numbers():
    for name in ("cProvincialGovernorsGold", "cColonialGoldPerStep", "cDecentralizedGoldPerTc",
                 "cCentralizedGold", "cFeudalTaxationFoodPerVillager"):
        assert _xs_float(name).is_integer(), name
