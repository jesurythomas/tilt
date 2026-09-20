# CONVENTIONS — Peril Point Godot Port

**Normative. Binding on every module.**

Read this file in full before writing any GDScript in this project. If anything
here conflicts with your defaults, this file wins. If anything here conflicts
with `docs/superpowers/specs/2026-09-20-peril-point-godot-port-design.md`, the
spec wins and this file is wrong — report it rather than resolving it silently.

Target engine: **Godot 4.7.2-stable**, GDScript, standard (non-.NET) build.

---

## 0. The five port laws

These exist because this is a **port**, not a new game. 13,250 lines of tuned
TypeScript are being translated across many disconnected sessions. The failure
mode is not bad architecture. It is plausible-looking invention.

> ### LAW 1 — No invented numbers.
> Every numeric literal in ported code carries a source citation:
> `# PORT: web/src/tilt-to-live/PlayerShip.ts:118`
> A literal without a citation is a defect, however reasonable it looks.
> Exempt: `0`, `1`, `-1`, `0.0`, `1.0`, and array indices.
>
> ### LAW 2 — No silent improvement.
> If the TypeScript looks wrong, inefficient, or ugly — **port it exactly as
> written** and add `# PORT-NOTE: <what looks off> — preserved deliberately`.
> The tuned feel of this game lives in its oddities. Changing one is a spec
> change, not a port. Raise it; do not fix it.
>
> ### LAW 3 — One file, one file.
> Each TypeScript module becomes exactly one `.gd` file with the same members in
> the same order and the same method names, snake_cased. A reviewer must be able
> to diff them side by side. Do not merge two TS files. Do not split one.
> (The sole sanctioned exception is `TiltGame.ts`, whose decomposition is
> specified in §5.1 of the spec.)
>
> ### LAW 4 — Nothing new.
> If it is not in the TypeScript source or an explicit line of the spec, it does
> not get written. No helper systems, no convenience wrappers, no abstraction
> "for later", no speculative extensibility, no performance work that profiling
> has not demanded.
>
> ### LAW 5 — Stop, do not guess.
> If the TypeScript is genuinely ambiguous, or the spec does not cover a case
> you have hit: **stop**. Record the question in `HANDOFF.md` and ask. A
> plausible guess is the most expensive failure mode available to you, because
> it looks finished and will not be caught by review.

---

## 1. Machine enforcement

### 1.1 GDScript warnings as errors

These are set to **Error** in Project Settings → Debug → GDScript (enable
Advanced Settings to see them). `project.godot` carries the settings and is
committed:

- `UNTYPED_DECLARATION`
- `INFERRED_DECLARATION`
- `UNSAFE_CALL_ARGUMENT`
- `UNSAFE_METHOD_ACCESS`
- `UNSAFE_PROPERTY_ACCESS`
- `UNSAFE_CAST`
- `UNSAFE_VOID_RETURN`
- `SHADOWED_VARIABLE`
- `UNUSED_VARIABLE`

The engine will refuse to run code that violates these. That is intentional. Do
not lower a severity to get something running — fix the code.

`@warning_ignore` is permitted **only** with a `# PORT-NOTE:` on the same block
explaining why, and only where the TS genuinely requires it.

### 1.2 Formatter and linter

gdtoolkit 4.x (`gdformat`, `gdlint`). Verified against `--help` on 2026-09-20
with gdtoolkit **4.5.0**; both are on `PATH` and need no qualification.

```
INSTALL:  pip install "gdtoolkit==4.*"
FORMAT:   gdformat godot/src godot/tests
LINT:     gdlint godot/src godot/tests
CHECK:    gdformat --check godot/src godot/tests
```

Both must run clean before any module may be marked done.

Notes, all observed rather than assumed:

- Both take `<path>...` and recurse into directories.
- `gdformat` **rewrites files in place.** `--check` reports what would change
  without writing (`--diff` shows the changes and implies `--check`). Prefer
  `CHECK` in any verification step; reserve bare `FORMAT` for when you intend
  to reformat.
