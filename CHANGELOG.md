# Changelog — Punishing Death

## [Unreleased]

**Fixed**
- **Revives no longer trigger the penalty.** The penalty now fires on the
  player's **respawn**, not on the death instant. A Herbil second-life (and any
  in-place revive, incl. multiplayer ally-revive) takes a separate engine path,
  so a revived player keeps all their EXP — previously they were docked for a
  death they never actually completed.

**Changed**
- **Trigger reworked from death-detection to respawn.** Replaced the `IsDead`
  poll (`LoopAsync`) with a hook on `PalPlayerCharacter:CallRespawnDelegate`,
  which fires only on a real death→respawn — not on revive, fast travel, statue
  warp, or load-in. Deterministic (event-driven, no 2s poll race) and lower
  overhead. Penalty math is unchanged; it now applies to the full pre-death EXP.

## 2.0.0
A full rework of the penalty. 1.x drained your in-level EXP and never touched
your level; 2.0 makes death cost a level's worth of progress — and strips that
level's rewards — while staying exploit-proof.

**Changed**
- On death you now lose a flat fraction of your **total earned EXP** (default
  **10%**), instead of a fraction of current-level progress. In the mid-to-late
  game that is roughly one level, so you **drop a level**.
- Config `progress_loss_fraction` → **`total_loss_fraction`** (default `0.10`).

**Added**
- **De-leveling with exploit-proof reward stripping.** When you lose a level:
  - technologies unlocked at that level are **re-locked** (they leave the tech
    tree and build menu until you re-earn the level);
  - that level's **technology points** are removed — with the stripped techs'
    point cost refunded, so re-buying them nets to zero;
  - one **stat point** per level lost is removed (an unspent point first,
    otherwise a point is docked from a stat you've allocated).
- **On-screen death notice:** *"\<name\> died and lost N EXP."* — new
  `show_message` option (on by default). On dedicated servers this is a system
  announce visible to all players.
- Confirmed working on **dedicated servers** (community-tested).

**Why it's still exploit-proof**
Re-earning the lost level re-grants exactly what was stripped, and you re-buy the
techs with the refunded points — so death → recover nets to **zero**. You can't
farm points by dying.

**Known minor issue**
After a de-level the HUD level number may not repaint until you level up again or
open a menu; the actual level, EXP, techs, and points update and save immediately.

## 1.0.0
- Initial release. On death, drain a configurable share of your current-level
  EXP progress toward the next level. Level number, technologies, and stats are
  never touched — exploit-proof by never de-leveling.
