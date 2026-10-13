"""Read the vanilla dat, apply patches in order, write the modded dat."""
import logging
from pathlib import Path


def build_dat(vanilla_dat: Path, output_dat: Path) -> dict[str, int]:
    """Returns the IDs assigned to new objects, keyed by their XS constant name."""
    from genieutils.datfile import DatFile  # imported lazily: optional for XS-only builds

    from hinterland.datmod.patches import PATCHES

    logging.info("Parsing %s", vanilla_dat)
    data = DatFile.parse(vanilla_dat)
    new_ids: dict[str, int] = {}
    for patch in PATCHES:
        logging.info("Applying patch %s", patch.NAME)
        patch.apply(data, new_ids)
    output_dat.parent.mkdir(parents=True, exist_ok=True)
    data.save(output_dat)
    logging.info("Wrote %s", output_dat)
    return new_ids
