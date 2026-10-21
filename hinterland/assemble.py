"""Assemble build/<ModName>/ mirroring the game's resources/_common layout.

Also assembles build/<ModName>-Text/, a strings-only mod. The game loads modded
strings at startup from enabled mods only; a data mod is enabled later, in the
lobby, so its own strings file is never read (playtest 2026-10-14).
"""
import json
import logging
import re
import shutil
from dataclasses import replace
from pathlib import Path

from hinterland import BUILD_DIR, SRC_RMS, SRC_STRINGS, SRC_XS, xsflatten, xsgen
from hinterland.config import GamePaths, ModInfo


def mod_root(mod: ModInfo) -> Path:
    return BUILD_DIR / mod.name


def dev_mod(mod: ModInfo) -> ModInfo:
    """A local test build that does not clash with the published mod."""
    return replace(mod, name=f"{mod.name}Dev", title=f"{mod.title} (dev)")


AI_SWITCH = "extern const bool cExemptComputerPlayers = true;"


def affect_computer_players(xs_dir: Path) -> None:
    """Flip the AI exemption switch in a build copy of the XS (testing only).

    constants.xs keeps `cExemptComputerPlayers = true` (release default); this
    sets it to false in build/, so the AI is treated like a human player.
    """
    constants = xs_dir / "Hinterland" / "constants.xs"
    text = constants.read_text(encoding="utf-8")
    if AI_SWITCH not in text:
        raise ValueError(f"AI switch not found in {constants}: expected {AI_SWITCH!r}")
    constants.write_text(text.replace(AI_SWITCH, AI_SWITCH.replace("true", "false")),
                         encoding="utf-8", newline="\n")
    logging.warning("AI players are AFFECTED by the mod in this build (--ai-affected)")


def assemble(mod: ModInfo, paths: GamePaths | None, with_dat: bool, text_mod: bool = True,
             ai_affected: bool = False) -> Path:
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
    if ai_affected:
        affect_computer_players(common / "xs")
    vanilla_effects = paths.vanilla_effects_xs if (with_dat and paths is not None) else None
    _ship_xs(common / "xs", vanilla_effects)
    if SRC_RMS.is_dir() and any(SRC_RMS.iterdir()):
        shutil.copytree(SRC_RMS, common / "random-map-scripts")
    _write_info(root, mod.author, mod.description, mod.title)
    logging.info("Assembled %s", root)
    if text_mod:
        assemble_text_mod(mod)
    return root


XS_ENTRY = "HinterlandSupplyLines.xs"
EFFECTS_XS = "Effects.xs"
_TOP_LEVEL = re.compile(
    r"^(?:extern\s+)?(?:const\s+)?(?:int|float|bool|string|vector|void)\s+(\w+)|^rule\s+(\w+)",
    re.MULTILINE,
)


def top_level_names(xs: str) -> set[str]:
    return {a or b for a, b in _TOP_LEVEL.findall(xs)}


def _ship_xs(xs_dir: Path, vanilla_effects: Path | None) -> None:
    """Ship our XS as one flat file, appended to the game's Effects.xs when known.

    The game includes Effects.xs in every game ("Included automatically"), and a
    data mod's copy replaces the game's, so the supply rules run on any map (T14).
    Nested includes do not resolve inside a published mod (xsflatten.py), so the
    XS is flattened. Without the vanilla file (--no-dat builds) the flat entry
    file is shipped instead, for linting and tests.
    """
    ours = xsflatten.flatten(xs_dir / XS_ENTRY, xs_dir)
    for child in xs_dir.iterdir():
        if child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink()
    if vanilla_effects is None or not vanilla_effects.is_file():
        (xs_dir / XS_ENTRY).write_text(ours, encoding="utf-8", newline="\n")
        return
    vanilla = vanilla_effects.read_text(encoding="utf-8-sig")
    clashes = top_level_names(vanilla) & top_level_names(ours)
    if clashes:
        raise ValueError(f"XS names clash with the game's Effects.xs: {sorted(clashes)}")
    banner = "\n\n// ==== Hinterland Supply Lines (appended by the mod build) ====\n\n"
    (xs_dir / EFFECTS_XS).write_text(vanilla.rstrip() + banner + ours, encoding="utf-8", newline="\n")


def text_mod_root(mod: ModInfo) -> Path:
    return BUILD_DIR / f"{mod.name}-Text"


def assemble_text_mod(mod: ModInfo) -> Path:
    root = text_mod_root(mod)
    if root.exists():
        shutil.rmtree(root)
    for lang_dir in SRC_STRINGS.iterdir():
        shutil.copytree(lang_dir, root / "resources" / lang_dir.name / "strings" / "key-value")
    _write_info(
        root,
        mod.author,
        f"Tooltips for {mod.title}. Enable it (On) alongside the data mod.",
        f"{mod.title} - Text",
    )
    logging.info("Assembled %s", root)
    return root


def _write_info(root: Path, author: str, description: str, title: str) -> None:
    info = {"Author": author, "CacheStatus": 0, "Description": description, "Title": title}
    root.mkdir(parents=True, exist_ok=True)
    (root / "info.json").write_text(json.dumps(info, indent=2), encoding="utf-8")
