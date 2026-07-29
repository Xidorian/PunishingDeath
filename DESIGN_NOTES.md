# Punishing Death — Design Notes & Attempt Log

Goal: make death **cost** something, to make the game harder. Anything that lets
a player come out *ahead* by dying is a failure of the design.

## Final design (shipped, 2.0): de-level + reward stripping
On death, lose a flat fraction of **total earned EXP** (`total_loss_fraction`,
default 0.10). The level is recomputed from the new EXP against the live curve,
so in the mid/late game you **drop a level**. When you lose a level, that level's
rewards are stripped so the drop can't be farmed:

- **Technologies** with a `LevelCap` above the new level are re-locked.
- **Technology points**: `newUnused = max(0, unused + stripCost − 6 × levelsLost)`
  — remove the level's grant (6/level) but refund the stripped techs' point cost.
- **Stat points**: one per level lost — an unspent point if available, else a
  point is docked from a randomly chosen allocated stat.

**Exploit-safety.** Re-earning the level re-grants exactly what was stripped, and
you re-buy the techs with the refunded points, so a death→recover cycle nets to
**zero**. The refund term is what makes it exact: strip more than 6 points of
techs and the surplus is returned; strip less and only the difference is removed.

This is the "hardcore" approach the 1.x notes below judged impossible. It became
possible once three engine levers were found (see next section).

## How the 1.x blockers were solved
1.x abandoned de-leveling for two reasons — a point-farm exploit and a HUD
desync — both rooted in writing `SaveParameter.Level` directly (which bypasses
the level-change event). 2.0 keeps the direct write but neutralizes the fallout:

- **Point-farm exploit → fixed by stripping.** Leveling re-grants points; 1.x
  never removed them, so dying was a net gain. 2.0 removes exactly the level's
  grant on the way down (with the tech-cost refund above), so the re-grant on the
  way up is a wash, not a profit.
- **"No clean re-lock API" (1.x attempt #4, judged unsafe) → solved.** Rebuild
  `PalTechnologyData.UnlockedTechnologyNameArray` (read the names, `:Empty()`,
  re-add the keepers by indexed assignment) then call
  `OnRep_UnlockedTechnologyNameArray()` — this re-locks the tech in the tree AND
  removes its recipe from the build menu. Each tech's level and point cost come
  from `GetTechlonogyBaseData(FName(name))` (`.LevelCap`, `.Cost`).
- **"Can't undo a stat" → solved.** Status points are keyed by (Japanese) FName;
  read the live list via `GetStatusPointList`, then `SetStatusPoint(name, val−1)`
  reduces an allocated stat without refunding it. Unspent points use
  `DecrementUnusedStatusPoint`.

## Known minor issue (accepted)
After a de-level the top-left HUD level number may not repaint until you level up
again or open a menu. The stored level, EXP, techs, and points are all correct
and saved immediately; only the HUD widget lags. `OnUpdateLocalPlayerLevel()`
does not refresh it, and chasing a clean HUD refresh wasn't worth blocking the
release. If you know the widget-refresh call, PRs/notes welcome.

## History: 1.x "no-de-level progress loss"
1.0 shipped the safe-but-milder design: drain EXP **within** the current level
only, never changing the level number. That sidestepped the exploit and HUD bug
entirely by never de-leveling. It's still a valid, gentler penalty — if you
prefer it, keep using 1.x. 2.0 supersedes it with the true de-level mechanic now
that the blockers are solved.
