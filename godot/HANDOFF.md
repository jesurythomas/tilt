# Handoff

Rewritten at every module stop. Written for a session with zero context.

## State

Last completed module: **M0 — Scaffold** (pending exit protocol)
Branch: `feat/godot-port`

## How to verify right now

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

# project loads                                          expect exit 0
"$GODOT" --headless --path godot --import

# GUT suite         expect Scripts 1 / Tests 1 / Passing 1, "All tests passed!"
"$GODOT" --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# lint                                    expect "Success: no problems found"
gdlint godot/tests

# format check                             expect "1 file would be left unchanged"
gdformat --check godot/tests
```

## Toolchain facts

| Thing | Value |
|---|---|
| Godot | `4.7.2.stable.official.ed1daf0bf` — **not on PATH**, use the path above |
| GUT | **9.6.1** vendored at `godot/addons/gut/` (9.7.1 exists upstream) |
| gdtoolkit | **4.5.0**, `gdformat` and `gdlint` both on PATH |
| Python / pip | 3.13.1 / 24.3.1 |

Always use the `_console` variant of the Godot exe — the plain `.exe` detaches
and you get no stdout and no usable exit code.

## Three traps, all hit and verified during M0

**1. `--quit` is not a usable boot check.** It exits **0** for any directory
that exists, even with no `project.godot` at all, so it cannot fail for the
right reason. Worse, once a project *does* exist but has no main scene (true
until M2), Godot 4.7.2 opens a modal `ALERT!` window **even under `--headless`**
and blocks forever. Use `--import`, which was verified in both directions:
exit 0 on a valid project, exit 1 on a directory with no project file.

**2. `--import` is silent about script errors.** It proves the *project* loads,
not that any GDScript compiles — a file with a fatal parse error produced no
output and exit 0. To check one script, use
`"$GODOT" --headless --path godot --check-only -s <path/to.gd>`, which exits 1
and prints the parse error.

**3. GUT exits 0 when a test script fails to parse.** It logs
`Ignoring script ... because it does not extend GutTest` (misleading — the parse
failed, so the base class was never seen) and then `Nothing was run.`, and still
returns 0. With several test scripts the others would run, print
`All tests passed!` and exit 0 while the broken one is silently skipped.
**Never accept GUT's exit code alone** — also read the `Scripts` and `Tests`
counts in the run summary and confirm they are what you expected. No GUT flag
fixes this; `-gexit_on_success`, `-gerrors_do_not_cause_failure` and
`-gfailure_error_types` all concern errors during execution, not collection.

## Verified project.godot keys

Godot omits any setting left at its default, so the file is shorter than the
list of things that were set. All values below were confirmed by querying
`ProjectSettings.get_setting()` at runtime, not by reading the file.

Present in the file:

```ini
[application]
run/max_fps=60
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="mobile"
[debug]
gdscript/warnings/untyped_declaration=2
gdscript/warnings/inferred_declaration=2
gdscript/warnings/unsafe_call_argument=2
gdscript/warnings/unsafe_method_access=2
gdscript/warnings/unsafe_property_access=2
gdscript/warnings/unsafe_cast=2
gdscript/warnings/shadowed_variable=2
gdscript/warnings/unused_variable=2
```

Correct but **absent because they are already the Godot 4.7.2 default**:

| Setting | Effective value | Note |
|---|---|---|
| `display/window/handheld/orientation` | `0` | Index 0 is **Landscape**, confirmed from the property's own hint string `Landscape,Portrait,Reverse Landscape,...` |
| `display/window/stretch/mode` | `disabled` | Required by spec §4.1 and load-bearing |
| `debug/gdscript/warnings/unsafe_void_return` | `2` (Error) | Already Error by default in 4.7.2 — so all **nine** required warnings are at Error, though only eight appear in the file |

Warning severity encodes as `0=Ignore, 1=Warn, 2=Error`.

`debug/gdscript/warnings/exclude_addons` returns `<null>` in 4.7.2 — that key
does not exist in this version. GUT's vendored code nonetheless loads and runs
fine with all nine warnings at Error, which was verified directly.

## Untyped-rejection proof (observed, not re-runnable)

With `var untyped_proof = 1` added to `tests/test_scaffold.gd`, the suite was
run and Godot refused the script:

```
SCRIPT ERROR: Parse Error: Variable "untyped_proof" has no static type. (Warning treated as error.)
SCRIPT ERROR: Parse Error: The local variable "untyped_proof" is declared but never used in the block. (Warning treated as error.)
```

The line was then removed and the suite returned to 1 passing test. Note this
run still exited 0 — see trap 3 above. The proof is the parse error, not the
exit code.

## Next module

**M0b — Android toolchain.** Requires user action and several GB of downloads:
export templates, JDK 17, Android SDK. `ANDROID_HOME` is currently set to a
path that does not exist and must be corrected.

First concrete step: in the Godot editor, **Editor → Manage Export Templates →
Download and Install**.

M1 depends on M0b because M1's acceptance requires tilt verification on a
physical device, which an emulator cannot provide.

iOS cannot be exported from this Windows machine and is deferred to M11
(D1, `PREREQUISITES.md` §3).

## Open questions

- **How should the GUT collection-failure gap (trap 3) be closed?** It is
  harmless at one test script and dangerous from M1 onward. Deliberately not
  solved in M0 — Law 4 forbids adding tooling that the module does not need.
  Decide when M1 adds its second spec file.
- Vendored GUT is 9.6.1 while 9.7.1 is available upstream. Pinned deliberately;
  no reason to move found.
