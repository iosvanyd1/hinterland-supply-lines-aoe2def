import re

from hinterland import SRC_XS


def test_tc_radius_matches_xs_constant():
    from hinterland.datmod.patches import supply_radius

    xs = (SRC_XS / "Hinterland" / "constants.xs").read_text(encoding="utf-8")
    m = re.search(r"cTownCenterRadius\s*=\s*([\d.]+)", xs)
    assert m, "cTownCenterRadius not found in constants.xs"
    assert float(m.group(1)) == supply_radius.TC_SUPPLY_RADIUS
