# AoE2:DE open-source mods and tooling: how they're structured, built and deployed

Research date: 2026-10-13. Method: I shallow-cloned each repo marked "(cloned)" and read its files. GitHub search and profile pages were read with WebFetch. The GitHub REST API (`api.github.com`) was blocked in this session, so star counts come from the GitHub web pages (topic, search and profile listings) on the research date.
Markers: **[V]** = I checked it in a primary source (repo file or official page). **[U]** = unverified (forum hearsay, my inference, or not found).

---

## 1. Key takeaways

1. **Mods don't build their own binaries; they generate files with Python.** The established pattern, used by Alian713 (Divy1211), KSneijders and SiegeEngineers, is a Python build that:
   - reads the vanilla `empires2_x2_p1.dat` from the install folder and patches it with `genieutils-py` or `GenieDatParser`;
   - generates or patches a `.aoe2scenario` with `AoE2ScenarioParser`;
   - writes everything into `<mod>/resources/_common/{dat,xs,scenario,random-map-scripts}`, a tree that mirrors the game install. [V]
2. **Deploying means writing that tree into `%USERPROFILE%\Games\Age of Empires 2 DE\<SteamID64>\mods\local\<ModName>\`.** You either point the build output there directly (TowerDefenceAoE2), copy it there with a deploy script (aoe2-cba-survival), or symlink your working XS folder into the profile `xs` folder for fast iteration (TowerDefenceAoE2 README: `mklink /D`). [V]
3. **XS linting exists:** `xs-check` (Rust CLI and LSP) by Alian713. AoE2ScenarioParser ships it as a bundled binary (`xs_manager.add_script(..., validate=True)`). The VS Code extension "AoE2 XS Scripting" (`Divy.vscode-xs`) uses it, and so does a JetBrains plugin by KSneijders. For RMS there is `rms-check` (SiegeEngineers, older; Divy1211 is rewriting it). [V]
4. **Releases:** zip the *contents* of the mod folder (`resources/...` at the zip root; `info.json` is optional) and upload it at `https://www.ageofempires.com/mods/create/`, or use "Publish Mod" in the in-game Mod Manager. `mods.ageofempires.com` does not resolve (DNS ENOTFOUND); the real site is `www.ageofempires.com/mods/`. [V]
5. **Testing:** few repos have CI against the game, because the game can't run on CI. They test structure instead:
   - pytest round-trips (build, write, re-read the scenario, assert triggers and units);
   - xs-check / rms-check lint;
   - genieutils-py CI checks out a private `SiegeEngineers/dat-files` repo of sample `.dat` files;
   - in-game playtesting is a manual checklist (`PLAYTEST.md`). [V]

---

## 2. Tooling repos

### KSneijders/AoE2ScenarioParser (cloned) [V]
- **URL / activity:** https://github.com/KSneijders/AoE2ScenarioParser · 105★ · last commit 2026-10-12 (v0.9.7 on PyPI, uploaded 2026-10-12; requires Python >= 3.8).
- **What it is:** a Python library to read, write and create `.aoe2scenario` files. Through "managers" (trigger, unit, map, player, message, option, xs) it can inspect, add, edit and remove triggers, conditions, effects, units, terrain and players.
- **DE version support:** the README says "Support: `1.36` (Nov 2019) → `1.59` Current Version (Since: Sept 2026)". The `AoE2ScenarioParser/versions/DE/` directory goes up to `v1.59`. Changelog 0.9.7 (2026-10-12) adds the **Viking Sagas DLC** datasets and renames entries (for example `LONGBOAT` → `LONGSHIP`, `JARL` → `NORSE_CHIEFTAIN`), so pin the version.
- **Layout:** `AoE2ScenarioParser/` (package), `docs/` (docsify site + cheatsheets), `tests/`, `tricks/`, `resources/`, `pyproject.toml` (version placeholder `<VERSION_HERE>`), `CHANGELOG.md`.
- **CI / release:** `.github/workflows/deploy-app.yml` runs on tag `v*`. It `sed`s the tag into `pyproject.toml` and `version.py`, runs `python -m build`, then publishes to TestPyPI and PyPI. `deploy-docs.yml` deploys the docs.
- **Generating triggers programmatically:**
  ```python
  from AoE2ScenarioParser.scenarios.aoe2_de_scenario import AoE2DEScenario
  scn = AoE2DEScenario.from_default()            # or .from_file(path); from_default uses LATEST_VERSION
  t = scn.trigger_manager.add_trigger("Hello World Trigger")
  t.new_effect.display_instructions(...)          # every effect/condition is a typed method
  scn.xs_manager.script_name = r"MyMod\main"      # Map tab "Script Filename" (subfolder allowed)
  scn.xs_manager.add_script(xs_file_path="src/xs/main.xs", validate=True)  # embeds XS + runs xs-check
  scn.write_to_file(out_path)
  ```
