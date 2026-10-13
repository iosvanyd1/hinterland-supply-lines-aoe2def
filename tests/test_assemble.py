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
    info = json.loads((root / "info.json").read_text(encoding="utf-8"))
    assert info["Title"].startswith(mod.title)


def test_rms_includes_entry_point():
    rms = (assemble.SRC_RMS / "HinterlandArabia.rms").read_text(encoding="utf-8")
    assert "#includeXS HinterlandSupplyLines.xs" in rms


def test_package_has_resources_at_zip_root():
    mod = config.load_mod_info()
    assemble.assemble(mod, None, with_dat=False)
    out = package.package(mod)
    names = zipfile.ZipFile(out).namelist()
    assert "info.json" in names
    assert all(n == "info.json" or n.startswith("resources/") for n in names)
