"""Runs only when a vanilla dat is available (AOE2_INSTALL_DIR or config/paths.local.toml)."""
import pytest

from hinterland import config, ids


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    paths = config.load_game_paths()
    if not paths.vanilla_dat.exists():
        pytest.skip("vanilla dat not available")
    pytest.importorskip("genieutils")
    from hinterland.datmod.build import build_dat

    out = tmp_path_factory.mktemp("dat") / "empires2_x2_p1.dat"
    return build_dat(paths.vanilla_dat, out), out


def test_supply_cart_added_to_every_civ(built):
    from genieutils.datfile import DatFile

    new_ids, out = built
    data = DatFile.parse(out)
    cart_id = new_ids["cSupplyCartId"]
    for civ in data.civs:
        cart = civ.units[cart_id]
        assert cart.name == "SUPPLYCART"
        assert cart.creatable.train_locations[0].unit_id == ids.TOWN_CENTER


def test_castle_age_enables_cart(built):
    from genieutils.datfile import DatFile

    new_ids, out = built
    data = DatFile.parse(out)
    commands = data.effects[data.techs[ids.CASTLE_AGE].effect_id].effect_commands
    assert any(c.type == 2 and c.a == new_ids["cSupplyCartId"] and c.b == 1 for c in commands)
