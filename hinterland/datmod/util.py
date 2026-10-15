"""genieutils-py helpers (pattern from SiegeEngineers/auto-mods)."""
from typing import TypeVar

from genieutils.common import ByteHandler, GenieClass
from genieutils.versions import Version

GC = TypeVar("GC", bound=GenieClass)


def set_identity(unit, new_id: int) -> None:
    """Make a cloned unit its own unit: id, copy_id and base_id all point at it.

    Playtest 2026-10-14: a Wonder clone that kept copy_id/base_id 276 started the
    Wonder victory countdown, showed the Wonder's tooltip and cost on its build
    button, and drew no aura circle.
    """
    unit.id = new_id
    unit.copy_id = new_id
    unit.base_id = new_id


def clone(item: GC, version: str) -> GC:
    """Deep-copy a dat object by round-tripping it through bytes."""
    packed = item.to_bytes(Version(version))
    handler = ByteHandler(memoryview(packed))
    handler.version = Version(version)
    return item.__class__.from_bytes(handler)
