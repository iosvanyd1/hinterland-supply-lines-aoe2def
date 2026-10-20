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
        assert [loc.unit_id for loc in cart.creatable.train_locations] == [new_ids["cPalaceId"]]


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


def test_loaded_cart_pays_killer_cart_gold(built):
    from genieutils.datfile import DatFile

    from hinterland.datmod.patches import supply_cart

    new_ids, out = built
    data = DatFile.parse(out)
    for civ in data.civs:
        loaded = civ.units[new_ids["cLoadedSupplyCartId"]]
        refunds = [t for t in loaded.bird.tasks if t.action_type == supply_cart.ACTION_UNIT_REFUND]
        assert len(refunds) == 1
        r = refunds[0]
        assert (r.work_value_1, r.resource_out, r.combat_level_flag) == (supply_cart.CART_GOLD, 3, 0)
        assert r.work_range > 0            # to the killer
        empty = civ.units[new_ids["cSupplyCartId"]]
        assert all(t.action_type != supply_cart.ACTION_UNIT_REFUND for t in empty.bird.tasks)


def test_dark_buildings_cannot_attack_or_be_built(built):
    from genieutils.datfile import DatFile

    from hinterland.datmod.patches import dark_buildings

    new_ids, out = built
    data = DatFile.parse(out)
    for key, live_id in dark_buildings.DARK_TWINS.items():
        dark_id = new_ids[key]
        for civ in data.civs:
            live, dark = civ.units[live_id], civ.units[dark_id]
            if live is None:
                continue
            assert (dark.id, dark.copy_id, dark.base_id) == (dark_id, dark_id, dark_id), key
            assert dark.standing_graphic == live.standing_graphic
            assert dark.class_ == live.class_
            assert dark.type_50.attacks == [] and dark.type_50.projectile_unit_id == -1
            assert all(t.action_type not in (ids.ACTION_ATTACK, ids.ACTION_AURA) for t in dark.bird.tasks)
            assert not dark.type_50.break_off_combat & 32          # no aura
            storages = [(r.type, r.amount) for r in dark.resource_storages]
            assert storages == [(r.type, r.amount) for r in live.resource_storages]   # pop space kept
            assert dark.creatable.train_locations == []
            assert dark.garrison_capacity == 0


def test_dark_building_ids_match_xs():
    import re

    from hinterland import SRC_XS

    xs = (SRC_XS / "Hinterland" / "constants.xs").read_text(encoding="utf-8")
    for name, value in (("cWatchTowerId", ids.WATCH_TOWER), ("cGuardTowerId", ids.GUARD_TOWER),
                        ("cKeepId", ids.KEEP), ("cBombardTowerId", ids.BOMBARD_TOWER),
                        ("cDonjonId", ids.DONJON), ("cKrepostId", ids.KREPOST),
                        ("cHarborId", ids.HARBOR), ("cFortifiedChurchId", ids.FORTIFIED_CHURCH),
                        ("cFortifiedOutpostId", ids.FORTIFIED_OUTPOST),
                        ("cFortifiedOutpost2Id", ids.FORTIFIED_OUTPOST_2),
                        ("cTownCenterCastleId", ids.TOWN_CENTER_CASTLE),
                        ("cTownCenterImperialId", ids.TOWN_CENTER_IMPERIAL),
                        ("cEconomicTownCenterId", ids.ECONOMIC_TOWN_CENTER),
                        ("cDefensiveTownCenterId", ids.DEFENSIVE_TOWN_CENTER),
                        ("cMilitaryTownCenterId", ids.MILITARY_TOWN_CENTER)):
        assert re.search(rf"{name} = {value};", xs), name


AGE_NAMES = ("", "Feudal", "Castle", "Imperial")
DROP_SITE_CHAINS = (("cDock", ids.DOCK_CHAIN), ("cMill", ids.MILL_CHAIN),
                    ("cLumberCamp", ids.LUMBER_CAMP_CHAIN), ("cMiningCamp", ids.MINING_CAMP_CHAIN),
                    ("cShipyard", ids.SHIPYARD_CHAIN), ("cPort", ids.PORT_CHAIN),
                    ("cFolwark", ids.FOLWARK_CHAIN), ("cSettlement", ids.SETTLEMENT_CHAIN))


def test_drop_site_ids_match_xs():
    import re

    from hinterland import SRC_XS

    xs = (SRC_XS / "Hinterland" / "constants.xs").read_text(encoding="utf-8")
    for prefix, chain in DROP_SITE_CHAINS:
        seen = set()
        for age, value in zip(AGE_NAMES, chain):
            if value in seen:
                continue            # no variant for this age (Shipyard Feudal, Folwark Imperial)
            seen.add(value)
            name = f"{prefix}{age}Id"
            assert re.search(rf"{name} = {value};", xs), name
    assert re.search(rf"cMuleCartId = {ids.MULE_CART};", xs)


