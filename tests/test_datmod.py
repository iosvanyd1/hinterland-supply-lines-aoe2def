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


def test_tc_has_visible_supply_radius_aura(built):
    from genieutils.datfile import DatFile

    from hinterland.datmod.patches import supply_radius

    _, out = built
    data = DatFile.parse(out)
    for civ in data.civs:
        tc = civ.units[ids.TOWN_CENTER]
        if tc is None:
            continue
        auras = [
            t for t in tc.bird.tasks
            if t.action_type == ids.ACTION_AURA and t.work_value_1 == supply_radius.AURA_VALUE
        ]
        assert len(auras) == 1
        assert auras[0].work_range == supply_radius.TC_SUPPLY_RADIUS
        assert auras[0].combat_level_flag & supply_radius.FLAG_VISIBLE
        assert auras[0].id == tc.bird.tasks.index(auras[0])


def test_supply_cart_strings_and_look(built):
    from genieutils.datfile import DatFile

    from hinterland import assemble
    from hinterland.datmod.patches import supply_cart

    new_ids, out = built
    data = DatFile.parse(out)
    civ = data.civs[1]
    cart = civ.units[new_ids["cSupplyCartId"]]
    assert cart.standing_graphic == civ.units[supply_cart.LOOK_UNIT].standing_graphic
    assert cart.language_dll_name == supply_cart.STRING_NAME

    strings = (assemble.SRC_STRINGS / "en" / "key-value-modded-strings-utf8.txt").read_text(encoding="utf-8")
    for sid in (supply_cart.STRING_NAME, supply_cart.STRING_CREATION, supply_cart.STRING_HELP):
        assert f"\n{sid} " in strings
