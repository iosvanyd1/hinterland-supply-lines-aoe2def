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
    assert f"\n{supply_cart.STRING_HELP} " in strings


def test_palace_cloned_from_wonder_and_enabled_in_feudal(built):
    from genieutils.datfile import DatFile

    from hinterland.datmod.patches import palace

    new_ids, out = built
    data = DatFile.parse(out)
    palace_id = new_ids["cPalaceId"]
    assert palace_id != new_ids["cSupplyCartId"]
    for civ in data.civs:
        unit = civ.units[palace_id]
        assert unit.name == "PALACE"
        assert unit.standing_graphic == civ.units[ids.WONDER].standing_graphic
        assert unit.creatable.train_locations[0].button_id == palace.BUILD_BUTTON_ID
    commands = data.effects[data.techs[ids.FEUDAL_AGE].effect_id].effect_commands
    assert any(c.type == 2 and c.a == palace_id and c.b == 1 for c in commands)

    from hinterland import SRC_STRINGS

    strings = (SRC_STRINGS / "en" / "key-value-modded-strings-utf8.txt").read_text(encoding="utf-8")
    assert f"\n{palace.STRING_HELP} " in strings
    for civ in data.civs:
        unit = civ.units[palace_id]
        assert all(t.action_type != ids.ACTION_WONDER_VICTORY for t in unit.bird.tasks)
        assert unit.bird.default_task_id == -1
        for wonder_id in ids.WONDER_VARIANTS:
            assert civ.units[wonder_id].creatable.train_locations == []


def test_wonder_is_never_enabled(built):
    from genieutils.datfile import DatFile

    _, out = built
    data = DatFile.parse(out)
    for effect in data.effects:
        for c in effect.effect_commands:
            assert not (c.type == 2 and c.a == ids.WONDER and c.b == 1), effect.name


def test_clones_are_their_own_base_unit(built):
    from genieutils.datfile import DatFile

    new_ids, out = built
    data = DatFile.parse(out)
    for key in ("cSupplyCartId", "cLoadedSupplyCartId", "cPalaceId"):
        uid = new_ids[key]
        for civ in data.civs:
            unit = civ.units[uid]
            assert (unit.id, unit.copy_id, unit.base_id) == (uid, uid, uid), key


def test_string_ids_follow_vanilla_pattern_and_exist():
    from hinterland import SRC_STRINGS
    from hinterland.datmod.patches import palace, supply_cart

    strings = (SRC_STRINGS / "en" / "key-value-modded-strings-utf8.txt").read_text(encoding="utf-8")
    for patch in (palace, supply_cart):
        assert patch.STRING_NAME < 100000
        for sid in (patch.STRING_NAME, patch.STRING_CREATION, patch.STRING_HELP):
            assert f"\n{sid} " in strings


def test_loaded_cart_is_ox_wagon_and_never_trained(built):
    from genieutils.datfile import DatFile

    from hinterland.datmod.patches import supply_cart

    new_ids, out = built
    data = DatFile.parse(out)
    empty_id, loaded_id = new_ids["cSupplyCartId"], new_ids["cLoadedSupplyCartId"]
    assert loaded_id == empty_id + 1
    for civ in data.civs:
        empty, loaded = civ.units[empty_id], civ.units[loaded_id]
        assert loaded.standing_graphic == civ.units[supply_cart.LOADED_LOOK_UNIT].standing_graphic
        assert loaded.creatable.train_locations == []
        assert (loaded.id, loaded.copy_id, loaded.base_id) == (loaded_id, loaded_id, loaded_id)
        for unit in (empty, loaded):
            assert all(t.action_type != ids.ACTION_TRADE for t in unit.bird.tasks)


def test_home_turf_aura_on_palace_and_tcs(built):
    from genieutils.datfile import DatFile

    from hinterland.datmod.patches import home_turf_aura as ht

    new_ids, out = built
    data = DatFile.parse(out)
    units = [(new_ids["cPalaceId"], ht.PALACE_RADIUS, True)]
    units += [(tc, ht.TC_RADIUS, tc in ht.TC_VARIANTS_WITH_AURA_ON) for tc in ht.TC_VARIANTS]
    for unit_id, radius, on in units:
        unit = data.civs[1].units[unit_id]
        auras = [t for t in unit.bird.tasks if t.action_type == ids.ACTION_AURA]
        assert len(auras) == 3 * len(ids.MILITARY_CLASSES), unit_id
        assert {t.class_id for t in auras} == set(ids.MILITARY_CLASSES)
        assert {t.work_range for t in auras} == {radius}
        assert bool(unit.type_50.break_off_combat & 32) == on, unit_id   # Combat Ability
    # No penalty: the Castle Age effect gains no speed/armor commands.
    vanilla_data = DatFile.parse(config_vanilla_dat())
    ours = data.effects[data.techs[ids.CASTLE_AGE].effect_id].effect_commands
    theirs = vanilla_data.effects[vanilla_data.techs[ids.CASTLE_AGE].effect_id].effect_commands
    added = ours[len(theirs):]
    assert not any(c.type in (4, 5) and c.c in (5, 8) for c in added)



def config_vanilla_dat():
    from hinterland import config

    return config.load_game_paths().vanilla_dat
