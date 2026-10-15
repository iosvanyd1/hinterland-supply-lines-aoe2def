"""Mod metadata (pyproject.toml) and local game paths (config/paths.local.toml + env)."""
import os
import re
import tomllib
from dataclasses import dataclass
from pathlib import Path

from hinterland import REPO_ROOT

DEFAULT_INSTALL_DIR = Path(r"C:\Program Files (x86)\Steam\steamapps\common\AoE2DE")
STEAM_LIBRARY_INDEX = Path(r"C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf")
PROFILES_ROOT = Path.home() / "Games" / "Age of Empires 2 DE"


@dataclass(frozen=True)
class ModInfo:
    name: str
    title: str
    author: str
    description: str
    version: str


def load_mod_info() -> ModInfo:
    data = tomllib.loads((REPO_ROOT / "pyproject.toml").read_text(encoding="utf-8"))
    mod = data["tool"]["hinterland"]["mod"]
    return ModInfo(
        name=mod["name"],
        title=mod["title"],
        author=mod["author"],
        description=mod["description"],
        version=data["project"]["version"],
    )


@dataclass(frozen=True)
class GamePaths:
    install_dir: Path
    profile_dir: Path | None

    @property
    def vanilla_dat(self) -> Path:
        return self.install_dir / "resources" / "_common" / "dat" / "empires2_x2_p1.dat"

    @property
    def vanilla_effects_xs(self) -> Path:
        return self.install_dir / "resources" / "_common" / "xs" / "Effects.xs"

    @property
    def civilizations_json(self) -> Path:
        return self.install_dir / "resources" / "_common" / "dat" / "civilizations.json"

    @property
    def local_mods_dir(self) -> Path | None:
        return self.profile_dir / "mods" / "local" if self.profile_dir else None


def _detect_profile() -> Path | None:
    if not PROFILES_ROOT.is_dir():
        return None
    # "0" is the game's offline/default profile; the real one is the SteamID64.
    candidates = [
        p for p in PROFILES_ROOT.iterdir() if p.is_dir() and p.name.isdigit() and p.name != "0"
    ]
    return candidates[0] if len(candidates) == 1 else None


def _steam_library_installs(index: Path = STEAM_LIBRARY_INDEX) -> list[Path]:
    """AoE2DE folders in every Steam library listed in libraryfolders.vdf."""
    if not index.is_file():
        return []
    text = index.read_text(encoding="utf-8", errors="replace")
    libraries = [Path(m.replace("\\\\", "\\")) for m in re.findall(r'"path"\s+"([^"]+)"', text)]
    return [lib / "steamapps" / "common" / "AoE2DE" for lib in libraries]


def _detect_install() -> Path:
    for candidate in [DEFAULT_INSTALL_DIR, *_steam_library_installs()]:
        if (candidate / "resources" / "_common" / "dat" / "empires2_x2_p1.dat").is_file():
            return candidate
    return DEFAULT_INSTALL_DIR


def load_game_paths() -> GamePaths:
    local = REPO_ROOT / "config" / "paths.local.toml"
    cfg = tomllib.loads(local.read_text(encoding="utf-8-sig")) if local.exists() else {}
    install = os.environ.get("AOE2_INSTALL_DIR") or cfg.get("install_dir") or str(_detect_install())
    profile = os.environ.get("AOE2_PROFILE_DIR") or cfg.get("profile_dir") or ""
    return GamePaths(
        install_dir=Path(install),
        profile_dir=Path(profile) if profile else _detect_profile(),
    )
