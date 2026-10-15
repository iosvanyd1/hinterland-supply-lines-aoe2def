import json
import zipfile

from hinterland import assemble, config, package


def test_build_without_dat_mirrors_game_layout():
    mod = config.load_mod_info()
    root = assemble.assemble(mod, None, with_dat=False)
    common = root / "resources" / "_common"
    assert (common / "xs" / "HinterlandSupplyLines.xs").is_file()
    assert (common / "xs" / "Hinterland" / "main.xs").is_file()
    assert (common / "random-map-scripts" / "HinterlandArabia.rms").is_file()
    text = assemble.text_mod_root(mod)
    assert (text / "resources" / "en" / "strings" / "key-value" / "key-value-modded-strings-utf8.txt").is_file()
    assert (text / "info.json").is_file()
    info = json.loads((root / "info.json").read_text(encoding="utf-8"))
    assert info["Title"].startswith(mod.title)


def test_rms_includes_entry_point():
    rms = (assemble.SRC_RMS / "HinterlandArabia.rms").read_text(encoding="utf-8")
    assert "#includeXS HinterlandSupplyLines.xs" in rms


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
    import re

    path = assemble.SRC_STRINGS / "en" / "key-value-modded-strings-utf8.txt"
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("//") or not line.strip():
            continue
        assert re.fullmatch(r'\d+ ".*"', line), f"broken strings entry: {line[:60]}"
