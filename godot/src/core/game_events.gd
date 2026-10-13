## game_events.gd
## PORTS: web/src/tilt-to-live/TiltGame.ts (direct DOM reaches to signals), per spec §5.3
# PORT-NOTE: no `class_name`, against CONVENTIONS §2. An autoload script cannot
# carry one: `class_name GameEvents` shadows the `GameEvents` singleton and causes
# Nil base resolution. Same as Log in src/core/log.gd.
extends Node
## Global event bus for simulation-to-UI and simulation-to-audio signals.
##
## Standing rule (spec §5.3): signals are sim→UI and sim→audio only. Never sim→sim.
## Simulation systems keep direct references and Callable callbacks.

## Emitted when score, multiplier, or best score changes.
signal score_changed(score: int, multiplier: int, best_score: int)

## Emitted when an enemy is destroyed.
signal enemy_killed(enemy: PerilEnemy, weapon_type: Types.WeaponType)

## Emitted when a weapon orb is collected and activated.
signal weapon_activated(weapon_type: Types.WeaponType)

## Emitted when the player loses a life.
signal life_lost(lives_remaining: int)

## Emitted on a near miss. DIVERGENCE(MVP Week 1): no TS counterpart; Haptics listens.
signal close_call

## Emitted when the ship dashes. DIVERGENCE(DASH R2): no TS counterpart; Haptics listens.
signal dash_activated

## Emitted when a run finishes on player death.
signal run_ended(final_score: int, stats: Types.GameStats)

## Emitted when an in-run or cumulative goal is completed.
signal goal_completed(goal_id: String)

## Emitted when total points currency updates.
signal points_changed(total_points: int)

## Emitted when the game phase changes.
signal phase_changed(new_phase: Types.GamePhase)
