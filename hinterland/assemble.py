"""Assemble build/<ModName>/ mirroring the game's resources/_common layout."""
import json
import logging
import shutil
from pathlib import Path

from hinterland import BUILD_DIR, SRC_RMS, SRC_STRINGS, SRC_XS, xsgen
from hinterland.config import GamePaths, ModInfo


def mod_root(mod: ModInfo) -> Path:
    return BUILD_DIR / mod.name


def assemble(mod: ModInfo, paths: GamePaths | None, with_dat: bool) -> Path:
    root = mod_root(mod)
    if root.exists():
        shutil.rmtree(root)
    common = root / "resources" / "_common"
    new_ids: dict[str, int] | None = None

    if with_dat:
        from hinterland.datmod.build import build_dat

        if paths is None or not paths.vanilla_dat.exists():
            raise FileNotFoundError(
                "Vanilla dat not found. Set install_dir in config/paths.local.toml "
                "or AOE2_INSTALL_DIR, or build with --no-dat."
            )
        new_ids = build_dat(paths.vanilla_dat, common / "dat" / "empires2_x2_p1.dat")
        if paths.civilizations_json.exists():
            shutil.copy2(paths.civilizations_json, common / "dat" / "civilizations.json")
    else:
        logging.info("Skipping data mod (--no-dat); generated_ids.xs keeps its placeholders")

    shutil.copytree(SRC_XS, common / "xs")
    if new_ids is not None:
        # Real IDs go into the build copy only; src/ keeps the committed placeholders,
        # since IDs like len(units) shift when a game patch adds units.
        xsgen.write(new_ids, common / "xs" / xsgen.GENERATED_IDS.relative_to(SRC_XS))
    shutil.copytree(SRC_RMS, common / "random-map-scripts")
    for lang_dir in SRC_STRINGS.iterdir():
        shutil.copytree(lang_dir, root / "resources" / lang_dir.name / "strings" / "key-value")

    info = {
        "Author": mod.author,
        "CacheStatus": 0,
        "Description": mod.description,
        "Title": f"{mod.title} v{mod.version}",
    }
    (root / "info.json").write_text(json.dumps(info, indent=2), encoding="utf-8")
    logging.info("Assembled %s", root)
    return root
