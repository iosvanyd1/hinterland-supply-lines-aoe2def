import json
import re
import zipfile

from hinterland import assemble, config, package


def test_build_without_dat_mirrors_game_layout():
    mod = config.load_mod_info()
    root = assemble.assemble(mod, None, with_dat=False)
    common = root / "resources" / "_common"
    xs_files = sorted(p.relative_to(common / "xs").as_posix() for p in (common / "xs").rglob("*") if p.is_file())
    assert xs_files == ["HinterlandSupplyLines.xs"]          # no vanilla Effects.xs: one flat file
    assert not (common / "random-map-scripts").exists()     # any map: no custom RMS
    text = assemble.text_mod_root(mod)
    assert (text / "resources" / "en" / "strings" / "key-value" / "key-value-modded-strings-utf8.txt").is_file()
    assert (text / "info.json").is_file()
    info = json.loads((root / "info.json").read_text(encoding="utf-8"))
    assert info["Title"] == mod.title        # no version in the title (published name)


def test_our_xs_has_no_main():
    # Appended to the game's auto-included Effects.xs, so a main() would clash.
    src = (assemble.SRC_XS / "Hinterland" / "main.xs").read_text(encoding="utf-8")
    assert not re.search(r"^\s*void\s+main\s*\(", src, re.MULTILINE)
    assert src.count("hlEnsureInit();") == src.count("\nrule hl")


def test_effects_xs_is_vanilla_plus_ours(tmp_path):
    xs = tmp_path / "xs"
    (xs / "Hinterland").mkdir(parents=True)
    (xs / "HinterlandSupplyLines.xs").write_text('include "Hinterland\\a.xs";\n', encoding="utf-8")
    (xs / "Hinterland" / "a.xs").write_text("rule hlOurs active { }\n", encoding="utf-8")
    vanilla = tmp_path / "Effects.xs"
    vanilla.write_text("void EffectFunction1(int playerId = -1) { }\n", encoding="utf-8")
    assemble._ship_xs(xs, vanilla)
    assert sorted(p.name for p in xs.iterdir()) == ["Effects.xs"]
    out = (xs / "Effects.xs").read_text(encoding="utf-8")
    assert out.startswith("void EffectFunction1") and "rule hlOurs" in out


def test_effects_xs_name_clash_is_an_error(tmp_path):
    xs = tmp_path / "xs"
    xs.mkdir()
    (xs / "HinterlandSupplyLines.xs").write_text("void EffectFunction1() { }\n", encoding="utf-8")
    vanilla = tmp_path / "Effects.xs"
    vanilla.write_text("void EffectFunction1(int playerId = -1) { }\n", encoding="utf-8")
    try:
        assemble._ship_xs(xs, vanilla)
    except ValueError as e:
        assert "EffectFunction1" in str(e)
    else:
        raise AssertionError("expected a name clash error")


def test_dev_build_has_its_own_name():
    mod = config.load_mod_info()
    dev = assemble.dev_mod(mod)
    root = assemble.assemble(dev, None, with_dat=False, text_mod=False)
    assert root.name == f"{mod.name}Dev"
    info = json.loads((root / "info.json").read_text(encoding="utf-8"))
    assert info["Title"] == f"{mod.title} (dev)"
    assert not assemble.text_mod_root(dev).exists()


def test_package_zips_data_and_text_mods_with_resources_at_root():
    mod = config.load_mod_info()
    assemble.assemble(mod, None, with_dat=False)
    outs = package.package(mod)
    assert [o.name for o in outs] == [f"{mod.name}-{mod.version}.zip", f"{mod.name}-Text-{mod.version}.zip"]
    for out in outs:
        names = zipfile.ZipFile(out).namelist()
        assert "info.json" in names
        assert all(n == "info.json" or n.startswith("resources/") for n in names)
    text_names = zipfile.ZipFile(outs[1]).namelist()
    assert "resources/en/strings/key-value/key-value-modded-strings-utf8.txt" in text_names


def test_strings_file_has_one_entry_per_line():
    path = assemble.SRC_STRINGS / "en" / "key-value-modded-strings-utf8.txt"
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("//") or not line.strip():
            continue
        assert re.fullmatch(r'\d+ ".*"', line), f"broken strings entry: {line[:60]}"


def test_flattened_xs_has_no_includes_and_all_rules():
    mod = config.load_mod_info()
    root = assemble.assemble(mod, None, with_dat=False)
    flat = (root / "resources" / "_common" / "xs" / "HinterlandSupplyLines.xs").read_text(encoding="utf-8")
    assert not re.search(r'^\s*include\s+"', flat, re.MULTILINE)
    for name in ("void hlEnsureInit()", "rule hlSupplyTick", "rule hlCartLogistics", "extern const int cSupplyCartId"):
        assert name in flat
