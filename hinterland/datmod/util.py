"""genieutils-py helpers (pattern from SiegeEngineers/auto-mods)."""
from typing import TypeVar

from genieutils.common import ByteHandler, GenieClass
from genieutils.versions import Version

GC = TypeVar("GC", bound=GenieClass)


def clone(item: GC, version: str) -> GC:
    """Deep-copy a dat object by round-tripping it through bytes."""
    packed = item.to_bytes(Version(version))
    handler = ByteHandler(memoryview(packed))
    handler.version = Version(version)
    return item.__class__.from_bytes(handler)
