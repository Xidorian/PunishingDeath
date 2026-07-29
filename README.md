# Punishing Death (Palworld / UE4SS)

**When you die, you lose ~10% of your total EXP** — in the mid/late game that's
about a level, so you **drop a level** and lose that level's rewards with it:
its unlocked technologies re-lock, its technology points are removed, and a stat
point is docked.

It stays **exploit-proof**: re-earning the level re-grants exactly what was
stripped (and you re-buy the techs with the refunded points), so a
death→recover cycle nets to zero — you can never farm points by dying. See
`DESIGN_NOTES.md` for how the de-leveling was made safe, and `CHANGELOG.md` for
what changed from 1.x.

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
- `total_loss_fraction` — fraction of TOTAL EXP lost per death:
  - `0.05` = 5% (gentler)
  - `0.10` = 10% (default; ≈ one level mid/late game)
  - `0.20` = 20% (can drop more than one level)
- `show_message` — `true` broadcasts "\<name\> died and lost N EXP" (a system
  announce; on a dedicated server all players see it). `false` silences it.
- `poll_ms` — how often the death check runs (default 2000 ms).
- `enable_test_keys` — set `false` for a clean release (default false).

Edits hot-reload live if UE4SS auto-reload is on.

## What triggers it / what doesn't
- TRIGGERS: any real death (fall, damage, lava, drowning, etc.).
- DOES NOT trigger: fast travel, opening menus/map, low HP without dying, or
  the brief load state at login.

## Test keys (only if `enable_test_keys = true`)
- `F9` — apply the death penalty now (no dying needed).
- `F1` — force exactly one level down (to test the de-level at any level).
- `F3` — dry-run: print what a death would strip, without changing anything.

## Compatibility
- Works on the PC (Steam) build with UE4SS. Does NOT work on the Xbox / Microsoft
  Store (Game Pass) version or on consoles.
- Community-tested on dedicated servers.
- Reads the level curve and tech costs live, so extended-level-cap and tech mods
  are handled automatically.

## Known minor issue
After a de-level the top-left HUD level number may not repaint until you level up
again or open a menu. The level, EXP, techs, and points are all correct and saved
immediately — only the HUD widget lags.
