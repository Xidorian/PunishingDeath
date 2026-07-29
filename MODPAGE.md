# Punishing Death — mod-page copy

Paste/adapt this when you create the Nexus Mods or CurseForge page. Sections are
labeled; most upload forms have separate fields for Summary, Description, etc.

---

## Name
Punishing Death

## Version
1.0.0

## Short summary (one line)
Die and you lose progress toward your next level — a fair, exploit-proof death penalty.

## Description

**Death should cost something.** In vanilla Palworld, dying is barely an
inconvenience. Punishing Death adds a real setback: when you die, you lose part
of your EXP progress **toward your next level**.

Crucially, your **level number never drops**. Only the EXP *inside* your current
level is drained — down to, at most, the start of that level.

### Why no de-leveling?
Because it would be exploitable. If a mod lowered your level, Palworld re-grants
status and technology points when you level back up — meaning you could *gain*
points by dying on purpose. That's the opposite of a punishment. By keeping your
level fixed and only draining in-level progress, this mod is **impossible to
farm**: death is always a loss, never a gain. (A full breakdown of the tested
approaches is in DESIGN_NOTES.md, included in the download.)

### Features
- Lose a configurable share of your current-level progress on every death.
- Level number, unlocked technologies, and allocated stats are never touched.
- Reads the level curve live from the game, so extended-level-cap mods work
  automatically.
- Lightweight: a single low-frequency death check, no per-frame work.

### Configuration
Open `Scripts/main.lua` and edit the top:
- `progress_loss_fraction`
  - `0.25` — lose a quarter of your progress toward the next level
  - `0.50` — lose half (default)
  - `1.00` — every death sends you back to the START of your current level

## Requirements
- **UE4SS** (RE-UE4SS) installed for Palworld.
- Single-player / client (host-and-play). Not tested on dedicated servers.

## Installation
1. Install UE4SS for Palworld if you haven't.
2. Extract this download so the `PunishingDeath` folder sits in your UE4SS
   `Mods` folder, e.g.:
   `Palworld\...\ue4ss\Mods\PunishingDeath\`
3. Enable it. Most UE4SS builds auto-enable via the included `enabled.txt`.
   If your setup uses `mods.txt`, add this line:
   `PunishingDeath : 1`
4. Launch the game.

## Compatibility
- PC (Steam) build with UE4SS. **Does not work** on the Xbox / Microsoft Store
  (Game Pass) version or on consoles.
- Play-nice with other UE4SS Lua mods.

## Known minor issue
The on-screen EXP bar may not repaint until you re-open the character menu; the
value updates and saves immediately.

## Credits
Created by <your name/handle>.
