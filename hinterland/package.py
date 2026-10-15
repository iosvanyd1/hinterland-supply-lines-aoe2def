"""Zip the built mods for upload (resources/ and info.json at each zip root).

Two zips: the data mod and the strings-only Text mod (see assemble.py). Both
must be published; players subscribe to both and switch the Text mod On.
"""
import hashlib
import zipfile
from pathlib import Path

from hinterland import DIST_DIR
from hinterland.assemble import mod_root, text_mod_root
from hinterland.config import ModInfo


def _zip(root: Path, out: Path) -> Path:
    if not root.exists():
        raise FileNotFoundError(f"{root} missing; run `hinterland build` first")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in sorted(root.rglob("*")):
            if f.is_file():
                zf.write(f, f.relative_to(root).as_posix())
    return out


def package(mod: ModInfo) -> list[Path]:
    DIST_DIR.mkdir(exist_ok=True)
    outs = [
        _zip(mod_root(mod), DIST_DIR / f"{mod.name}-{mod.version}.zip"),
        _zip(text_mod_root(mod), DIST_DIR / f"{mod.name}-Text-{mod.version}.zip"),
    ]
    sums = "".join(f"{hashlib.sha256(o.read_bytes()).hexdigest()}  {o.name}\n" for o in outs)
    (DIST_DIR / "SHA256SUMS").write_text(sums, encoding="utf-8")
    return outs
