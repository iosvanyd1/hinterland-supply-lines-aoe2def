# Hinterland Supply Lines — project notes for Claude

AoE2 DE mod: a Python-built data mod + XS logic + an RMS. Design doc (source of truth for mechanics): https://claude.ai/code/artifact/f78bb463-4b0f-4604-94be-e4146d721e85

Read first: docs/DEVELOPMENT.md, docs/ARCHITECTURE.md, docs/research/TECHNICAL_UNKNOWNS.md.

## Rules
- The game cannot run in cloud sessions. Never claim in-game behaviour works; it is verified only by entries in docs/PLAYTEST.md written by the user.
- Work one vertical slice at a time (design section 16). Do not start a slice whose blocking tests (TECHNICAL_UNKNOWNS.md) are unresolved without saying so.
- Never commit game files (*.dat, civilizations.json, game graphics).
- Data changes go in `hinterland/datmod/patches/` as scripts, never as a hand-edited .dat.
- Do not invent XS functions, trigger effects or IDs. Check docs/research/xs-api.md or https://ugc.aoe2.rocks/general/xs/functions/functions/ and mark anything unverified.
- When a patch adds an object whose ID XS needs, add the constant to `hinterland/xsgen.py` DEFAULTS.

## Commands
- Lint XS: `python -m hinterland lint` (needs xs-check in tools/bin or PATH)
- Tests: `python -m pytest -q`
- Build without the vanilla dat: `python -m hinterland build --no-dat`
- Package: `python -m hinterland package`
