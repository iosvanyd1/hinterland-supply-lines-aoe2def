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

# Drop sites (decision 2026-10-15: gathering needs supply too). Villagers'
# drop-site lists hold the base ID, so age variants still take drop-offs and a
# dark twin (its own base ID) does not. Age-ups upgrade them in place (effect
# type 3 in techs 101/102/103); chains are (Dark, Feudal, Castle, Imperial).
# Folwark (Poles, replaces the Mill) and Settlement upgrade by their own techs
# 794/795 and 1354/1355 (Feudal, Castle) and have no Imperial variant.
DOCK_CHAIN = (45, 133, 47, 51)
MILL_CHAIN = (68, 129, 130, 131)
LUMBER_CAMP_CHAIN = (562, 563, 564, 565)
MINING_CAMP_CHAIN = (584, 585, 586, 587)
SHIPYARD_CHAIN = (2119, 2119, 2117, 2118)   # no Feudal variant
PORT_CHAIN = (2172, 2143, 2142, 2141)        # Greek civs' dock
FOLWARK_CHAIN = (1734, 1711, 1720, 1720)
SETTLEMENT_CHAIN = (2556, 2558, 2560, 2560)
MULE_CART = 1808                             # a movable drop site, no ages
WONDER = 276
WONDER_VARIANTS = (276, 1368, 1369)   # all on build slot 12; only 276 is ever enabled in vanilla
# Towers (class 52). Guard Tower (tech 140) upgrades 79 -> 234; Keep (tech 63)
# upgrades 79 and 234 -> 235. Bombard Tower and the Sicilian Donjon never upgrade.
WATCH_TOWER = 79
GUARD_TOWER = 234
KEEP = 235
BOMBARD_TOWER = 236
DONJON = 1665
# Other shooting buildings (decision 2026-10-15: they go dark out of supply).
# Effect type 3 turns Dock 45/133/47/51 into the Harbor (Thalassocracy),
# Monastery 104/30/31/32 into the Fortified Church, Outpost 598 into Fortified
# Outpost 2415, and TC 109 into the Economic / Military / Defensive TC.
CASTLE = 82               # goes dark only once an enemy has Siege & Starve Out (palace_techs.py)
KREPOST = 1251
HARBOR = 1189
FORTIFIED_CHURCH = 1806
FORTIFIED_OUTPOST = 2415
FORTIFIED_OUTPOST_2 = 2417
ECONOMIC_TOWN_CENTER = 2275
DEFENSIVE_TOWN_CENTER = 2276
MILITARY_TOWN_CENTER = 2277

# Techs
FEUDAL_AGE = 101          # dat names are off by one; go by ID
CASTLE_AGE = 102          # dat names are off by one; go by ID
IMPERIAL_AGE = 103        # dat names are off by one; go by ID
COINAGE = 23              # Market tech; template for the Palace techs
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
