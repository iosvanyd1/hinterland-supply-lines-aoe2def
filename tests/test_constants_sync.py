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
