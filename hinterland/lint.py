"""Run xs-check on the XS entry point.

The game resolves `include "Hinterland\\x.xs"` with Windows separators. On
Linux/macOS (CI) the sources are staged into a temp dir under literal
backslash filenames so xs-check resolves the same strings.
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from hinterland import REPO_ROOT, SRC_XS

ENTRY = "HinterlandSupplyLines.xs"


def find_xs_check() -> str:
    exe = "xs-check.exe" if os.name == "nt" else "xs-check"
    local = REPO_ROOT / "tools" / "bin" / exe
    if local.exists():
        return str(local)
    found = shutil.which("xs-check")
    if found:
        return found
    raise FileNotFoundError(
        "xs-check not found. Run scripts/setup.ps1 (Windows) or put xs-check on PATH. "
        "Releases: https://github.com/Divy1211/xs-check/releases"
    )


def _stage(tmp: Path) -> Path:
    for f in SRC_XS.rglob("*.xs"):
        rel = f.relative_to(SRC_XS)
        shutil.copy2(f, tmp / "\\".join(rel.parts))
    return tmp / ENTRY


def lint(warnings_as_errors: bool = True) -> int:
    xs_check = find_xs_check()
    flags = ["-w"] if warnings_as_errors else []
    if os.name == "nt":
        cmd = [xs_check, str(SRC_XS / ENTRY), "-I", str(SRC_XS), *flags]
        return subprocess.call(cmd)
    with tempfile.TemporaryDirectory() as d:
        entry = _stage(Path(d))
        cmd = [xs_check, str(entry), *flags, "-I", d]
        return subprocess.call(cmd)


if __name__ == "__main__":
    sys.exit(lint())
