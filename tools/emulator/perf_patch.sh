#!/usr/bin/env bash
# Emulator helpers (M11c review, 2026-09-27).
# Usage: perf_patch.sh apply|revert — the temporary perf test mode, never committed.
#   apply:  (1) no-death: RunController.lose_life returns;
#           (2) test mode (user, 2026-09-27: "a test mode which just spawns faster and
#               trigger different power ups between intervals"): seeker spawns at
#               least every 0.12 s and formations every 2 s (FAST_SPAWN=0: off), and
#               every POWER_EVERY s (default 3) the next power-up in POWERS (default
#               all seven, in order) fires at the ship, logging "POWER <NAME> en=N"
#               (tools/emulator/power_fps.sh reads it);
#           (3) an on-screen readout (GameRoot): FPS, frame ms, enemy count, and the
#               power-up's name for 2 s after it fires;
#           (4) autopilot: the ship steers around a square centred on the arena.
#           Then compiles both scripts (warnings are errors: a parse error breaks the
#           whole game on device) and reverts itself if they do not compile.
#   revert: deletes every line tagged "# TEMP perf" — nothing else changes, so
#           uncommitted work in these files survives (never git checkout them).
D="$(dirname "$0")"
R="$D/../../godot/src/sim/run_controller.gd"
GR="$D/../../godot/src/core/game_root.gd"
EVERY="${POWER_EVERY:-3.0}"
POWERS="${POWERS:-NUKE MISSILES LIGHTNING LASER VORTEX FREEZE SHIELD}"
FAST="${FAST_SPAWN:-1}"
G="${GODOT:-/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
case "$1" in
  apply)
    if grep -q "# TEMP perf" "$R" "$GR"; then echo "already applied"; exit 1; fi
    python - "$R" "$GR" "$EVERY" "$POWERS" "$FAST" <<'PY' || exit 1
import sys
rc, gr, every, powers, fast = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].split(), sys.argv[5] == "1"
T = "  # TEMP perf — do not commit"

def patch(path, anchor, lines, before=False):
    s = open(path, encoding="utf-8").read()
    if s.count(anchor) != 1:
        sys.exit("anchor missing or ambiguous in %s: %r" % (path, anchor))
    block = "".join(l + T + "\n" for l in lines)
    # Anchors begin with "\n": a block that goes before one goes after that newline.
    s = s.replace(anchor, "\n" + block + anchor[1:] if before else anchor + block)
    open(path, "w", encoding="utf-8", newline="").write(s)

# (1) no-death. Anchors start with "\n" so an indented copy of the line never matches.
patch(rc, "\n\tif player.has_shield():\n", [
    "\tif OS.is_debug_build():",
    "\t\treturn",
], before=True)

# (2) faster spawns and the power-up cycle, right after the swarm step.
lines = []
if fast:
    lines += [
        "\tswarm._spawn_timer = minf(swarm._spawn_timer, 0.12)",
        "\tswarm._wave_timer = minf(swarm._wave_timer, 2.0)",
    ]
plist = ", ".join("Types.WeaponType." + p for p in powers)
lines += [
    '\tvar tmp_pow_t: float = get_meta("tmp_pow_t", 0.0)',
    "\tif elapsed - tmp_pow_t >= %s:" % every,
    '\t\tset_meta("tmp_pow_t", elapsed)',
    "\t\tvar tmp_list: Array[Types.WeaponType] = [%s]" % plist,
    '\t\tvar tmp_k: int = get_meta("tmp_pow_k", 0)',
    '\t\tset_meta("tmp_pow_k", tmp_k + 1)',
    "\t\tvar tmp_w: Types.WeaponType = tmp_list[tmp_k % tmp_list.size()]",
    "\t\tvar tmp_name: String = Types.WeaponType.keys()[tmp_w]",
    '\t\tEngine.set_meta("tmp_pow_ms", Time.get_ticks_msec())',
    '\t\tEngine.set_meta("tmp_pow_name", tmp_name)',
    '\t\tprint("POWER %s en=%d" % [tmp_name, swarm.enemies.size()])',
    "\t\tweapons.trigger_weapon(tmp_w, player.x, player.y, player, swarm.enemies, particles, grid, audio, Callable(self, \"handle_enemy_killed\"), progression.data.perks)",
    "\t\t_on_weapon_activated(tmp_w)",
]
patch(rc, '\n\tPerfProbe.add("s_swarm", pt_swarm)\n', lines)

