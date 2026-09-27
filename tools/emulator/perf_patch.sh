#!/usr/bin/env bash
# Emulator helpers (M11c review, 2026-09-27).
# Usage: perf_patch.sh apply|revert — the temporary perf-test build patch, never committed.
#   apply:  no-death (RunController.lose_life returns) and an auto-nuke at the player's
#           position whenever the swarm reaches NUKE_AT enemies (default 200; at most one
#           per 3 s), logging "NUKE en=N" so a run's PERF lines can be split around it.
#   revert: deletes every line tagged "# TEMP perf" — nothing else in the file changes,
#           so uncommitted work in run_controller.gd survives (never git checkout it).
F="$(dirname "$0")/../../godot/src/sim/run_controller.gd"
N="${NUKE_AT:-200}"
T="# TEMP perf — do not commit"
case "$1" in
  apply)
    if grep -q "# TEMP perf" "$F"; then echo "already applied"; exit 1; fi
    grep -q '^	if player.has_shield():$' "$F" || { echo "lose_life anchor missing"; exit 1; }
    grep -q '^	PerfProbe.add("s_swarm", pt_swarm)$' "$F" || { echo "swarm anchor missing"; exit 1; }
    sed -i "s/^\tif player.has_shield():\$/\tif OS.is_debug_build():  $T\n\t\treturn  $T\n&/" "$F"
    sed -i "s/^\tPerfProbe.add(\"s_swarm\", pt_swarm)\$/&\n\tif swarm.enemies.size() >= $N and elapsed - float(get_meta(\"tmp_nuke\", -99.0)) > 3.0:  $T\n\t\tset_meta(\"tmp_nuke\", elapsed)  $T\n\t\tprint(\"NUKE en=%d\" % swarm.enemies.size())  $T\n\t\tweapons.trigger_weapon(Types.WeaponType.NUKE, player.x, player.y, player, swarm.enemies, particles, grid, audio, Callable(self, \"handle_enemy_killed\"), progression.data.perks)  $T\n\t\t_on_weapon_activated(Types.WeaponType.NUKE)  $T/" "$F"
    echo "applied ($(grep -c '# TEMP perf' "$F") lines, NUKE_AT=$N)"
    ;;
  revert)
    sed -i '/# TEMP perf/d' "$F"
    echo "reverted ($(grep -c '# TEMP perf' "$F") tagged lines left)"
    ;;
  *) echo "usage: $0 apply|revert"; exit 2 ;;
esac