- **XS behaviour:** `add_script` embeds the XS in a disabled trigger named "XS SCRIPT" with a `Script Call` effect. When the scenario loads, the game compiles Script Call contents into `default0.xs` on every machine, so this XS *does* reach all players and spectators. A file referenced only through the Script Filename field transfers to players but **not to spectators** (`docs/cheatsheets/xs.md`).
  - The parser raises `XsValidationError` if a Script Call calls a function *with parameters*, because the game silently fails on that.
  - The parser bundles xs-check binaries (`dependencies/xs-check/xs-check{,.exe}`, pinned version 0.2.30).

### huongnguyen2h/AoE2ScenarioParserTutorial (cloned) [V]
- https://github.com/huongnguyen2h/AoE2ScenarioParserTutorial · 5★ · last commit 2023-04-25.
- Folders `[Example1] - How to add triggers` through `[Example9] - How to modify terrains`, plus a template script. All examples hardcode `C:/Users/<u>/Games/Age of Empires 2 DE/<steamid>/resources/_common/scenario/`.

### KSneijders/AoE2ScenarioRms (cloned) [V]
- https://github.com/KSneijders/AoE2ScenarioRms · last commit 2026-10-12 · work in progress. Built on AoE2ScenarioParser, it randomises resource placement in a scenario using generated XS. PyPI `AoE2ScenarioRms`; CI `publish-to-test-pypi.yml`.

### SiegeEngineers/genieutils-py (cloned) [V]
- **URL / activity:** https://github.com/SiegeEngineers/genieutils-py · 21★ · last commit 2026-04-28 ("Support FileVersion 8.9"). PyPI `genieutils-py` 0.1.2 (2026-04-28), Python >= 3.11. Author: HSZemi.
- **What it is:** reads and writes `empires2_x2_p1.dat`. It supports only GV_C20+ (FileVersion 7.7+). It includes a CLI, `dat-to-json path/to/empires2_x2_p1.dat`.
- **API:**
  ```python
  data = DatFile.parse(path)
  data.techs[22].resource_costs[0].amount = 69
  data.save(out)
  # civs: data.civs[i].units[id]...
  ```
- **CI:** `.github/workflows/python-lib.yml` runs on push and PR. It checks out the private `SiegeEngineers/dat-files` repo into `tests/testdata/` (deploy key), runs `./test`, then `python -m build`.
- **Caveat [U]:** I did not confirm that the Oct 2026 Viking Sagas patch kept the dat at FileVersion 8.9. If `DatFile.parse` fails after a patch, wait for an update.

### Divy1211/GenieDatParser (cloned) [V]
- https://github.com/Divy1211/GenieDatParser · 6★ · last commit 2026-10-12. Alian713's dat parser, built on his `BinaryFileParser` (`bfp_rs`, Rust-backed). The README says it supports AoK, AoC, HD and DE2.
- API: `from sections.datfile_sections import DatFile`, then `DatFile.from_file(...)` and `.to_file(...)`. Not on PyPI under that name: it is consumed as a git submodule plus a uv path dependency.

### Divy1211/xs-check (cloned) [V]
- **URL / activity:** https://github.com/Divy1211/xs-check · 7★ · last commit 2026-09-23. Rust workspace: `xsc-core`, `xsc-cli`, `xsc-lsp`.
- **Install:** `cargo install --git https://github.com/Divy1211/xs-check xsc-cli`, or download the release binaries.
- **CLI:** `xs-check file.xs [--ignores W1,W2] [--warnings-as-errors]`. Exit codes: 0 = OK, 1 = bad args or file missing, 2 = lint errors. This makes it usable as a CI gate.
- **Release:** a local `build.ps1` bumps the version, runs `cargo build --release` (Windows, then WSL for Linux), tags and pushes. It then copies `xs-check-lsp(.exe)` into the VS Code extension and runs `vsce package`. CI: `publish.yml`.