# (3) on-screen readout.
patch(gr, "\nfunc _process(_delta: float) -> void:\n", [
    '\tvar tmp_l: Label = get_node_or_null("CanvasLayer/TmpFps") as Label',
    "\tif tmp_l == null:",
    "\t\ttmp_l = Label.new()",
    '\t\ttmp_l.name = "TmpFps"',
    "\t\ttmp_l.position = Vector2(150.0, 40.0)",
    '\t\ttmp_l.add_theme_font_size_override("font_size", 44)',
    '\t\ttmp_l.add_theme_constant_override("outline_size", 12)',
    '\t\ttmp_l.add_theme_color_override("font_outline_color", Color.BLACK)',
    "\t\t$CanvasLayer.add_child(tmp_l)",
    '\tvar tmp_pow_ms: int = Engine.get_meta("tmp_pow_ms", -100000)',
    '\tvar tmp_pow_name: String = Engine.get_meta("tmp_pow_name", "")',
    '\tvar tmp_tag: String = ("   " + tmp_pow_name + "!") if Time.get_ticks_msec() - tmp_pow_ms < 2000 else ""',
    '\ttmp_l.text = "%d FPS  %.0f ms  %d enemies%s" % [Engine.get_frames_per_second(), get_process_delta_time() * 1000.0, _swarm.enemies.size(), tmp_tag]',
])

# (4) autopilot: the ship steers around a square (half side = 0.3 x the short side)
# centred on the arena, next corner within 40 px — closed loop, so it never drifts.
patch(gr, "\n\t_run_controller.update(\n\t\tdt, effective_mode,", [
    "\tvar tmp_b: Vector2 = _run_controller.bounds",
    "\tvar tmp_h: float = minf(tmp_b.x, tmp_b.y) * 0.3",
    "\tvar tmp_i: int = get_meta(\"tmp_wp\", 0)",
    "\tvar tmp_wp: Vector2 = tmp_b * 0.5 + Vector2(-tmp_h if tmp_i == 0 or tmp_i == 3 else tmp_h, -tmp_h if tmp_i < 2 else tmp_h)",
    "\tvar tmp_to: Vector2 = tmp_wp - Vector2(_player.x, _player.y)",
    "\tif tmp_to.length() < 40.0:",
    "\t\tset_meta(\"tmp_wp\", (tmp_i + 1) % 4)",
    "\teffective_mode = Types.ControlMode.GYRO",
    "\tdirectional = tmp_to.normalized() * TOUCH_JOYSTICK_SPEED_SCALE",
], before=True)
PY
    echo "applied ($(cat "$R" "$GR" | grep -c '# TEMP perf') lines; every ${EVERY}s: $POWERS; fast spawn $FAST)"
    OUT="$("$G" --headless --path "$D/../../godot" -s addons/gut/gut_cmdln.gd \
      -gtest=res://tests/test_run_controller.gd,res://tests/test_game_state_machine.gd -gexit 2>&1)"
    if echo "$OUT" | grep -q "SCRIPT ERROR"; then
      echo "$OUT" | grep "SCRIPT ERROR" | head -3
      echo "PATCH DOES NOT COMPILE — reverted"; sed -i '/# TEMP perf/d' "$R" "$GR"; exit 1
    fi
    echo "compiles"
    ;;
  revert)
    sed -i '/# TEMP perf/d' "$R" "$GR"
    echo "reverted ($(cat "$R" "$GR" | grep -c '# TEMP perf') tagged lines left)"
    ;;
  *) echo "usage: $0 apply|revert"; exit 2 ;;
esac
