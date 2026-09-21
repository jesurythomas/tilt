# HUD score feedback — design

**Status:** approved by the user 2026-09-21 (three answered questions, recorded
in §2). Numbered "HUD-FEEDBACK" so `DIVERGENCE(HUD-FEEDBACK §n)` tags resolve.

## 1. Problem

The web game (`ScoreManager.ts:102-131`) spawns floating text at the point an
enemy dies: `Nx MULTIPLIER!` every eighth combo kill and the combo callouts
`TRIPLE!` / `MULTI KILL!` / `MEGA KILL!` / `UNBELIEVABLE!` / `HOLY CRAP!`. On the
phone, with M3's roster and M4's area weapons, dozens of kills land in a
frame and the callouts pile up where the action is. The user asked for the
feedback to move to the score block instead.

This is a deliberate divergence from the port (LAW 2/4); every changed line
carries a `DIVERGENCE(HUD-FEEDBACK §n)` tag.

## 2. Decisions

| # | Decision | Chosen |
|---|---|---|
| D1 | Which kill-site texts go | All kill-related: `Nx MULTIPLIER!` and the five combo callouts. **`CLOSE CALL! +N` stays** — it happens at the ship, not at a kill. The milestone *sounds* (`play_milestone`) stay. |
| D2 | What the HUD does on a kill | The score label **pulses** (scales up briefly) and **flashes the tier colour**, then settles back to white. The `Nx` multiplier label sits **permanently in the tier colour**. |
| D3 | Colour tiers | Five, by `stats.multiplier`: 1x white · 2–4x yellow · 5–9x orange · 10–19x magenta · 20x+ cyan. Neon palette. |

## 3. Sim side (`src/sim/score_manager.gd`)

`register_kill()` no longer calls `add_floating_text` for the multiplier or
the combo callouts (D1). The `combo_count` branches that play
`audio.play_milestone()` keep playing it. `add_floating_text` itself,
`floating_texts`, its update loop and `register_close_call` are unchanged —
the effect layer still draws close calls.

No other sim file changes. `GameEvents` gains no signal: `enemy_killed` and
`score_changed` already carry everything the HUD needs (spec §5.3).

## 4. HUD side (`src/ui/hud_controller.gd`)

- `static func tier_color_for(multiplier: int) -> Color` implements D3:
  `TIER_WHITE = Color.WHITE`, `TIER_YELLOW = Color("#ffe14d")`,
  `TIER_ORANGE = Color("#ffb14d")`, `TIER_MAGENTA = Color("#ff3fd1")`,
  `TIER_CYAN = Color("#3dfff0")`; thresholds 2, 5, 10, 20.
- `_on_score_changed` additionally sets `_multiplier_label.modulate` to the
  tier colour (D2).
- `_on_enemy_killed(enemy, weapon_type)` (connected to
  `GameEvents.enemy_killed`) triggers the pulse: a `Tween` on the score label
  from `scale = Vector2(PULSE_SCALE, PULSE_SCALE)` (`1.18`) back to `ONE` and
  `modulate` from the current tier colour back to `TIER_WHITE`, both over
  `PULSE_SECONDS = 0.22`, `Tween.TRANS_QUAD` / `EASE_OUT`. A kill during a
  running pulse kills the old tween and restarts (so mass kills read as a
  sustained glow, not a stack of tweens). `pivot_offset` is set to the
  label's centre in `set_ui_scale()` so the scale is about the centre.
- Tier for the pulse comes from the last `score_changed` multiplier
  (`_current_multiplier`), not from the kill signal, so both handlers agree.
- Nothing runs while paused: `Tween` uses `TWEEN_PAUSE_PROCESS` default
  (pauses with the tree); no other change.

Constants above are provisional until seen on the A55; `VERIFY-ME.md` gets a
line.

## 5. Tests

- `tests/test_score_manager.gd`: the multiplier test asserts
  `floating_texts.size() == 0` after the eighth kill (was `> 0`); a new spec
  asserts the combo milestones spawn no text while `CLOSE CALL!` still does.
- `tests/test_hud_controller.gd`: `tier_color_for` at 1, 2, 4, 5, 9, 10, 19,
  20, 50; the multiplier label's `modulate` after a `score_changed` at 7x;
  after `enemy_killed` the score label's `scale.x > 1.0` and `modulate` is the
  tier colour, and after `PULSE_SECONDS + 0.05` s of frames both are back to
  `ONE` / white.

## 6. Out of scope

Removing close-call text; changing scoring, combo timing or audio; the effect
layer's text renderer (still needed for close calls).
