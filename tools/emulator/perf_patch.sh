#!/usr/bin/env bash
# Emulator helpers (M11c review, 2026-09-27).
# Usage: perf_patch.sh apply|revert — the temporary perf-test build patch, never committed.
#   apply:  (1) no-death: RunController.lose_life returns;
#           (2) auto-nuke at the player's position whenever the swarm reaches NUKE_AT
#               enemies (default 200; at most one per 3 s), logging "NUKE en=N";
#           (3) an on-screen readout (GameRoot): FPS, frame ms, enemy count, and
#               "NUKE!" for 2 s after each nuke — so the drop is visible while watching.
#           Then compiles both scripts (warnings are errors: a parse error breaks the
#           whole game on device) and reverts itself if they do not compile.
#   revert: deletes every line tagged "# TEMP perf" — nothing else changes, so
#           uncommitted work in these files survives (never git checkout them).
D="$(dirname "$0")"
R="$D/../../godot/src/sim/run_controller.gd"
GR="$D/../../godot/src/core/game_root.gd"
N="${NUKE_AT:-200}"
G="${GODOT:-/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
case "$1" in
  apply)
    if grep -q "# TEMP perf" "$R" "$GR"; then echo "already applied"; exit 1; fi
    python - "$R" "$GR" "$N" <<'PY' || exit 1
import sys
rc, gr, n = sys.argv[1], sys.argv[2], sys.argv[3]
T = "  # TEMP perf — do not commit"

def patch(path, anchor, lines, before=False):
    s = open(path, encoding="utf-8").read()
    if s.count(anchor) != 1:
        sys.exit("anchor missing or ambiguous in %s: %r" % (path, anchor))
    block = "".join(l + T + "\n" for l in lines)
    # Anchors begin with "\n": a block that goes before one goes after that newline.
    s = s.replace(anchor, "\n" + block + anchor[1:] if before else anchor + block)
    open(path, "w", encoding="utf-8", newline="").write(s)

# Anchors start with "\n" so an indented copy of the same line never matches.
patch(rc, "\n\tif player.has_shield():\n", [
    "\tif OS.is_debug_build():",
    "\t\treturn",
], before=True)
patch(rc, '\n\tPerfProbe.add("s_swarm", pt_swarm)\n', [
    '\tvar tmp_nuke_t: float = get_meta("tmp_nuke", -99.0)',
    "\tif swarm.enemies.size() >= %s and elapsed - tmp_nuke_t > 3.0:" % n,
    '\t\tset_meta("tmp_nuke", elapsed)',
    '\t\tEngine.set_meta("tmp_nuke_ms", Time.get_ticks_msec())',
    '\t\tprint("NUKE en=%d" % swarm.enemies.size())',
    "\t\tweapons.trigger_weapon(Types.WeaponType.NUKE, player.x, player.y, player, swarm.enemies, particles, grid, audio, Callable(self, \"handle_enemy_killed\"), progression.data.perks)",
    "\t\t_on_weapon_activated(Types.WeaponType.NUKE)",
])
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
    '\tvar tmp_nuke_ms: int = Engine.get_meta("tmp_nuke_ms", -100000)',
    '\tvar tmp_tag: String = "   NUKE!" if Time.get_ticks_msec() - tmp_nuke_ms < 2000 else ""',
    '\ttmp_l.text = "%d FPS  %.0f ms  %d enemies%s" % [Engine.get_frames_per_second(), get_process_delta_time() * 1000.0, _swarm.enemies.size(), tmp_tag]',
])
PY
    echo "applied ($(cat "$R" "$GR" | grep -c '# TEMP perf') lines, NUKE_AT=$N)"
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