- `gdlint` exits 0 on success, non-zero with a list of problems.
- `godot/src` holds no `.gd` files until M1. Until then both commands are run
  against `godot/tests` alone.
- Never run either against `godot/addons/` — GUT is vendored third-party code
  and is not ours to reformat.

---

## 2. File anatomy

Mandatory member order, per the official Godot style guide. No deviation.

```gdscript
## player_ship.gd
## PORTS: web/src/tilt-to-live/PlayerShip.ts (633 lines, source commit 7be9614)
class_name PlayerShip
extends RefCounted
## Mouse/tilt-driven arrow ship with inertia physics.
##
## Instantiated twice concurrently: once for the live run, once for the menu
## backdrop. Must never become an autoload (see spec §5.2).

# --- order below is mandatory ---
#  1. signals
#  2. enums
#  3. constants
#  4. static variables
#  5. @export variables
#  6. regular variables
#  7. @onready variables
#  8. _init()
#  9. overridden virtuals: _enter_tree, _ready, _process, _physics_process, rest
# 10. public methods
# 11. private methods
# 12. inner classes
```

The header block is required on every file:

- `## <filename>`
- `## PORTS: <ts path> (<line count>, source commit <sha>)` — or
  `## PORTS: nothing — new file per spec §<n>` for files with no TS counterpart
- `class_name` + `extends`
- `##` class doc comment

---

## 3. Naming

No judgment calls. Use this table.

| Thing | Case | Example |
|---|---|---|
| file | `snake_case.gd` | `enemy_swarm.gd` |
| `class_name` | `PascalCase` | `EnemySwarm` |
| node in scene | `PascalCase` | `EffectLayer` |
| function | `snake_case` | `spawn_seeker` |
| variable | `snake_case` | `spawn_timer` |
| private member | `_snake_case` | `_next_enemy_id` |
| constant | `CONSTANT_CASE` | `COIN_BASE_VALUE` |
| enum type | `PascalCase` | `EnemyType` |
| enum value | `CONSTANT_CASE` | `EnemyType.SPIKE_MINE` |
| signal | `snake_case`, past tense | `enemy_killed` |
| boolean | `is_` / `has_` / `can_` prefix | `is_frozen`, `has_shield` |

**Porting names:** a TS `spawnSeeker()` becomes `spawn_seeker()`. A TS
`nextEnemyId` private becomes `_next_enemy_id`. Do not rename, shorten, or
"clarify" a ported name. Law 3 depends on the names matching.

---

## 4. Static typing

**Every declaration is explicitly typed.** No exceptions, no inference.

Legal:

```gdscript
var radius: float = 12.0
var enemies: Array[Enemy] = []
const MAX_COINS_ON_SCREEN: int = 6  # PORT: web/src/tilt-to-live/CoinSystem.ts:29

func spawn_coin(bounds: Vector2, player: PlayerShip) -> Coin:
    var coin: Coin = Coin.new()
    return coin

func reset() -> void:
    _spawn_timer = 0.0
```

Illegal — every line below fails the Tier 1 warnings:

```gdscript
var radius = 12.0            # untyped
var radius := 12.0           # inferred
var enemies: Array = []      # untyped element type
func spawn_coin(bounds):     # untyped parameter
func reset():                # missing return type
```

`Variant` is permitted only where the data is genuinely dynamic (parsed JSON
before validation) and requires a `# PORT-NOTE:` justifying it.

Typed arrays are mandatory: `Array[Enemy]`, never bare `Array`.

---

## 5. Comments

### Required

**File header** — §2.

**`##` doc comments on every public member** (class, public method, public
variable, signal). These populate Godot's in-editor documentation.

```gdscript
## Emitted once per enemy destroyed, after score has been credited.
signal enemy_killed(position: Vector2, type: EnemyType, combo_index: int)

## Applies flocking separation so seekers do not stack into a single point.
func apply_flocking_separation() -> void:
```

