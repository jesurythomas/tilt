# Play Games leaderboards — Play Games Services v2, one board per mode (MVP R2)

Branch `feat/play-games` (from `review/copilot-pr-12-15` at `1d62984`, which is PR #17 into
`staging`, still open). Request (user, 2026-10-14): the Play Games Services setup guide,
"https://developer.android.com/games/pgs/android/android-start#step_3_modify_your_code", sent
after the console setup (Cloud project `peril-point-jtg`, consent screen, Android OAuth client).
The feature is MVP R2 (`docs/superpowers/plans/2026-09-29-mvp-roadmap.md`): "Google Play Games
Services, one board per mode, submitted at death, with a button on the menu and the Run over."

## Sources checked (2026-10-14)

- developer.android.com/games/pgs/android/android-start and …/android-signin: dependency
  `com.google.android.gms:play-services-games-v2`; manifest `<meta-data
  android:name="com.google.android.gms.games.APP_ID">` holding the Play Console's project ID;
  `PlayGamesSdk.initialize` in `Application.onCreate`; `GamesSignInClient.isAuthenticated()` at
  launch (PGS signs in automatically and retries by itself; "doesn't require a manual Sign in
  button"); `signIn()` when the player asks.
- developer.android.com/games/pgs/console/setup: the Android OAuth client must carry the
  published package and the Play app signing SHA-1, or every call fails.
- Google Maven: `play-services-games-v2` latest 22.1.0.
- The Play app signing certificate, read off the A55's Play install of 0.1.3 (code 4, stamp
  `STAMP_TYPE_DISTRIBUTION_APK`): SHA-1 `ED:48:D2:DA:C9:F8:CF:0F:AE:EB:86:5C:DA:E0:3E:17:54:76:51:AB`.

## Rulings (my calls, standing "always proceed")

- **PGS R1 — our own small plugin, as ADS R1.** `PerilGames` (Java) in `android/peril-games/`,
  built by `tools/build_games_plugin.sh` into `godot/addons/peril_games/bin/`; SDK
  `play-services-games-v2:22.1.0`, `compileOnly` in the AAR and handed to the game's gradle
  build by the export plugin. GDScript reaches it only through
  `src/core/android_games_backend.gd`; the autoload is `PlayGames` (`src/core/play_games.gd`),
  with a null backend on desktop, headless and in tests.
- **PGS R2 — IDs in project settings (`GamesConfig`).** `peril/games/project_id` (the digits on
  Play Console's Play Games Services configuration page) and one board ID per mode:
  `peril/games/leaderboard_survival`, `…_corridor`, `…_overdrive` (the modes' display names, as
  the boards will be named). While the project ID is blank the export plugin leaves the AAR, the
  SDK and the manifest entry out: no singleton, the null backend, no leaderboard buttons. The
  manifest value is written `\u003` + the ID (the GPGS Unity plugin's form), so aapt keeps it a
  string; a bare number becomes an integer that the SDK cannot read.
- **PGS R3 — sign-in.** The plugin initializes the SDK in `onMainCreate` (a plugin's earliest
  hook; it has no Application). `PlayGames.start()` reads the launch's automatic sign-in. No
  sign-in button and no Settings row; a tap on a leaderboard button while signed out calls
  `signIn()` and opens the board if it succeeds. If the launch check is still out, the tap waits
  for it and asks only if it failed. No profile-creation suppression.
- **PGS R4 — scores.** One board per mode (MVP R2). At run end the score goes to the run's
  mode board when the player is signed in, the score is above 0 and the board's ID is set.
  Nothing is queued while signed out (a board keeps each player's best; their next signed-in run
  posts). The local best stays one number for all modes.
- **PGS R5 — buttons.** An icon-only podium button: on the menu's stats row after Achievements,
  beside the Best it ranks (all boards; the nav row has no room, task 3), and on the Run over's
  bottom row after Armory (the run's mode board, or all boards
  while that mode has no ID). Shown only when `PlayGames.is_available()`; held while
  `Ads.is_break_pending()`, as Armory and Achievements (ADS R14).
- **PGS R6 — store package.** `PERIL_AAB=1 tools/release.sh` exports the Play listing's package
  `ph.newzenith.perilpoint` for that run (override with `PERIL_PACKAGE`); APKs keep
  `com.jtg.perilpoint`, so A55 sideloads keep the save. Sideloads cannot sign in (other package,
  other key): Play Games is checked on a Play install (internal testing).
- **PGS R7 — signing out inside the boards.** When a board screen returns
  `RESULT_RECONNECT_REQUIRED` (the player signed out from Play Games' own UI) the game counts
  itself signed out.

## Tasks

- [x] 1. Plugin: `android/peril-games` (manifest, gradle, `PerilGamesPlugin.java`),
  `tools/build_games_plugin.sh`, AARs built and committed. *(Compiles against 22.1.0, so the
  API names are right. A Java `long` takes a GDScript int whole: Godot 4.7.2's
  `java_class_wrapper.cpp` passes `ARG_TYPE_LONG` as `jlong`.)*
- [x] 2. Godot: export plugin `addons/peril_games`, `GamesConfig`, `GamesBackend`,
  `AndroidGamesBackend`, the `PlayGames` autoload; tests with a recording backend
  (`test_play_games.gd`).
- [x] 3. Buttons: `UiTheme.ICON_LEADERBOARD`; menu and Run over buttons; GameRoot submits at
  run end and opens boards; tests (`test_play_games_flow.gd`, `test_tilt_menu.gd`,
  `test_run_over_sheet.gd`). *(The menu's podium went to the stats row, not the nav row: a
  fourth nav button made the row 355 px against the panel's 318 px at 844x390 and pushed
  Settings off screen. In the stats row it overhangs a slot as tall as the stats, so the left
  column keeps its size: measured equal with and without it.)*
- [x] 4. `release.sh` store package (PGS R6). *(A check `.aab` carried `ph.newzenith.perilpoint`;
  the preset came back to APK and `com.jtg.perilpoint`.)*
- [x] 5. Checks, 2026-10-14: suite 1065/1065, 77/77 scripts, nothing leaked; gdformat/gdlint
  clean; the new tests mutation-checked (no submit, no podium, no ADS R14 guard, no ask after a
  failed launch check, an ask during the check: each fails a test). Exports: without a project
  ID no Play Games classes and no manifest entries; with a stand-in ID (`734361789228`) the
  plugin registers, the SDK is in (+361 KB) and aapt2 shows `APP_ID="734361789228"` as a string
  (`versionCode=26` beside it is a bare integer). On the A55 that build (a sideload) initialized
  the plugin, answered `games: signed_in=false` and ran; menu frame time mean 16.67 ms, p95
  25.05 (0.1.25: 16.67, 25.11); 0.1.25 was put back. No per-frame code: the podiums are built
  with their screens, the score goes once per death. VERIFY-ME §PGS.
- [ ] 6. With the user's IDs (VERIFY-ME §PGS Part A): set them in `project.godot`, build an
  `.aab` for internal testing, then the device pass (Part B).

## Open

- **IDs.** The project ID and three board IDs come from Play Console once the user creates the
  boards (VERIFY-ME §PGS). Until then the feature is compiled out of exports.
- **Testers.** Until the Play Games configuration is published, only accounts on its Testers
  list can sign in.
