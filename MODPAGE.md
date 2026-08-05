# Punishing Death — mod-page copy

Paste/adapt this when you update the Nexus Mods, CurseForge, or Steam Workshop
page. Sections are labeled; most upload forms have separate fields for Summary,
Description, etc.

---

## Name
Punishing Death

## Version
2.1.0

## Short summary (one line)
Die and you lose ~10% of your total EXP — enough to drop a level and strip that level's tech and stat points. Exploit-proof.

## Description

**Death should cost something.** In vanilla Palworld, dying is barely an
inconvenience. Punishing Death makes it hurt: when you die, you lose a flat
share of your **total earned EXP** (10% by default).

In the early game that's just a dent in your progress. But in the mid-to-late
game, 10% of your total is roughly a level's worth — so **you drop a level** —
and when you do, that level's rewards come with it:

- **Technologies** unlocked at the level you lost are **re-locked** (they vanish
  from your tech tree and build menu until you earn the level back).
- The **technology points** that level granted are removed.
- One **stat point** per level lost is removed — an unspent point if you have
  one, otherwise a point is docked from a stat you've already allocated.

### Isn't de-leveling exploitable?
It would be — if you got to keep the rewards. Palworld re-grants tech and stat
points when you level up, so a mod that *only* lowered your level would let you
farm points by dying. Punishing Death closes that hole by **stripping exactly
what the level gave you**: when you re-earn the level, the game re-grants the
points and you re-buy the techs, netting to **zero**. Death is always a loss,
never a gain. (Full breakdown in DESIGN_NOTES.md, included in the download.)

### Features
- Lose a configurable share of your **total** EXP on every death (default 10%).
- Natural de-leveling with full, exploit-proof reward stripping (techs + tech
  points + stat points).
- On-screen notice: *"\<name\> died and lost N EXP."*
- Reads the level curve and tech costs live from the game, so extended-level-cap
  and tech mods work automatically.
- **Fires on respawn, so being revived is free.** A second-life passive (e.g.
  Herbil), a downed teammate getting picked up in multiplayer, or any in-place
  revive doesn't count as a death — you only pay when you actually respawn.
- Lightweight: an event-driven respawn hook, no polling and no per-frame work.

### Configuration
Open `Scripts/main.lua` and edit the top:
- `total_loss_fraction`
  - `0.05` — lose 5% of total EXP per death (gentler)
  - `0.10` — lose 10% (default; ≈ one level in mid/late game)
  - `0.20` — lose 20% (brutal; can drop more than one level)
- `show_message` — `true` to broadcast the death notice, `false` to silence it.

## Requirements
- **UE4SS** (RE-UE4SS) installed for Palworld.
- Works in single-player and has been run on dedicated servers by players.

## Installation
1. Install UE4SS for Palworld if you haven't.
2. Extract this download so the `PunishingDeath` folder sits in your UE4SS
   `Mods` folder, e.g.:
   `Palworld\...\ue4ss\Mods\PunishingDeath\`
3. Enable it. Most UE4SS builds auto-enable via the included `enabled.txt`.
   If your setup uses `mods.txt`, add this line:
   `PunishingDeath : 1`
4. Launch the game.

### Updating from 1.x
Just replace the old `PunishingDeath` folder with this one. **Note the mechanic
changed:** 1.x drained in-level progress and never de-leveled; 2.0 loses total
EXP and de-levels with reward stripping. If you preferred the old behavior, keep
using 1.x.

## Compatibility
- PC (Steam) build with UE4SS. **Does not work** on the Xbox / Microsoft Store
  (Game Pass) version or on consoles.
- Plays nice with other UE4SS Lua mods.

## Multiplayer note
On a dedicated server the death notice is a system announce, so **all players
see it** ("PlayerX died and lost N EXP"). Set `show_message = false` if you'd
rather keep deaths private. Reviving a downed teammate (rather than letting them
respawn) spares them the penalty — it only lands on an actual respawn.

## Known minor issue
After a de-level, the level number on the HUD may not repaint until you level up
again or re-open a menu — the actual level, EXP, techs, and points all update and
save immediately.

## Credits
Created by <your name/handle>.
