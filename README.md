# hinterland-supply-lines-aoe2def
Hinterland Supply Lines is a multiplayer logistics overhaul for Age of Empires II: Definitive Edition. In vanilla AoE2, you pay to build but never to hold, so castle drops and map-wide leapfrogging carry no risk. Hinterland adds the missing brake:
- **Capital and town-center coverage:** Buildings inside any town center's radius run freely. Anything beyond needs a live link to your capital.
- **Supply carts:** Castle Age carts shuttle from your capital to forward buildings, keeping training and research active on a timed window. If a convoy is cut, the building goes dark.
- **Raiding pays:** A destroyed cart drops gold. A cart converted by a monk is captured, unless its owner has Heresy, in which case the attacker gets gold.
- **Supply aura:** Units are weaker by default. Town centers restore full strength to units nearby.
- **Grace countdowns:** Losing a supply source starts a timer rather than causing instant collapse.
- **Food upkeep:** Standing armies cost food continuously. At 0 food, every unit is debuffed.

Built on a data mod and XS scripting for random-map multiplayer.

## Status
Pre-alpha. Slices 1–2 (Supply Cart unit, single-building supply window) are written and **not yet tested in game**.

## Docs
- [Design doc](https://claude.ai/code/artifact/f78bb463-4b0f-4604-94be-e4146d721e85)
- [Development guide](docs/DEVELOPMENT.md): setup on Windows 11 / Steam, build, deploy, test, publish
- [Architecture](docs/ARCHITECTURE.md)
- [Technical unknowns and in-game test list](docs/research/TECHNICAL_UNKNOWNS.md)
- [Playtest log](docs/PLAYTEST.md)

## Quick start (Windows 11, Steam)
```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
.venv\Scripts\python.exe -m hinterland build
scripts\deploy.ps1 -AlsoProfile
```
Then in game: Mods → My Mods → Import Local Mods; Skirmish → Data Mod: Hinterland Supply Lines → Map: Custom → HinterlandArabia.
