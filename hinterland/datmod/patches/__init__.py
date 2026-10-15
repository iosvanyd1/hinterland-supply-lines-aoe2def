"""Ordered list of data-mod patches. Each module exposes NAME and apply(data, ids)."""
from hinterland.datmod.patches import dark_towers, home_turf_aura, palace, supply_cart

PATCHES = [
    supply_cart,
    palace,
    home_turf_aura,     # after palace: needs cPalaceId
    dark_towers,
]
