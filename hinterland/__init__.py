"""Build tooling for Hinterland Supply Lines (AoE2 DE)."""
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC_XS = REPO_ROOT / "src" / "xs"
SRC_RMS = REPO_ROOT / "src" / "rms"
BUILD_DIR = REPO_ROOT / "build"
DIST_DIR = REPO_ROOT / "dist"
