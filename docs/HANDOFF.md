# Session handoff — 2026-10-14

Paste this into a new Claude Code session (or tell it: "read docs/HANDOFF.md and continue").

## Context
- Project: **Hinterland Supply Lines**, an AoE2 DE logistics mod (data mod + XS + RMS).
- Design doc (source of truth for mechanics, a Claude Docs artifact): https://claude.ai/code/artifact/f78bb463-4b0f-4604-94be-e4146d721e85. It is edited through the Claude Docs connector on claude.ai. A local session may not have that connector; if not, propose doc edits in chat.
- Repo: `iosvanyd1/hinterland-supply-lines-aoe2def`, branch `claude/scaffold-research`, **PR #1** (open). Push to this branch to update the PR.
- User environment: Windows 11, AoE2 DE from Steam, default install `C:\Program Files (x86)\Steam\steamapps\common\AoE2DE`.
- Read first: `CLAUDE.md`, `docs/DEVELOPMENT.md`, `docs/ARCHITECTURE.md`, `docs/research/TECHNICAL_UNKNOWNS.md`.

## Done in the previous (cloud) session
1. Read the design doc and applied 5 user decisions to it (doc rev 22):
   - The "make capital" cooldown always applies, even right after the capital is lost.
   - At 0 food, **every unit** gets the out-of-supply debuff, inside or outside TC range.
   - An out-of-supply building blocks **training and research**.
   - Carts path automatically like Trade Carts: capital → destination → capital, repeating.
   - Open questions (section 10) are marked confirmed.
2. Researched the technical unknowns with 4 parallel agents. Reports are in `docs/research/`, consolidated in `TECHNICAL_UNKNOWNS.md` (U1–U14, tests T1–T14).
3. Scaffolded the repo, modelled on Divy1211/TowerDefenceAoE2 and SiegeEngineers/auto-mods:
   - `src/xs/`: entry `HinterlandSupplyLines.xs` → `Hinterland/main.xs` (supply-window rules, cart load/deliver, capital = first TC, TC coverage check, food upkeep rule inactive). Lint-clean with xs-check 0.2.30.
   - `src/rms/HinterlandArabia.rms`: `#includeXS HinterlandSupplyLines.xs`.
   - `hinterland/`: Python CLI (`python -m hinterland build|lint|package|paths`).
     - genieutils-py 0.1.2 patch `datmod/patches/supply_cart.py`: clones Trade Cart 128, trains at TC 109, enabled by Castle Age tech 102.
     - `xsgen.py` writes `generated_ids.xs`.
   - `scripts/setup.ps1`, `deploy.ps1` (`-Mode Copy|Link`, `-AlsoProfile`), `check.ps1`.
   - `tests/`: 7 pass. The 2 data-mod tests skip without the vanilla .dat.
   - `.github/workflows/ci.yml`: xs-check, pytest, and a `--no-dat` build + package.

## Not done / not verified
- **The full mod has never been built.** The cloud session had no vanilla `empires2_x2_p1.dat`. The Supply Cart patch has never run against a real .dat. On Windows, `hinterland build` followed by `pytest` runs the two data-mod tests for the first time.
- **Nothing has been tested in game.** `docs/PLAYTEST.md` has no entries.
- **CI on PR #1 has not been checked yet.** First thing: look at its status and fix any failures.
- Field names used in `supply_cart.py`: `creatable.train_locations`, `resource_costs`, `bird.tasks`, `bird.drop_sites`, `EffectCommand(type, a, b, c, d)`. They come from genieutils-py's source but are untested against a real .dat.
- `TC_BUTTON_ID = 10` is a guess at a free TC button slot.

## Key research findings (details in TECHNICAL_UNKNOWNS.md)
- Per-unit stat changes exist: `xsEffectAmount(cAddUnitAttribute=11, unitId, attr, value)`. Attack/armor use `class*256+amount` packing. Avoid Set (per-type Set adds instead of setting).
- **U6:** no per-building training/research lock exists. The scaffold's stand-in is `xsSetUnitProperty(id, cUnitSelectable, 0)`. Alternatives: a "dark twin" building swap, or local techs.
- **U5:** Trade-Cart-style pathing to a TC is unproven. `EXPERIMENTAL_TRADE_TO_TC` in the patch tries it. The fallback is XS-issued move orders.
- **U14:** the only known per-building queue stop (Stop/Freeze Object) **clears** the queue. The design wants "pause". It may need to become "cancel + refund"; ask the user.
- **U13:** the sources conflict on whether a data mod can run XS by itself (resource 33 + `Effects.xs`).
- Multiplayer: data mod + RMS `#includeXS`, unranked lobbies only. XS is not saved in recorded games.

## Gotchas found while scaffolding
- Constants shared across XS files must be `extern const` (xs-check errors otherwise).
- XS includes use backslashes, e.g. `include "Hinterland\main.xs";`.
  - On Linux the lint step copies the files under literal backslash names.
  - On Windows it passes the file directly.
- xs-check CLI: put the file path **before** `-I <dir>`. `-I` takes several values and swallows a path placed after it.
- Resolved paths: `python -m hinterland paths`. Local overrides: `config/paths.local.toml` (gitignored), or the environment variables `AOE2_INSTALL_DIR` / `AOE2_PROFILE_DIR`.

## Open question for the user
- The user once called the carts "Logistics Carts"; everything still says "Supply Cart". Rename or keep?

## Next steps (in order)
1. On Windows:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
   .venv\Scripts\python.exe -m hinterland paths
   .venv\Scripts\python.exe -m hinterland build
   .venv\Scripts\python.exe -m pytest -q
   ```
   Fix whatever the first real .dat build breaks.
2. Check and fix CI on PR #1.
3. `scripts\deploy.ps1 -AlsoProfile`, then run the smoke test and tests T1, T5, T7 and T8 in game. The user records the results in `docs/PLAYTEST.md`.
4. Based on the results, finish slice 1 (cart unit) and slice 2 (single-building supply window), then move to slice 3. One slice at a time, each playtested before the next.