def test_xs_root_types_upgrade_in_place(built):
    """hlRootType swaps dark buildings back to the root; each root -> variant is an upgrade."""
    import re

    from genieutils.datfile import DatFile

    from hinterland import SRC_XS

    xs = (SRC_XS / "Hinterland" / "constants.xs").read_text(encoding="utf-8")

    def const(name):
        return int(re.search(rf"{name} = (\d+);", xs).group(1))

    data = DatFile.parse(config_vanilla_dat())
    upgrades = {(c.a, c.b) for e in data.effects for c in e.effect_commands if c.type == 3}
    pairs = [("cMonasteryId", v) for v in ("cMonasteryFeudalId", "cMonasteryCastleId",
                                           "cMonasteryImperialId", "cFortifiedChurchId")]
    pairs += [("cOutpostId", "cFortifiedOutpostId"), ("cDockId", "cHarborId"), ("cMillId", "cFolwarkId")]
    pairs += [("cTownCenterId", v) for v in ("cTownCenterFeudalId", "cTownCenterCastleId",
                                             "cTownCenterImperialId", "cEconomicTownCenterId",
                                             "cDefensiveTownCenterId", "cMilitaryTownCenterId")]
    for root, variant in pairs:
        assert (const(root), const(variant)) in upgrades, (root, variant)


def test_drop_site_chains_match_upgrade_effects(built):
    """Each chain step is an effect type 3 (upgrade unit) in the vanilla dat."""
    from genieutils.datfile import DatFile

    data = DatFile.parse(config_vanilla_dat())
    upgrades = {(c.a, c.b) for e in data.effects for c in e.effect_commands if c.type == 3}
    for prefix, chain in DROP_SITE_CHAINS:
        base = chain[0]
        for variant in dict.fromkeys(chain[1:]):
            if variant != base:
                assert (base, variant) in upgrades, (prefix, variant)
    for civ in data.civs:
        for unit in civ.units:
            if unit is not None and unit.class_ == 4 and unit.bird is not None:
                for site in (ids.MILL_CHAIN[0], ids.LUMBER_CAMP_CHAIN[0], ids.MINING_CAMP_CHAIN[0]):
                    if site in unit.bird.drop_sites:
                        break
                else:
                    continue
                assert ids.MILL_CHAIN[2] not in unit.bird.drop_sites   # sites listed by base ID


def test_palace_techs_researched_at_palace(built):
    from genieutils.datfile import DatFile

    from hinterland.datmod.patches import palace_techs, supply_cart

    new_ids, out = built
    data = DatFile.parse(out)
    palace_id = new_ids["cPalaceId"]
    by_key = {spec.key: spec for spec in palace_techs.TECHS}
    for spec in palace_techs.TECHS:
        tech = data.techs[new_ids[spec.key]]
        assert tech.name == spec.name
        assert [(loc.location_id, loc.button_id) for loc in tech.research_locations] == [(palace_id, spec.button)]
        assert spec.button != supply_cart.PALACE_BUTTON_ID
        required = [t for t in tech.required_techs if t >= 0]
        assert spec.age in required and tech.required_tech_count == len(required)
        if spec.requires is not None:
            assert new_ids[spec.requires] in required
            assert by_key[spec.requires].button == spec.button       # an upgrade line: one button
        assert data.effects[tech.effect_id].effect_commands == []     # XS applies it
        assert tech.language_dll_help == spec.string_help + palace_techs.HELP_ID_OFFSET
        assert len(tech.required_techs) == 6
        assert [(c.type, c.amount) for c in tech.resource_costs if c.type >= 0] == list(spec.costs)
        assert tech.language_dll_tech_tree == spec.string_name + palace_techs.TECH_TREE_OFFSET
        assert tech.effect_id < len(data.effects)
    # Coinage, the template, is untouched (clone is a deep copy).
    vanilla_data = DatFile.parse(config_vanilla_dat())
    assert data.techs[ids.COINAGE] == vanilla_data.techs[ids.COINAGE]
    # Everything trained or researched at the Palace: one button each, except upgrade lines.
    palace_units = {loc.button_id for unit in data.civs[1].units if unit is not None and unit.creatable
                    for loc in unit.creatable.train_locations if loc.unit_id == palace_id}
    assert palace_units == {supply_cart.PALACE_BUTTON_ID}
    tech_buttons = [loc.button_id for t in data.techs for loc in t.research_locations
                    if loc.location_id == palace_id]
    assert sorted(set(tech_buttons)) == sorted({s.button for s in palace_techs.TECHS})
    assert not palace_units & set(tech_buttons)
    # One button per line: techs sharing a button form a chain.
    buttons = {}
    for spec in palace_techs.TECHS:
        buttons.setdefault(spec.button, []).append(spec)
    for specs in buttons.values():
        assert all(s.requires is not None for s in specs[1:])


def test_palace_tech_strings_exist():
    from hinterland import SRC_STRINGS
    from hinterland.datmod.patches import palace_techs

    strings = (SRC_STRINGS / "en" / "key-value-modded-strings-utf8.txt").read_text(encoding="utf-8")
    import re

    families = [(s.string_name, s.string_creation, s.string_help, s.string_name + 71000)
                for s in palace_techs.TECHS]
    all_ids = [sid for family in families for sid in family]
    assert len(set(all_ids)) == len(all_ids)
    ids_in_file = [int(m) for m in re.findall(r"^(\d+) ", strings, flags=re.M)]
    assert len(set(ids_in_file)) == len(ids_in_file)          # no ID defined twice in the mod
    seen = set()
    for spec in palace_techs.TECHS:
        assert spec.requires is None or spec.requires in seen   # prerequisite listed first
        seen.add(spec.key)
        for sid in (spec.string_name, spec.string_creation, spec.string_help, spec.string_name + 71000):
            assert f"\n{sid} " in strings, sid