### Divy1211/vsc-xs-support (cloned) [V]
- https://github.com/Divy1211/vsc-xs-support · 9★ · Marketplace id **`Divy.vscode-xs`** ("AoE2 XS Scripting", v1.0.21 in `package.json`). Provides syntax highlighting, completion and hover docs. The xs-check `build.ps1` packages the LSP into a `dev-lsp` branch of the extension (prerelease) [V]. Whether the LSP diagnostics are in the stable Marketplace build is [U].

### KSneijders/idea-xs-support (cloned) [V]
- https://github.com/KSneijders/idea-xs-support · last commit 2026-10-12. A JetBrains (PyCharm/IDEA) plugin that wraps the xs-check LSP via LSP4IJ. Installed from a release zip; the xs-check source is a git submodule.

### Divy1211/AoE2DE_UGC_Guide (ugc.aoe2.rocks source) (cloned) [V]
- https://github.com/Divy1211/AoE2DE_UGC_Guide · 36★ · last commit 2026-10-10. MkDocs site (`mkdocs.yml`, `docs/`, `aoe2lexers/` Pygments lexers for XS/RMS); CI `publish.yml`. Sections: `general/xs` (beginner, programmer, function and constant reference, bugs list), `scenarios/triggers`, `rms`, `mods`, `tools`.
- The XS library list names:
  - `mardaravicius/aoe2de_xslibs` (lists, dicts, RNG);
  - `KSneijders/XsStructs`;
  - `codeberg.org/hmis/aoe2_xsSort`.
- I did not fetch the live domain ugc.aoe2.rocks; I read the repo source instead. The GitHub Pages URL is `divy1211.github.io/AoE2DE_UGC_Guide` (linked from the AoE2ScenarioParser docs) [V].

