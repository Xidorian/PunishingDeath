# Punishing Death — Design Notes & Attempt Log

Goal: make death **cost** something, to make the game harder. Anything that
lets a player come out *ahead* by dying is a failure of the design.

## Final design (shipped): no-de-level "progress loss"
On death, drain part of the player's EXP progress **within the current level**,
down to at most the start of that level. **The level number never changes.**

- `progress_loss_fraction` controls severity (0.50 = lose half your progress
  toward the next level; 1.00 = back to the start of the current level).
- Exploit-free by construction: no level change → the game never re-grants
  status/technology points → nothing to farm.
- No HUD desync: the level number is never wrong, so the top-left HUD and the
  character sheet always agree.

Implementation touches only `SaveParameter.Exp` (via the individual character
parameter). Level curve is read live from `DT_PalExpTable.TotalEXP`.

## What we tried first: de-leveling (abandoned)
Original idea: lose a % of TOTAL exp and recompute the level downward for a
"hardcore" feel. It worked mechanically but opened a serious exploit and a
display bug, both rooted in the same cause.

### Root cause
We change the level by writing `SaveParameter.Level` directly. That bypasses
the game's internal level-change event, so systems that react to level changes
never run.

### Consequence 1 — point-farm exploit (the dealbreaker)
Leveling up grants status points and technology points. De-leveling by direct
write does NOT remove them. Measured on a real 44→45 re-level:
`TechPt 14→17, BossTechPt 24→25, UnusedStatusPoint 0→1`. So a player could die,
re-level, and pocket free points every cycle — most dangerous at max level,
where points are otherwise capped. This is the exact opposite of a punishing
mod, so de-leveling had to go.

### Attempts to fix the exploit (all failed)
1. **Single-shot clawback** — after a re-level into already-earned territory,
   write the point counters back down. Failed: the engine re-grants the points
   a frame *after* our write (timing race). Result stayed inflated (14→17).
2. **Enforcement window** — keep re-writing the counters down for ~4s to outlast
   the grant. Failed for a different reason: the `TechnologyData` object
   (reached via PlayerState) did not reliably resolve at the moment of the
   level-up, so the clawback silently no-op'd. Result leaked worse (17→24).
3. **Trigger the game's own reconcile** — call
   `PalTechnologyData:OnUpdateLocalPlayerLevel()` to make the game recompute
   points for the new level. Failed: no effect on the point totals, and did not
   refresh the HUD either.
4. **Full rollback** (remove allocated stats, re-lock purchased techs) — not
   attempted; judged unsafe. There is no clean "re-lock technology" API,
   techs have prerequisite chains, and the game itself keeps unlocks after a
   de-level (confirmed: a de-leveled character could still build L45 tech). The
   game doesn't track stat-allocation order either, so "undo the last stat" has
   nothing to key on.

### Consequence 2 — HUD level desync
After a direct de-level the top-left HUD kept showing the old level (with a
mis-scaled XP bar) while the character sheet showed the new one. Same root
cause; the reconcile call above did not fix it.

## Verdict
De-leveling cannot be made both correct and robust from Lua without fighting the
engine on every level-up. The no-de-level design removes the level change
entirely, which removes the exploit, the clawback complexity, and the HUD bug
in one move — and still punishes death by erasing progress. Aligns with the
goal; ships.
