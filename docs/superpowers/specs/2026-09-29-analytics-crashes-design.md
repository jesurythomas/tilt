# Analytics and crash reporting (MVP Week 1)

Written 2026-09-29. Task: `docs/superpowers/plans/2026-09-29-mvp-roadmap.md` §Week 1,
"Analytics + crashes". **Ruling MVP R6 (assistant's pick, the user said "just proceed"):
Firebase Analytics + Crashlytics**, not GameAnalytics. Reversible: everything game-side
goes through one facade, so swapping the vendor touches one file.

## 1. Why Firebase

- Crashlytics is the only free crash reporter with native Android (C++/GDExtension)
  symbolication, and the game has a native library.
- Firebase is the same Google project that Play Games, AdMob and Play Console link to
  (Week 2), so one account covers retention, ad revenue and crashes.
- GameAnalytics has no crash reporting; it would need a second vendor.
- Cost: a Godot 4 Android plugin plus `google-services.json`. The project already uses the
  Gradle build (`use_gradle_build=true`), so this is an add-on, not a switch.

## 2. What the user must supply (blocks step 3 below, nothing before it)

1. A Firebase project with an Android app whose package name equals the export preset's
   `package/unique_name`. The **SHA-1 of both keys** goes on the app: the upload key and,
   once Play App Signing exists, Google's app-signing key. The A55 copy is signed with
   Godot's debug key, the tablet copy with the dev key; register those two too or their
   sessions will not report.
2. `google-services.json` downloaded from it. It is not a secret, but keep it out of
   git until the user decides (`godot/android/build/google-services.json`, listed in
   `.gitignore`).
3. Analytics consent stance: EEA/UK users need UMP consent (already planned, MVP R1)
   before Analytics starts. Until UMP lands the collection default is **off in the EEA
   build path** and on elsewhere; see §5.

## 3. Architecture

One autoload, `src/core/telemetry.gd` (no `class_name`, per the `Log` / `GameEvents`
note in CONVENTIONS §2), the only file that names the plugin.

```
GameEvents / shell / ProgressionManager  ──►  Telemetry.log_event(name, params)
                                              Telemetry.set_user_property(k, v)
                                              Telemetry.record_error(msg)   # non-fatal
                                                    │
                                     plugin singleton present? ──no──► Log.debug only
                                                    │yes
                                            Firebase Android plugin
```

- **Desktop, headless and the test suite have no plugin.** `Telemetry` checks
  `Engine.has_singleton("<PluginName>")` once and becomes a logger otherwise, so the 786
  tests and `tools/emulator` runs need no change.
- Standing rule (spec §5.3): signals go sim→UI only. `Telemetry` is a UI/shell-side
  listener; **no sim class calls it**. It subscribes to `GameEvents`
  (`run_ended`, `goal_completed`, `weapon_activated`) and the shell calls it for menu-side
  events.
- `Telemetry.enabled` is a Settings toggle ("Share anonymous usage data", default on),
  saved by `GameOptions`. Off means `setAnalyticsCollectionEnabled(false)` and Crashlytics
  collection off. The Play Data safety form must say the same thing.
- No personal data: no name, no email, no device id beyond Firebase's app-instance id.

## 4. Events

Firebase caps event names at 40 chars and 25 params per event; keep params flat and
low-cardinality. Names are `snake_case`.

| Event | When | Params |
|---|---|---|
| `run_start` | `launch_run`, after the cinematic starts | `mode`, `first_run` (0/1), `run_index` (this session), `ship`, `arena` |
| `run_end` | `GameEvents.run_ended` | `mode`, `score`, `seconds`, `kills`, `best_combo`, `close_calls`, `max_mult`, `lives_used`, `is_best` (0/1), `first_run` (0/1), `killer` |
| `mode_select` | mode segment changed on the menu | `mode` |
| `upgrade_buy` | any `ProgressionManager.buy_*` returning true | `kind` (`perk`/`boost`/`ship`/`cursor`/`skin`/`arena`), `id`, `rank`, `cost`, `balance_after` |
| `achievement` | `GameEvents.goal_completed` | `id` |
| `first_run_hint` | hint hidden | `how` (`orb`/`timeout`), `seconds` |
| `settings_change` | Steer, Stick size, audio toggles, Reset | `key`, `value` |
| `screen` | Armory, Achievements, Settings, Run over opened | `name` |

Firebase logs `session_start`, `first_open` and `app_remove` itself, which give day-1 and
day-7 retention and session count with no code. Set user properties once per app start:
`steer` (touch/tilt), `build` (version code), `device_class` (phone/tablet, from
`DisplayServer.screen_get_size` aspect and `ui_scale`).

**Session length and runs per session** come from Firebase's `engagement_time_msec` and
`run_start` counts; no separate code.

### Death cause and time

`survival_time` is already in `GameStats`. **A death cause does not exist in the sim yet**
(grep for `killed_by` / `death_cause` finds nothing). Add `killer: String` to
`Types.GameStats`, set by the collision that costs the last life, to the enemy kind's
snake_case name (e.g. `chaser`, `wall_dot`, `black_hole`). This is one sim-side write
(no signal, no telemetry call) and is testable without Firebase. Until it lands,
`killer` is `"unknown"`.

## 5. Crashes

- Crashlytics Gradle plugin and SDK in `android/build/build.gradle`; upload the native
  symbols for `libperil.android.template_release.arm64.so` (the release build strips
  them, so `tools/release.sh` must keep the unstripped `.so` and run
  `firebaseUploadCrashlyticsSymbolFileRelease`).
- `Log.error` and GDScript `push_error` calls are **not** crashes. Forward only
  `Log.error` to `Telemetry.record_error` (non-fatal), rate-limited to 5 per session, so
  the tablet's empty-image error and any future one shows up without spam.
- Custom keys attached to every crash report: `mode`, `phase`, `run_seconds`, `enemies`
  (from PERF's counters). These answer "was it a big swarm?" without more logging.
- EEA/UK: gate the SDK's auto-init off in `AndroidManifest` (`firebase_analytics_collection_enabled`
  = false) and enable it from `Telemetry` after UMP consent. Non-EEA: on.

## 6. Build order (each step ends green and committed)

1. **Facade + tests, no vendor.** `Telemetry` autoload with the null backend and a
   recording backend for tests; `GameStats.killer`; the `run_start` / `run_end` /
   `upgrade_buy` / `achievement` wiring; the Settings toggle. Tests assert events and
   params with the recording backend. Needs nothing from the user.
2. **Docs for the user:** `VERIFY-ME.md` §MVP R6 (create the Firebase project, register
   the SHA-1s, drop in `google-services.json`).
3. **Plugin + Gradle** (blocked on §2): add the plugin, `google-services` and Crashlytics
   Gradle plugins, symbol upload in `tools/release.sh`; build, install on the A55, watch
   DebugView (`adb shell setprop debug.firebase.analytics.app <package>`) for the events.
4. **Force a test crash** on the A55 from a debug-only Settings row and confirm it
   appears symbolicated in Crashlytics; then remove the row.

Steps 1–2 are code-only and can be done now. Steps 3–4 wait for `google-services.json`.

## 7. Out of scope

Ad revenue events (Week 2, AdMob links to Firebase itself), A/B tests, Remote Config,
per-player ids or any login, and a custom backend.

## 8. Risks

- **Plugin choice for Godot 4.7.** There is no first-party Firebase plugin; community
  ones exist. Step 3 begins with a check of what is maintained for 4.7 and, failing that,
  a ~80-line Kotlin `GodotPlugin` that wraps `FirebaseAnalytics.logEvent` and
  `FirebaseCrashlytics`. The facade in §3 is why this risk is contained.
- **Signature mismatches** (debug key, dev key, upload key, Play signing key) silently
  drop reports. §2 item 1 lists all four.
- **Event volume.** `run_end` is the only per-run event with many params; that is
  intentional. `score`/`seconds` are numeric params, not part of the event name.
