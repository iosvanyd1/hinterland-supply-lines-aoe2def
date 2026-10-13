"""Zip build/<ModName> for upload (resources/ and info.json at the zip root)."""
import hashlib
import zipfile
from pathlib import Path

from hinterland import DIST_DIR
from hinterland.assemble import mod_root
from hinterland.config import ModInfo


def package(mod: ModInfo) -> Path:
    root = mod_root(mod)
    if not root.exists():
        raise FileNotFoundError(f"{root} missing; run `hinterland build` first")
    DIST_DIR.mkdir(exist_ok=True)
    out = DIST_DIR / f"{mod.name}-{mod.version}.zip"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in sorted(root.rglob("*")):
            if f.is_file():
                zf.write(f, f.relative_to(root).as_posix())
    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    (DIST_DIR / "SHA256SUMS").write_text(f"{digest}  {out.name}\n", encoding="utf-8")
    return out
