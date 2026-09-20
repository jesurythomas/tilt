#!/usr/bin/env bash
#
# Runs the GUT suite and fails when GUT itself would not.
#
# WHY THIS EXISTS
# ---------------
# GUT returns exit 0 when a test script fails to *parse*. The script is dropped
# at collection time with a misleading warning ("does not extend GutTest" — it
# does; the parse failed so the base class was never resolved), and the run
# proceeds without it. With several test scripts the survivors pass, GUT prints
# "All tests passed!" and exits 0 while a spec was never executed.
#
# GUT's exit code IS trustworthy for ordinary assertion failures (verified: a
# failing assert yields exit 1). The gap is collection only. So this wrapper
# adds exactly one check GUT lacks: the number of scripts GUT reports running
# must equal the number of test scripts on disk.
#
# Usage:  tools/run_tests.sh
# Env:    GODOT  — override the engine path if it moves.
# Exits:  0 only if every test script was collected AND every test passed.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"

if [[ ! -x "$GODOT" ]]; then
	echo "FAIL: Godot not found or not executable at:" >&2
	echo "      $GODOT" >&2
	echo "      Set GODOT=<path to Godot_..._console.exe> and retry." >&2
	exit 2
fi

# GUT's defaults: prefix "test_", suffix ".gd", and subdirectories are NOT
# searched unless -ginclude_subdirs is passed. Count the same set it will.
expected="$(find "$REPO/godot/tests" -maxdepth 1 -name 'test_*.gd' | wc -l | tr -d '[:space:]')"

if [[ "$expected" -eq 0 ]]; then
	echo "FAIL: no test_*.gd files found in godot/tests/." >&2
	echo "      An empty suite must never report success." >&2
	exit 1
fi

# A newly added `class_name` is invisible to the parser until the project is
# re-imported. What registers it is .godot/global_script_class_cache.cfg, which
# is gitignored — so a fresh clone, a CI runner, and any session that adds a
# class_name all start without it. GUT then drops every script referencing the
# new class and the check below reports "collected N of M" with a parse error
# that says only 'Identifier "Foo" not declared', which is a misleading trail.
# Observed live in M1 Task 2: types.gd parsed clean on its own while
# test_types.gd would not collect until this ran.
#
# This cannot mask a real parse error: --import stays silent and exits 0 on one
# (CONVENTIONS §1.3), so the collection check below still catches it.
"$GODOT" --headless --path "$REPO/godot" --import >/dev/null 2>&1

output="$("$GODOT" --headless --path "$REPO/godot" \
	-s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1)"
gut_exit=$?

echo "$output"
echo

# "Scripts               1" -> 1. Absent if GUT died before the summary.
reported="$(printf '%s\n' "$output" | grep -E '^Scripts[[:space:]]+[0-9]+' \
	| tail -1 | awk '{print $2}')"

status=0

if [[ -z "$reported" ]]; then
	echo "FAIL: GUT printed no run summary — it did not complete." >&2
	status=1
elif [[ "$reported" -ne "$expected" ]]; then
	echo "FAIL: GUT collected $reported of $expected test scripts." >&2
	echo "      A script was silently skipped, almost certainly a parse error." >&2
	echo "      Find the culprit with:" >&2
	echo "        \"\$GODOT\" --headless --path godot --check-only -s tests/<file>.gd" >&2
	status=1
fi

if [[ "$gut_exit" -ne 0 ]]; then
	echo "FAIL: GUT exited $gut_exit (test failures)." >&2
	status=1
fi

if [[ "$status" -eq 0 ]]; then
	echo "OK: $reported/$expected scripts collected, all tests passed."
fi

exit "$status"
