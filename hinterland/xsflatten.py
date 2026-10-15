"""Inline XS `include` statements into one self-contained file.

Nested `include "Hinterland\\main.xs"` statements did not resolve inside a
published mod (playtest 2026-10-14), and the XS is appended to the game's
Effects.xs anyway (assemble.py), so the build ships one flat file.
"""
import re
from pathlib import Path

INCLUDE = re.compile(r'^[ \t]*include[ \t]+"([^"]+)"[ \t]*;[ \t]*\r?$', re.MULTILINE)


def flatten(entry: Path, root: Path, _seen: set[Path] | None = None) -> str:
    """Return `entry` with every `include "x";` replaced by x's (flattened) text.

    Include paths are relative to `root` and may use backslashes. A file included
    twice is inlined once.
    """
    seen = _seen if _seen is not None else {entry.resolve()}

    def inline(match: re.Match) -> str:
        rel = match.group(1)
        path = (root / rel.replace("\\", "/")).resolve()
        if path in seen:
            return f"// (already included: {rel})"
        if not path.is_file():
            raise FileNotFoundError(f"XS include not found: {rel} (from {entry.name})")
        seen.add(path)
        return f"// ---- begin {rel} ----\n{flatten(path, root, seen)}\n// ---- end {rel} ----"

    return INCLUDE.sub(inline, entry.read_text(encoding="utf-8"))
