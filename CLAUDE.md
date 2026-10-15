# Hinterland Supply Lines — project notes for Claude

AoE2 DE mod: a Python-built data mod whose XS logic ships inside the game's `Effects.xs` (runs on any map), plus a strings-only Text mod. Design doc (source of truth for mechanics): https://claude.ai/code/artifact/f78bb463-4b0f-4604-94be-e4146d721e85

Read first: **docs/KNOWLEDGEBASE.md** (verified engine facts, field names, XS behaviour, dead ends: check it before researching or experimenting), then docs/DEVELOPMENT.md, docs/ARCHITECTURE.md, docs/research/TECHNICAL_UNKNOWNS.md.

## Rules
- The game cannot run in cloud sessions. Never claim in-game behaviour works; it is verified only by the user's playtest reports (docs/PLAYTEST.md or chat, recorded in TECHNICAL_UNKNOWNS.md).
- Work one vertical slice at a time (design section 16). Do not start a slice whose blocking tests (TECHNICAL_UNKNOWNS.md) are unresolved without saying so.
- Never commit game files (*.dat, civilizations.json, Effects.xs, game graphics).
- Data changes go in `hinterland/datmod/patches/` as scripts, never as a hand-edited .dat.
- Do not invent XS functions, trigger effects or IDs. Check docs/KNOWLEDGEBASE.md, docs/research/xs-api.md or https://ugc.aoe2.rocks/general/xs/functions/functions/ and mark anything unverified.
- When a patch adds an object whose ID XS needs, add the constant to `hinterland/xsgen.py` DEFAULTS.
- When a playtest verifies an engine fact, or something turns out not to work, add it to docs/KNOWLEDGEBASE.md with its evidence tag.
- Deploy only with the game closed. The user publishes only via in-game My Mods > Update Mod.

## Commands
- Lint XS: `python -m hinterland lint` (needs xs-check in tools/bin or PATH)
- Tests: `python -m pytest -q`
- Dev build for local tests: `python -m hinterland build --dev`, then `scripts\deploy.ps1 -ModName HinterlandSupplyLinesDev`
- Release build: `python -m hinterland build`, then `scripts\deploy.ps1` (for My Mods > Update Mod; remove the local copies afterwards)
- Build without the vanilla dat: `python -m hinterland build --no-dat`
- Package zips: `python -m hinterland package`
