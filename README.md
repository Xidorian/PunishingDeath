# Punishing Death (Palworld / UE4SS)

Single-player mod: **when you die, you lose part of your progress toward the
next level.** Your level number never drops — only the EXP inside your current
level is drained (down to at most the start of that level).

This is deliberately exploit-proof: because your level never changes, dying can
never trick the game into re-granting status/technology points. Making death a
loss — never a gain — is the whole point. See `DESIGN_NOTES.md` for the
approaches we tried and rejected (including full de-leveling and why it failed).

## Install
Copy the `PunishingDeath` folder into your UE4SS Mods folder:
```
Palworld\Mods\NativeMods\UE4SS\Mods\PunishingDeath\
  enabled.txt
  Scripts\main.lua
```
Then enable it in `...\UE4SS\Mods\mods.txt` with a line:
```
PunishingDeath : 1
```

## Configure (top of Scripts/main.lua)
- `progress_loss_fraction` — severity per death:
  - `0.25` = lose a quarter of your progress toward the next level
  - `0.50` = lose half (default)
  - `1.00` = every death throws you back to the START of your current level
- `poll_ms` — how often the death check runs (default 1000 ms).
- `enable_test_keys` — set `false` for a clean release (removes F9/F7/F10).

Edits hot-reload live if UE4SS auto-reload is on.

## What triggers it / what doesn't
- TRIGGERS: any real death (fall, damage, lava, drowning, etc.).
- DOES NOT trigger: fast travel, opening menus/map, low HP without dying, or
  the brief load state at login.

## Test keys (on foot; only if `enable_test_keys = true`)
- `F9` — apply the penalty now (no dying needed).
- `F7` — restore your EXP to the snapshot taken before the first penalty.
- `F10` — print level/EXP to the UE4SS log.

## Compatibility
- Works on the PC (Steam) build with UE4SS. Does NOT work on the Xbox / Microsoft
  Store (Game Pass) version or on consoles.
- Reads the level curve live from `DT_PalExpTable`, so extended-level-cap mods
  are handled automatically.

## Known minor issue
The on-screen EXP bar may not repaint until you re-open the character sheet;
the underlying value updates and saves immediately. (Your level number is always
correct — that was a de-leveling problem, which this design avoids.)
