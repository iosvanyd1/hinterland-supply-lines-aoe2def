# Development guide

How to work on Hinterland Supply Lines on Windows 11 with the Steam version of AoE2 DE.

## 1. How the mod is built

The mod has three parts, all generated or copied into one folder that mirrors the game's own `resources\_common` layout:

| Part | Source | What it does |
|---|---|---|
| Data mod | `hinterland/datmod/patches/*.py` | Python patches applied to the vanilla `empires2_x2_p1.dat` (Supply Cart unit; later the dark-twin buildings and the charter unit). Never edited by hand in AGE. |
| XS scripts | `src/xs/` | All game logic: supply windows, carts, capital, aura, upkeep. Runs as XS rules. |
| Random map | `src/rms/` | The map players pick. Its first line `#includeXS HinterlandSupplyLines.xs` loads the logic. |

`python -m hinterland build` writes `build\HinterlandSupplyLines\` like this:

```
build\HinterlandSupplyLines\
├─ info.json
└─ resources\_common\
   ├─ dat\empires2_x2_p1.dat, civilizations.json
   ├─ xs\HinterlandSupplyLines.xs, xs\Hinterland\*.xs
   └─ random-map-scripts\HinterlandArabia.rms
```

`scripts\deploy.ps1` copies that folder into your local mods folder.

**Why patches instead of a hand-edited .dat:** every game patch ships a new vanilla .dat and breaks old data mods. With the patches as scripts, a rebuild re-applies them to the new .dat. This is how SiegeEngineers/auto-mods survives patches.

## 2. One-time setup

1. Install:
   - [Git](https://git-scm.com/download/win)
   - [uv](https://docs.astral.sh/uv/) (`winget install --id=astral-sh.uv -e`)
   - VS Code with the **AoE2 XS Scripting** extension (`Divy.vscode-xs`): syntax and live errors
   - Optional: Advanced Genie Editor, bundled in `C:\Program Files (x86)\Steam\steamapps\common\AoE2DE\Tools_Builds`, for inspecting the .dat (read only; changes go in patches)
2. Clone and set up:
   ```powershell
   git clone https://github.com/iosvanyd1/hinterland-supply-lines-aoe2def.git
   cd hinterland-supply-lines-aoe2def
   powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
   ```
   This creates `.venv`, downloads `xs-check.exe` into `tools\bin\`, and creates `config\paths.local.toml`.
3. Check the paths it prints:
   ```powershell
   .venv\Scripts\python.exe -m hinterland paths
   ```
   - `install_dir` must exist. If Steam is in another library, edit `config\paths.local.toml`.
   - `profile_dir` is `%USERPROFILE%\Games\Age of Empires 2 DE\<SteamID64>`. It is auto-detected if there is exactly one numeric folder; otherwise set it.

## 3. Game folders you will use

| What | Path |
|---|---|
| Game install | `C:\Program Files (x86)\Steam\steamapps\common\AoE2DE\` |
| Vanilla .dat (read by the build) | `<install>\resources\_common\dat\empires2_x2_p1.dat` |
| Profile | `%USERPROFILE%\Games\Age of Empires 2 DE\<SteamID64>\` |
| Local mods (deploy target) | `<profile>\mods\local\HinterlandSupplyLines\` |
| Your scenarios | `<profile>\resources\_common\scenario\` |
| Your RMS / XS (for `-AlsoProfile`) | `<profile>\resources\_common\random-map-scripts\`, `...\xs\` |
| Logs and crash dumps | `%USERPROFILE%\Games\Age of Empires 2 DE\logs\` |

Never edit `default0.xs` in the install folder. The game overwrites it.

## 4. The dev loop

```powershell
# 1. edit src\xs\..., src\rms\..., or hinterland\datmod\patches\...
.venv\Scripts\python.exe -m hinterland lint      # xs-check; must exit 0
.venv\Scripts\python.exe -m pytest -q
.venv\Scripts\python.exe -m hinterland build     # add --no-dat for XS/RMS-only changes
scripts\deploy.ps1 -AlsoProfile                  # close the game first
# 2. launch the game and test (section 5)
```

`scripts\check.ps1` runs lint, tests and build in one go.

Notes:
- **Close the game before deploying.** It locks mod files and reads the .dat and XS at startup or game start.
- `scripts\deploy.ps1 -Mode Link` makes the mods folder a junction to `build\`, so later builds need no redeploy. Still restart the match to reload XS.
- After changing a patch, the next `build` rewrites `src\xs\Hinterland\generated_ids.xs` with the new unit IDs. Commit that file.

## 5. Testing in game

**First time:** Mods → My Mods → **Import Local Mods**. Data mods are not switched on with a checkbox; you pick one in the game setup screen.

### Fast loop: Scenario Editor (XS logic)
1. Editor → new scenario, small map. Place a TC, a Barracks far from it, a few units.
2. Map tab → **Script Filename** = `HinterlandSupplyLines` (no `.xs`). This needs `deploy.ps1 -AlsoProfile`.
3. Press **Test**. XS compile errors show as a popup; runtime messages from `xsChatData` show in chat.
4. Save useful setups as `<profile>\resources\_common\scenario\!dev_<name>.aoe2scenario` and note them in PLAYTEST.md.

To test with the custom cart, the scenario must use the data mod. Unverified how the editor picks it up; see T5 in [research/TECHNICAL_UNKNOWNS.md](research/TECHNICAL_UNKNOWNS.md).

### Real loop: random map skirmish (everything)
1. Single Player → Skirmish.
2. Data Mod dropdown → **Hinterland Supply Lines**.
3. Map → Custom → **HinterlandArabia**.
4. Start. Add AI or a second player as needed.

### Debugging
- `xsChatData("supply %d", value);` prints to chat. Identical consecutive messages are de-duplicated.
- XS errors appear as an in-game dialog. If the game crashes, check the logs folder.
- Use `xsUnsync*` functions for debug display only, never for logic (multiplayer desync).

## 6. Working in slices

Follow the build order in the design doc (section 16). Do one slice at a time, and playtest each before starting the next:

| Slice | Contents | State |
|---|---|---|
| 1 | Supply Cart unit (data mod) | Patch written, untested in game |
| 2 | Single-building supply window (refuel, drain, lock) | XS skeleton written, untested |
| 3 | Capital-origin cart network, "make capital" | Partial (capital = first TC) |
| 4 | Grace countdowns | — |
| 5 | Default debuff + TC aura | — |
| 6 | Raiding rewards | — |
| 7 | Food upkeep (+ starvation debuff) | Rule written, inactive |
| 8 | UI layer | Captions only |

Before building a slice, run its blocking tests from [research/TECHNICAL_UNKNOWNS.md](research/TECHNICAL_UNKNOWNS.md). Slices 1–2 need T1, T5, T7 and T8.

## 7. After a game patch

1. Steam updates the game, and the game turns off local mods.
2. `python -m hinterland build`. If genieutils-py fails to parse the new .dat, wait for a genieutils-py release and bump the pin in `pyproject.toml`.
3. Re-check vanilla IDs (`hinterland/ids.py`, `src/xs/Hinterland/constants.xs`) in AGE if the patch notes mention them.
4. Re-run the in-game smoke test (PLAYTEST.md), then republish.

## 8. Publishing

1. Bump `version` in `pyproject.toml`.
2. Run `scripts\check.ps1`, then playtest.
3. `python -m hinterland package` writes `dist\HinterlandSupplyLines-<version>.zip` with `resources\` and `info.json` at the zip root.
4. Upload at https://www.ageofempires.com/mods/create/ (or in game: My Mods → Publish Mod).
5. Attach the same zip to a GitHub release.

Multiplayer: everyone joining the lobby is prompted to subscribe to the data mod. All players need the same version. Unranked lobbies only.

## 9. Working with Claude Code

- Cloud sessions run on Linux without the game. They can edit, lint (`xs-check`), run tests and build without the data mod (`--no-dat`). They cannot run the game or read your .dat.
- You run the in-game tests and paste the results into [PLAYTEST.md](PLAYTEST.md). Include what you did, what happened, and any chat or error output. Claude works from that record.
- Ask for one slice or one test at a time. Code generation alone cannot validate game behaviour.
- [CLAUDE.md](../CLAUDE.md) at the repo root holds the project rules Claude follows.