**`# PORT:` citations** — Law 1. On the same line as the literal where it fits,
otherwise directly above:

```gdscript
const SPAWN_INTERVAL_MIN: float = 2.5  # PORT: web/src/tilt-to-live/CoinSystem.ts:35
```

**`# PORT-NOTE:` for deliberate divergence** — Law 2. Always states what and
why:

```gdscript
# PORT-NOTE: particles update before the player here, matching
# TiltGame.ts:1866. Particles emitted this tick therefore draw unaged. Looks
# accidental; preserved deliberately — it is part of the tuned feel.
```

**Module-tagged TODOs only.** Never a bare `TODO`:

```gdscript
# TODO(M7): wire to ProgressionManager.get_points_multiplier once M7 lands.
```

### Banned

- Comments restating the code — `# increment the counter`, `# loop over enemies`
- Commented-out code (git has it)
- Decorative separator bars beyond the file header
- Narration of the porting process — `# Now we handle the enemies`,
  `# First, let's set up the state`
- Any comment claiming something was tested, verified or benchmarked unless it
  actually was

---

## 6. Forbidden constructs

Each is a known drift vector in a multi-session port.

| Forbidden | Use instead | Why |
|---|---|---|
| untyped / inferred `var` | explicit type | Tier 1 error; hides type drift |
| `call("name")`, `get("prop")`, `set("prop")` | direct access | string names are unverifiable and invisible to the linter |
| `has_method()` duck-typing | a typed parameter | hides interface mismatches until runtime |
| `Dictionary` as an entity record | typed `RefCounted` class | slower, untypeable, invites key typos |
| autoload for any sim system | plain instantiation | breaks `MenuBackdrop`'s second sim instance — spec §5.2 |
| bare `print()` | `Log.info` / `Log.warn` / `Log.error` | no levels, ships to release builds |
| `await` inside `_physics_process` | restructure | silently desynchronises the fixed step |
| `get_node("Some/Long/Path")` | `@onready var x: T = %UniqueName` | breaks silently when a scene is reorganised |
| sim→sim signals | direct reference or `Callable` | destroys knowable frame order — spec §5.3 |
| new helper systems / abstractions | nothing | Law 4 |

---

## 7. Signals

Signals are **sim→UI and sim→audio only. Never sim→sim.**

Simulation systems communicate through direct references and `Callable`
callbacks, exactly as the TypeScript does (`loseLife`, `handleEnemyKilled`,
`addPointsCredited` are all passed into `update()` today and port directly).

The `GameEvents` autoload carries only: `score_changed`, `enemy_killed`,
`weapon_activated`, `life_lost`, `run_ended`, `goal_completed`,
`points_changed`, `phase_changed`. Adding a signal to it requires a spec change.

All signal parameters are typed.

---

## 8. Commits

One line. Imperative mood. 72 characters or fewer. **No trailers** — no
`Co-Authored-By`, no `Signed-off-by`, no generation attribution, no emoji.

Prefix with the module number, which is what makes `git log` a legible module
history when resuming cold:

```
M3: port charger and artillery enemy behaviours
M5: bake sfx from TiltAudio and add pitch variation on playback
M7: fall back to defaults when the progression save is corrupt
```

State why, not merely what, whenever the why is not obvious.

---

## 9. Module exit protocol

No module is done until all five steps are complete, in order:

1. **Verify** — actually run the module's acceptance commands from
   `PORT-PROGRESS.md` and read the output. Never claim a result you have not
   seen. If something fails, the module is not done.
2. **Commit** — per §8.
3. **Tick `PORT-PROGRESS.md`** — check the box, record the date and commit SHA.
4. **Rewrite `HANDOFF.md`** — written for a session with zero context: what
   landed, exact commands to verify it now, the next module and its literal
   first step, open questions, anything surprising.
5. **Stop. Report to the user. Do not begin the next module.**

Step 5 is not a suggestion. The user is managing a credit budget and has asked
explicitly for a hard stop at every module boundary.
