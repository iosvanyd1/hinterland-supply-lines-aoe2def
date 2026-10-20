# Playtest log

Record every in-game test here, newest first. Test IDs are from [research/TECHNICAL_UNKNOWNS.md](research/TECHNICAL_UNKNOWNS.md).

## Template

```
### YYYY-MM-DD — T<n> <short name>
- Build: <git commit>, game build <number from main menu>
- Setup: scenario editor / skirmish, map, data mod on/off, players
- Steps:
- Expected:
- Observed: (include chat / error text)
- Result: pass / fail / partial
- Follow-up:
```

## Smoke test (after every build)

- [ ] Game starts with the data mod selected, no "wrong data file" error
- [ ] HinterlandArabia is listed under Custom maps
- [ ] No XS error dialog at game start
- [ ] A Barracks built far from the TC shows a "Supply Ns" caption counting down
- [ ] Supply Cart is trainable at the Palace after reaching Castle Age

## Log

## Test 2

```
### 2026-10-14 — T<n> <short name>
- Build: <git commit>, game build <number from main menu>
- Setup: skirmish, HinterlandArabia, data mod on, 6 players
- Steps:
- Expected: Supply carts to appear at the TC at castle age.
- Observed: No supply carts button appears at TC after reaching castle age.
- Result: fail
- Follow-up:
```

## Smoke test (after every build)

- [v] Game starts with the data mod selected, no "wrong data file" error
- [v] HinterlandArabia is listed under Custom maps
- [v] No XS error dialog at game start
- [v] A Barracks built far from the TC shows a "Supply Ns" caption counting down
- [v] Supply Cart is trainable at the TC after reaching Castle Age

## Log

"Supply Ns" countdown and unselectable "Out of Supply" work. Buildings within reach of the TC and fully supplied do not have the "Supply Ns" above them, as expected.
The Supply cart button appear at the TC at Castle Age, or Emperial Age (at the middle row, right most column slot).
When a building’s supply runs out, it becomes unselectable. Hotkeys don't select it either. However it continues to produce already queued units. It does not cancel queue or refund resources.
Supply carts are resupplying the buildings as expected. However they have the same look, name, stats and properties as trade carts, making them impossible to distinguish. They do not return back to the TC and back to the building automatically.
TCs do not show accurate aura radius limit for which they auto supply buildings. Seems like buildings can still be supplied if they are a few squares outsie of the radius.

## Test 1

```
### 2026-10-14 — T<n> <short name>
- Build: <git commit>, game build <number from main menu>
- Setup: skirmish, HinterlandArabia, data mod on, 6 players
- Steps:
- Expected: Supply carts to appear at the TC at castle age.
- Observed: No supply carts button appears at TC after reaching castle age.
- Result: fail
- Follow-up:
```

## Smoke test (after every build)

- [v] Game starts with the data mod selected, no "wrong data file" error
- [v] HinterlandArabia is listed under Custom maps
- [v] No XS error dialog at game start
- [v] A Barracks built far from the TC shows a "Supply Ns" caption counting down
- [x] Supply Cart is trainable at the TC after reaching Castle Age

## Log

T1: "Supply Ns" countdown and unselectable "Out of Supply" work. Buildings within reach of the TC and fully supplied should not have the "Supply Ns" above them.
T5: No Supply cart button appear at the TC at Castle Age, or Emperial Age.
T7: When a building’s supply runs out, it becomes unselectable. Hotkeys don't select it either. However it continues to produce already queued units. It should not.
T8: Unable to resupply due to lack of supply carts.