### Divy1211/rms-check (new, cloned) and SiegeEngineers/rms-check (cloned) [V]
- **SiegeEngineers/rms-check** (https://github.com/SiegeEngineers/rms-check, 7★, last commit 2022-02): Rust linter + LSP + VS Code extension (`vscode/`), CLI `rms-check [--de] file`. It is stale: it does not know `#includeXS` or newer DE commands. The henrihallik repos below had to patch it.
- **Divy1211/rms-check** (last commit 2026-08-29): a rewrite (`rmsc-core`, `rmsc-cli`, `rmsc-lsp`, `build.ps1`, `bumpver.py`). README usage is still "ToDo", so treat it as pre-release.

### Other
- **mangudai/vscode** (cloned, 2018): old RMS VS Code extension.
- **mardaravicius/aoe2de_xslibs** (cloned, last commit 2026-10-10): XS libraries are *generated from Python* (`src/xs/*.py` produces `xs/*.xs`) and unit-tested with pytest (`tests/test_xs/`). It depends on `mardaravicius/aoe2de_xs_converter`, a Python→XS converter; my clone of that repo failed, so it may be private [U].
- **Divy1211/PyXs** (archived 2022): Python→XS.

---

## 3. Mods and game-mode repos

### SiegeEngineers/auto-mods (cloned): reference data-mod pipeline [V]
- **URL / activity:** https://github.com/SiegeEngineers/auto-mods · 23★ · last commit 2026-10-07. Python branch; the legacy C++ version is on `master`.
- **What it is:** about 24 published data mods (Exploding Villagers, No Wall, Random Costs, Teamwork, x3/x9 Tech, and others), regenerated for every patch.
- **Layout:**
  - `auto-mod.py`: argparse CLI, `input.dat output.dat --mods a b ... [--cache] [--logfile]`;
  - `mods/*.py`: one module per mod, each exposing `NAME` and `mod(data: DatFile)`, plus `ids.py` and `util.py` helpers;
  - `dat/` (vanilla `empires2_x2_p1.dat` + `civilizations.json`), `html/`;
  - `requirements.txt` = `genieutils-py`.
- **Build:** `create-mods.sh`:
  1. `mkdir -p build/<mod>/resources/_common/dat`;
  2. runs `auto-mod.py` per mod;
  3. **copies `civilizations.json`** next to each patched dat;
  4. `cd build/<mod> && zip -r ../<mod>.zip *`, so the zip root is `resources/`.
- **Mod modules are tiny and composable:** `no_wall.mod()` calls `disable_unit(data, PALISADE_WALL)` and `disable_tech_effect(...)`, and the CLI can stack several mods in one run.
- **Deploy and release:** the zips are uploaded with the companion **SiegeEngineers/auto-mods-update** (cloned, 2023). It uses Selenium plus a cookie script to update the mods on ageofempires.com automatically (`updateMods.py`, `config.json.template`). CI only builds an HTML page (`pages.yml`, daily cron).

### Divy1211/TowerDefenceAoE2 (cloned): the closest match to your target (XS + scenario + dat, all Python-built) [V]
- **URL / activity:** https://github.com/Divy1211/TowerDefenceAoE2 · new (last commit 2026-10-13, no stars shown). Alian713's PvP TD map.
- **Layout:**
  ```
  src/
    main.py              # create_dat(out) + create_scx(out) -> mods/local/PvPTowerDefence
    datfile/build.py     # GenieDatParser: clone tower units -> new "wall" units per civ; also GENERATES DataConstants.xs
    scx/build.py, map.py, player_setup.py   # AoE2ScenarioParser.from_default(), areas, units, xs script_name
    common/*.py          # tower/tech data tables
    xs/*.xs              # TowerDefence.xs, Constants.xs, Utils.xs, Array2D.xs, Effects.xs, DataConstants.xs (generated)
  prelude/   (git submodule Divy1211/AspPrelude: Paths, XsWriter, trigger helpers)
  gdp/       (git submodule Divy1211/GenieDatParser, uv editable path dep)
  pyproject.toml / uv.lock / .python-version (3.13)
  ```
- **Build:**
  1. `uv sync`;
  2. set paths in `prelude/common_vars.py`;
  3. `$env:PYTHONPATH = ".;.\src"`;
  4. `uv run python -m main`.
- **Paths config** (`AspPrelude/common_vars.py`):
  ```python
  _USER_PROFILE_DIR = Path.home()/"Games"/"Age of Empires 2 DE"/STEAM_ID
  _INSTALL_DIR = Path(r"C:\Program Files (x86)\Steam\steamapps\common\AoE2DE")
  MODS_LOCAL_DIR = profile/"mods/local/"; SCENARIO_DIR = profile/"resources/_common/scenario/"
  XS_DIR = profile/"resources/_common/xs/"; DAT_FILE = install/"resources/_common/dat/empires2_x2_p1.dat"
  ```
  Both paths are guarded by `assert ...exists()`.
- **Deploy:** the build writes directly into `mods/local/PvPTowerDefence/resources/_common/{dat/empires2_x2_p1.dat, xs/TowerDefence/*.xs, scenario/PvPTowerDefence vX.aoe2scenario}`. It re-reads the written dat as a sanity check.
- **Dev loop:** running `scx/build.py` standalone writes `!dev_<name>.aoe2scenario` into the *profile scenario folder*, with `script_name = TowerDefenceDev\TowerDefence`. The README suggests symlinking `src/xs` to `<profile>/resources/_common/xs/TowerDefenceDev` (`mklink /D`), so XS edits are live without rebuilding. The release build rewrites `TowerDefenceDev` to `TowerDefence` inside the copied XS.
- **Codegen:** `XsWriter` emits XS constants (`extern const int cFooWall = <new unit id>;`) and a `switch` function from the dat build. Unit IDs assigned in Python therefore stay in sync with XS automatically.
- **Testing and CI:** none.

### Divy1211/perk_pandemonium_aoe2de (cloned) [V]
- https://github.com/Divy1211/perk_pandemonium_aoe2de · 3★ · last commit 2024-06. A scenario generated "from scratch" with AoE2ScenarioParser (`parser_projects/maps/perk_pandemonium.py`). Published on ageofempires.com (mod 19751). Its `common_vars.py` hardcodes the profile scenario dir.

### razakadam74/aoe2-cba-survival (cloned): best example of a tested Python build + deploy [V]
- **URL / activity:** https://github.com/razakadam74/aoe2-cba-survival · 0★ · last commit 2026-07-11. A co-op PvE survival scenario mod.
- **Layout:** `config/{balance,waves}.yaml`, `src/cba_survival/{builder,triggers,placement,layout,players,datasets,config}.py`, `scripts/{build,deploy,clean}.py`, `tests/` (pytest), `mod/` (build output), `docs/{ARCHITECTURE,DESIGN,ROADMAP}.md`, `.github/workflows/ci.yml`.
- **Build:** `scripts/build.py` runs `AoE2DEScenario.from_default()`, writes `mod/<Title>/resources/_common/scenario/<Title>.aoe2scenario`, and writes `info.json`.
- **Deploy** (`scripts/deploy.py`):
  - auto-discovers every `~/Games/Age of Empires 2 DE/<id>/mods/local`; the `AOE2_MODS_DIR` env var or `--dest` overrides it;
  - `--dry-run`;
  - deletes the old copy, then `copytree`;
  - tells the user to close the game or editor on PermissionError.
- **Tests:**
  - round-trip (build, write, `from_file`, assert trigger names and unit counts);
  - determinism (compares structure, not bytes, because the writer stamps a save time);
  - config validation.
- **CI:** a matrix over Python 3.10, 3.12 and 3.13 runs `pytest`, then a build smoke test.

### henrihallik/deadfall-aoe2 and henrihallik/exodus-aoe2 (cloned): RMS + XS mods [V]
- **URLs / activity:** https://github.com/henrihallik/deadfall-aoe2 (last commit 2026-09-05) and https://github.com/henrihallik/exodus-aoe2 (2026-09-29). 0★.
- **Layout:** `src/<name>.xs`, `tools/build.py` (stdlib only), `tests/` (Python geometry tests + `events.test.cjs`, which translates the XS to JS and runs it against mocked XS APIs), `preview/` (HTML map preview), and the committed build output `dist/<Mod>/resources/_common/{random-map-scripts/*.rms, xs/*.xs, drs/sounds/*.wem}`. Also `dist/<Mod>-x.y.z.zip`, `SHA256SUMS`, `VALIDATION.md`, `PLAYTEST.md`, `SUBMISSION.md`.
- **The RMS** starts with `#includeXS deadfall.xs`.
- **Validation:** xs-check v0.2.29, and rms-check v0.0.4 with a local patch (`tools/rms-check-de.patch` adds `#includeXS`, `behavior_version`, `override_map_size`, and others). In-game testing is listed as "Pending".
- **Install note in the README:** copy the RMS into the profile `resources\_common\random-map-scripts\` and the XS into the profile `resources\_common\xs\` "on both players' computers. Do not rely on the lobby transferring the XS file."
- **Releases:** GitHub Releases (`v0.1.0` zip).

### qferre/aoe2-xs-comm (cloned) [V]
- https://github.com/qferre/aoe2-xs-comm · last commit 2025-10-14. Python ↔ XS communication. A scenario is patched with AoE2ScenarioParser, the XS writes and reads `.xsdat`, and Python polls the file. Its config points at `C:/Users/<u>/Games/Age of Empires 2 DE/<id>/profile/<scenario>.xsdat`.

### Others found (not deeply inspected)
- MegaDusknoir/AoE2TriggerCraft2 (7★, a GUI on AoE2ScenarioParser), AoE2TriggerCraft (C++ editor, 6★).
- aoe2control/AoE2RMSIDE (5★, RMS desktop editor, active).
- Erbenos/aoe2-rms (Racket RMS DSL).
- justinas-kazanavicius/aoe2-transparent-buildings (a generated graphics mod).
- GoKuModder/AoE2_AI_Modder (knowledge base).
- babycat262/AOE2-XScript (XS examples).
- bradsmithee/EXS (Extended XS, 2022).
- Hugehugecat/AOE2SuperXS.
- Arkanosis/awesome-aoe2 (173★ curated list; links mods.aoe2.se as a mod directory).

### Not found / [U]
- I found **no public repos** for the well-known XS game modes: "Battle Royale" (an official DE mode, closed source), King of the Hill-style, "Feudal Wars", "Empire Wars", or Krakenmeister's mods. GitHub search for `aoe2 xs` returned only 12 repos, listed above. These mods are distributed as ageofempires.com uploads, not as source.

---

## 4. Windows 11 / Steam locations and in-game behaviour

| Item | Path / behaviour | Status |
|---|---|---|
| Game install (Steam default) | `C:\Program Files (x86)\Steam\steamapps\common\AoE2DE\` | [V] (UGC guide, AspPrelude) |
| Vanilla dat | `<install>\resources\_common\dat\empires2_x2_p1.dat` (auto-mods also ships `civilizations.json` alongside) | [V] |
| Built-in XS folder | `<install>\resources\_common\xs\`. It contains `Constants.xs` and `xs.txt`; **never edit `default0.xs`**, which is a temp file the game overwrites | [V] UGC guide |
| User profile root | `%USERPROFILE%\Games\Age of Empires 2 DE\<SteamID64>\` (for example `76561198…`). Steam and MS Store installs have separate number folders | [V] |
| Local mods | `<profile>\mods\local\<ModName>\` (mirrors the install tree, for example `resources\_common\dat\…`) | [V] UGC guide (hszemi) |
| Subscribed mods | `<profile>\mods\subscribed\` | [V] UGC guide |
| User scenarios | `<profile>\resources\_common\scenario\` (editor: Load Scenario → "Open Scenario Folder") | [V] AoE2ScenarioParser docs |
| User RMS | `<profile>\resources\_common\random-map-scripts\` (the install path also works) | [V] deadfall README; forum |
| User XS | `<profile>\resources\_common\xs\` (subfolders allowed, for example `xs\MyMod\main.xs`). The FE page just says "place your .xs scripts in resources\_common\xs" | [V] xslibs/XsStructs READMEs, FE page |
| XS inside a mod | `<mod>\resources\_common\xs\<sub>\*.xs`, referenced as `<sub>\file` from the scenario | [V] TowerDefenceAoE2 does this |
| `.xsdat` files | `<profile>\profile\<scenario-or-rms-name>.xsdat`; max 1 MB, per-player. In the editor the name is always `default0` | [V] aoe2-xs-comm config, FE page, XsStructs |
| Logs / crash dumps | `%USERPROFILE%\Games\Age of Empires 2 DE\logs\` (timestamped logs, `.mdmp`). Possibly also `%LOCALAPPDATA%\age2_x1\logs` | [V] official forum (enhanced-logging thread); second path [U] |

**How scenarios use XS** [V] (UGC guide, FE page)
- In the editor's Map tab, set "Script Filename" to the file name without `.xs` (a subpath is allowed).
- A trigger effect `Script Call` takes a function name such as `myFn();`. A Script Call can only call functions **without parameters**.
- `void main()` runs automatically.
- Clicking the Script Call effect in the editor turns it **green** if the script compiles. Otherwise an error popup appears; that popup is the main "compiler" feedback.
- Code written inside Script Call effects is compiled into `default0.xs`.

**How RMS uses XS** [V]
- `#includeXS file.xs` goes at the top, before `<PLAYER_SETUP>`. The path is relative to the xs folder; quote names with spaces.
- An RMS's included XS is **not reliably transferred** in lobbies, so every player needs the file. Shipping it in a mod solves this.

**Debugging** [V]
- `xsChatData("..."+v)` prints to in-game chat.
- Quirks: identical consecutive messages are de-duplicated, and a leading `0` or `1` is swallowed.
- Runtime XS errors show as an in-game error dialog or chat message. I found no XS-specific log file [U].

**Enabling a local mod** [V] (forum)
- Open the Mod Manager → "My Mods" → "Import Local Mods" if the mod is not listed.
- UI and graphics mods are toggled with a checkbox in Installed Mods.
- **Data mods are not checkbox-activated.** Pick them in the **"Data Mod" dropdown** in the lobby, skirmish or campaign setup.
- Game updates auto-disable mods. Combining a data mod with UI or content mods has been reported broken at times.

**Publishing** [V]
- In game: "My Mods" → Publish Mod (requires Xbox sign-in).
- On the web: zip the mod contents (`resources/` at the zip root) and upload at https://www.ageofempires.com/mods/create/.
- To update: edit the mod on the website, upload a new zip, and fill in the "Change List".

---

## 5. Recommended repo layout (XS + RMS + prototype scenario + Python-built data mod)

The design below borrows from TowerDefenceAoE2 (Python generates dat, scenario and XS constants into one mod tree), auto-mods (one patch module per feature), cba-survival (a tested build, a deploy script, CI) and deadfall (lint gates, `dist` zip with checksums).

```
my-aoe2-mod/
├─ pyproject.toml            # uv/pip; deps pinned: AoE2ScenarioParser==0.9.7, genieutils-py==0.1.2
├─ uv.lock
├─ mod.toml                  # name, version, author, description -> info.json
├─ config/
│  └─ paths.example.toml     # install_dir, profile_dir (copy to paths.local.toml, gitignored)
├─ src/
│  ├─ xs/                    # hand-written XS (deployed as resources/_common/xs/<ModName>/)
│  │  ├─ main.xs             # void main(), rules
│  │  ├─ lib/…               # vendored aoe2de_xslibs / XsStructs if used
│  │  └─ generated/          # gitignored or committed: ids.xs emitted by the dat build
│  ├─ rms/
│  │  └─ MyMap.rms           # first line after header: #includeXS MyMod/main.xs
│  ├─ datmod/
│  │  ├─ build.py            # parse vanilla dat -> apply patches in order -> save; emit generated/ids.xs
│  │  └─ patches/            # one module per feature: NAME + apply(dat) (auto-mods pattern)
│  └─ scenario/
│     ├─ build.py            # AoE2DEScenario.from_default() / from_file(template) + triggers
│     └─ templates/*.aoe2scenario   # optional hand-made base map
├─ build/                    # gitignored output: build/<ModName>/resources/_common/{dat,xs,scenario,random-map-scripts}, info.json
├─ dist/                     # gitignored: <ModName>-<ver>.zip (+ SHA256SUMS)
├─ scripts/
│  ├─ build.py               # orchestrates datmod -> xs copy -> rms copy -> scenario -> info.json
│  ├─ lint.ps1 / lint.sh     # xs-check src/xs/main.xs --warnings-as-errors ; rms-check --de (optional)
│  ├─ deploy.ps1             # copy or junction build/<ModName> -> mods\local\<ModName>
│  └─ package.py             # zip build/<ModName>/* (resources/ at root) for ageofempires.com
├─ tests/                    # pytest: dat round-trip, scenario round-trip, id-sync between dat & XS
└─ .github/workflows/ci.yml  # lint + pytest (+ build if a vanilla dat is available via secret/private repo)
```

**Design notes**
- **Don't commit the vanilla `.dat`.** Read it from the install, like TowerDefenceAoE2. For CI, follow genieutils-py and check the sample dats out of a private repo, or skip dat tests when the file is missing. Copy `civilizations.json` from the install next to your patched dat, as auto-mods does.
- **Emit XS constants for every new unit or tech ID** from the dat build (TowerDefenceAoE2's `XsWriter` pattern). This keeps XS and dat in sync.
- **Two scenario flavours:**
  - a *dev* copy, `!dev_<name>.aoe2scenario`, written to `<profile>\resources\_common\scenario\` with `script_name = "<ModName>Dev\main"`, which points at a junction to `src/xs`;
  - a *release* copy written into the mod with `script_name = "<ModName>\main"`.
  - Alternatively, embed XS via `xs_manager.add_script(..., validate=True)` so spectators and lobbies get it through `default0.xs`.
- **Testing a data mod:** the scenario editor and test games only use it when it is selected in the Data Mod dropdown, or when the scenario is launched from a lobby with the mod selected. That interaction is [U]; confirm it in-game.
- **Close the game before deploying.** It locks files, and dat or XS changes generally need a reload of the scenario or match [U].

### Example `scripts/deploy.ps1`
```powershell
param(
  [ValidateSet('Copy','Link')] [string]$Mode = 'Copy',
  [string]$ModName = 'MyMod',
  [string]$SteamId,                      # optional; autodetected if one profile exists
  [switch]$DevXsLink                      # also junction src\xs -> <profile>\resources\_common\xs\<ModName>Dev
)
$ErrorActionPreference = 'Stop'
$repo    = Split-Path $PSScriptRoot -Parent
$src     = Join-Path $repo "build\$ModName"
$base    = Join-Path $env:USERPROFILE 'Games\Age of Empires 2 DE'
if (-not $SteamId) {
  $ids = Get-ChildItem $base -Directory | Where-Object { $_.Name -match '^\d+$' -and (Test-Path "$($_.FullName)\mods") }
  if ($ids.Count -ne 1) { throw "Found $($ids.Count) profiles in $base; pass -SteamId" }
  $SteamId = $ids[0].Name
}
$profile = Join-Path $base $SteamId
$dest    = Join-Path $profile "mods\local\$ModName"
if (-not (Test-Path $src)) { throw "Build output missing: $src (run: uv run python scripts/build.py)" }
if (Get-Process -Name 'AoE2DE_s' -ErrorAction SilentlyContinue) { Write-Warning 'AoE2DE is running; files may be locked.' }  # process name [U]

if (Test-Path $dest) {
  $item = Get-Item $dest -Force
  if ($item.LinkType) { $item.Delete() } else { Remove-Item $dest -Recurse -Force }
}
New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
if ($Mode -eq 'Link') {
  # Junctions need no admin/Developer Mode (unlike mklink /D symlinks)
  New-Item -ItemType Junction -Path $dest -Target $src | Out-Null
} else {
  Copy-Item $src $dest -Recurse
}
if ($DevXsLink) {
  $xsDev = Join-Path $profile "resources\_common\xs\${ModName}Dev"
  if (Test-Path $xsDev) { (Get-Item $xsDev -Force).Delete() }
  New-Item -ItemType Junction -Path $xsDev -Target (Join-Path $repo 'src\xs') | Out-Null
}
Write-Host "Deployed $ModName -> $dest ($Mode). In game: Mods > My Mods (Import Local Mods if needed); select data mod in lobby 'Data Mod' dropdown."
```

### Example `info.json` (written by the build) [V format from UGC guide]
```json
{ "Author": "You", "CacheStatus": 0, "Description": "…", "Title": "MyMod v0.1.0" }
```

### Release checklist
1. Bump `mod.toml`.
2. `uv run python scripts/build.py`.
3. `scripts/lint.ps1`, which must exit 0 (`xs-check` returns 2 on errors).
4. `pytest`.
5. `scripts/deploy.ps1` and playtest in game (keep a `PLAYTEST.md`).
6. `scripts/package.py` produces `dist/MyMod-x.y.z.zip`, with `resources/` at the zip root.
7. Upload at ageofempires.com/mods/create (or Publish Mod in game). Attach the same zip to a GitHub Release.

---

## 6. Sources opened
- Repos (cloned and read): KSneijders/AoE2ScenarioParser, AoE2ScenarioRms, XsStructs, idea-xs-support; Divy1211/TowerDefenceAoE2, AspPrelude, GenieDatParser, xs-check, vsc-xs-support, rms-check, AoE2DE_UGC_Guide, perk_pandemonium_aoe2de, PyXs; SiegeEngineers/genieutils-py, auto-mods, auto-mods-update, rms-check; HSZemi/aoe2dat; mardaravicius/aoe2de_xslibs; razakadam74/aoe2-cba-survival; henrihallik/deadfall-aoe2, exodus-aoe2; qferre/aoe2-xs-comm; huongnguyen2h/AoE2ScenarioParserTutorial; mangudai/vscode; Arkanosis/awesome-aoe2.
- GitHub pages: https://github.com/topics/aoe2de, https://github.com/topics/aoe2, https://github.com/Divy1211?tab=repositories, https://github.com/orgs/SiegeEngineers/repositories, https://github.com/KSneijders?tab=repositories, and GitHub search for `aoe2 xs`, `aoe2 rms`, `aoe2 mod`, `aoe2scenarioparser`.
- PyPI JSON: genieutils-py, AoE2ScenarioParser.
- Forgotten Empires XS page: https://www.forgottenempires.net/age-of-empires-ii-definitive-edition/xs-scripting-in-age-of-empires-ii-definitive-edition
- Forums:
  - https://forums.ageofempires.com/t/how-to-publish-a-scenario-mod-i-tried-everything/64173/9
  - https://forums.ageofempires.com/t/how-do-you-create-a-installable-mod/125688
  - https://forums.ageofempires.com/t/how-to-use-the-enhanced-logging-build-to-generate-networking-logs-disconnects/101090
  - https://forums.ageofempires.com/t/xsdat-file-cannot-be-stored-in-correct-file-as-expected-for-campaigns/204962
- https://www.ageofempires.com/mods/ (JS-rendered, no listings visible). mods.ageofempires.com gave DNS ENOTFOUND.
