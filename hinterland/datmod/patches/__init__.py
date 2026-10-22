"""Ordered list of data-mod patches. Each module exposes NAME and apply(data, ids)."""
from hinterland.datmod.patches import dark_buildings, home_turf_aura, palace, palace_techs, supply_cart

PATCHES = [
    palace,
    supply_cart,        # after palace: trained there (needs cPalaceId)
    home_turf_aura,     # after palace: needs cPalaceId
    palace_techs,       # after palace: researched there
    dark_buildings,     # last: clones the finished TCs (auras stripped again)
]
