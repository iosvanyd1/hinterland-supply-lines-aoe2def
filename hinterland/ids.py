"""Vanilla AoE2 DE IDs used by the data mod.

Sources: docs/research/TECHNICAL_UNKNOWNS.md. Re-verify after each game patch
in Advanced Genie Editor.
"""

# Units
TRADE_CART = 128          # empty Trade Cart (class 19)
TRADE_CART_FULL = 204

# Buildings
TOWN_CENTER = 109
# Age-ups "upgrade" the TC (effect type 3): 109 Dark -> 71 Feudal -> 141 Castle
# -> 142 Imperial. Per-type TC data must be on every variant.
TOWN_CENTER_FEUDAL = 71
TOWN_CENTER_CASTLE = 141
TOWN_CENTER_IMPERIAL = 142
MARKET = 84
WONDER = 276
WONDER_VARIANTS = (276, 1368, 1369)   # all on build slot 12; only 276 is ever enabled in vanilla
# Towers (class 52). Guard Tower (tech 140) upgrades 79 -> 234; Keep (tech 63)
# upgrades 79 and 234 -> 235. Bombard Tower and the Sicilian Donjon never upgrade.
WATCH_TOWER = 79
GUARD_TOWER = 234
KEEP = 235
BOMBARD_TOWER = 236
DONJON = 1665

# Techs
FEUDAL_AGE = 101          # dat names are off by one; go by ID
CASTLE_AGE = 102          # dat names are off by one; go by ID
HERESY = 439

# Effect command types
EFFECT_ENABLE_DISABLE_UNIT = 2

# Task / action types
ACTION_ATTACK = 7
ACTION_TRADE = 111
ACTION_AURA = 155
ACTION_WONDER_VICTORY = 120   # AGE: "Generate Wonder Victory"

# Unit class IDs
CLASS_TRADE_CART = 19

# Military unit classes that get the home-turf aura (design section 13).
# Ships (2, 20, 21, 22, 53), villagers (4), trade (19), livestock (58, 61) excluded.
MILITARY_CLASSES = (
    0,   # archer
    6,   # infantry
    12,  # cavalry
    13,  # siege weapon
    18,  # monk
    23,  # mounted gunpowder (Conquistador, Arambai)
    28,  # war dog
    35,  # petard
    36,  # cavalry archer
    44,  # hand cannoneer
    47,  # scout cavalry
    51,  # packed trebuchet
    54,  # unpacked trebuchet
    55,  # scorpion
    59,  # heroes and the Regicide King
)
