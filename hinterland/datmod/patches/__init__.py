"""Ordered list of data-mod patches. Each module exposes NAME and apply(data, ids)."""
from hinterland.datmod.patches import supply_cart, supply_radius

PATCHES = [
    supply_cart,
    supply_radius,
]
