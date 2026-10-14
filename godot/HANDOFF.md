# Handoff

Rewritten at every module stop. Written for a session with zero context.

## State

**Latest (2026-10-14, evening): Play Games leaderboards (MVP R2), on `feat/play-games`** (from
`review/copilot-pr-12-15` at `1d62984`; PR #17 is merged into `staging` at `5c61e75`, and the
three note commits after it ride on this branch). User sent the PGS guide's "Step
3: Modify your code" after the console setup. Plan
`docs/superpowers/plans/2026-10-14-play-games-leaderboards.md`, rulings PGS R1-R7: our own
`PerilGames` plugin (`android/peril-games`, `tools/build_games_plugin.sh`, AARs in
`godot/addons/peril_games/bin/`, SDK `play-services-games-v2:22.1.0`); the `PlayGames` autoload
(`src/core/play_games.gd`; `GamesConfig`, `GamesBackend`, `AndroidGamesBackend`); one board per
mode, a death's score posted when signed in; a podium button in the menu's stats row (all
boards) and the Run over's bottom row (the run's board), held during Retry's ad; sign-in is
Play Games' automatic one, a signed-out tap asks. **Compiled out until
`peril/games/project_id` is set** (the export plugin then adds the AAR, the SDK and
`APP_ID`, its first digit escaped so aapt keeps it a string). `PERIL_AAB=1 tools/release.sh`
now exports package `ph.newzenith.perilpoint` (the Play listing's); APKs keep
`com.jtg.perilpoint`, which cannot sign in to Play Games. Suite 1065/1065, 77/77; checked on the
A55 with a stand-in ID (plugin up, `signed_in=false`, no crash, frame time unchanged), then
0.1.25 put back. The Play app signing SHA-1 is
`ED:48:D2:DA:C9:F8:CF:0F:AE:EB:86:5C:DA:E0:3E:17:54:76:51:AB` (read off the A55's Play install).
**Next:** the user's Play Console steps (VERIFY-ME §PGS Part A: project ID, three boards,
testers), then set the IDs, build an `.aab` for internal testing (code 27+), and the device pass
(Part B). This branch goes to `staging` by PR (the user merges).

**Also (2026-10-14, 13:48): a Google Cloud project for Peril Point.** User: "create a new google
cloud project for Peril Point". `peril-point-jtg` ("Peril Point", number 734361789228; ID
`peril-point` was taken), owned by jtgadiane@gmail.com (user: "email is jtgadiane"), no
organization, no billing; Games, Games Management and Drive APIs enabled for Play Games'
OAuth consent screen, which the user set up in the console; the Android OAuth client is
VERIFY-ME §PGS Part A step 1. gcloud: a separate
configuration `peril-point` (account + project) — run gcloud with `--configuration=peril-point`;
the `default` configuration (jg@blackcapitaltechnology.com, `garage-hub-jtg-8b1fe`) is untouched.
It is the project for VERIFY-ME §Part B's Firebase step 2.

**Earlier (2026-10-14, 13:35): Copilot's PR #12-#15 comments, on `review/copilot-pr-12-15`
(from `staging` at `507e180`, where PR #16 is merged).** User: "copilot left some comments on the
pervious prs. take a look at those comments and fix if needed". 13 comments: 11 fixed, 2 moot
(merge-time wording on PR #14); PR #16 got no review (Copilot's quota). Triage
`docs/superpowers/plans/2026-10-14-copilot-pr-comment-triage-12-15.md`. Code: ADS R11 (closing
the privacy form drops ads loaded under the old consent, in the Java plugin and `Ads`; AARs
rebuilt), R12 (`Ads._showing` holds an ad until its own close, past the watchdog, so a late close
cannot end a newer break), R13 (a rewarded payout after Retry pays its own run:
`RunController.run_number`, `claim_reward_for`), R14 (Retry leaves the Run over up while its ad
opens); rulings in `docs/superpowers/plans/2026-10-13-in-game-ads.md`. Also: `run_tests.sh`
fails closed without a temp `user://`; the guide's Tilt card names Tilt level / Each start /
All runs / Calibrate tilt; doc fixes (the PR #12 tally, VERIFY-ME §HTP's build, the ads plan's
pacing note). Suite 1032/1032, 75/75 scripts, nothing leaked; gdformat/gdlint clean; 0 SCRIPT
ERROR. No per-frame cost (`bench_sim` within noise). User: "build it": 0.1.25 (code 26,
`godot/build/peril-point-0.1.25-a55.apk`, A55 key) is on the A55, installed 2026-10-14 13:35
over 0.1.24 (a finished run's Run over was open; its points were banked), data kept, launched:
the save loaded (best 1,459,665, 1,826 points, 42/57), consent `can_request_ads=true` in ~3 s,
0 SCRIPT ERROR; menu frame time mean 16.67 ms, p95 25.1 (0.1.24: 16.70, 25.1). Next A55 build
uses code 27. VERIFY-ME §ADS has the R11/R14 rows. Then one review run over the repo (user: "do 1 run for an overall review of the repo"): 6 of 8 findings fixed on the same branch — Armory/Milestones held while Retry's ad opens, a 30 s give-up for an ad that never opened, the 3× offer hides at every show, its glint stops on the hidden sheet, the plugin keeps its ads when the privacy form fails, and a tilt level cut off by a stopped sensor waits again (BUG-101 R5); the dash-into-wall finding is DASH R2 by design, long old commit messages stay. Triage doc's last section. Suite 1037/1037. Next: PR #17 (`review/copilot-pr-12-15` → `staging`, open; the user merges it),
then the user's A55 pass (BUG-101 R5, §ADS R9-R11/R14, §DASH).

**Earlier (2026-10-14, afternoon, later): BUG-101 R5, still-phone tilt levels, on
`feat/dash-and-abilities`.** User: "theres a drift now during the tilt calibration ... i usually
just press play and when on the game screen not expect it to move until i tilt. now, it tilts at
around 10-11". Every level was one gravity reading taken as a thumb left a button (Play's first
tick, Resume, the Pause crosshair, Armory, Set level), so a moving hand gave an off-level
neutral and the ship drifted up-left; the user's Pause showed Keep tilt level on, which keeps
that level for every run. Now `TiltInput.settle_level` takes the mean of 0.25 s of still samples
(within 1°) after the request (stillest window after 1.5 s), steering zero meanwhile; GameRoot
polls the sensor while a level settles in any phase (so Each start settles in the 0.6 s cold
open); Set level uses the 0.3 s before the finger came down (`level_to_recent`). One log line a
level ("tilt: level settled in …; the first reading was … deg off it"). Ruling and numbers in
`docs/superpowers/plans/2026-10-12-fix-bug-101-calibration-sticks.md` (R5). Suite 1026/1026,
75/75 scripts, nothing leaked; gdformat/gdlint clean; 0 SCRIPT ERROR headless. Cost: a tilt tick
0.84 → 1.08 µs on desktop. 0.1.24 (code 25, `godot/build/peril-point-0.1.24-a55.apk`, A55 key)
is on the A55, installed 2026-10-14 12:37 over 0.1.23 (a paused 0:02 run was the only thing
open), data kept, launched with no SCRIPT ERROR; menu frame time mean 16.70 ms, p95 25.1 (taken
just after launch). Next A55 build uses code 26. User: "commit push merge to staging": the branch is pushed and
PR #16 (`feat/dash-and-abilities` → `staging`) was opened; merging it was refused by the session's
permission check ("Merge Without Review"), and the user merged it (`507e180`). Next: the user's pass (`VERIFY-ME.md` §BUG-101
R5 lines; their Keep tilt level is on, so its old level stays until they level again or turn
it off), then the §ADS R9/R10 and §DASH checks, then PR `feat/dash-and-abilities` → `staging`.

**Earlier (2026-10-14, afternoon): ADS R9 and R10, on `feat/dash-and-abilities`.** User: "for
ads, if they manually select the 3x points to view ads, reset the count. also make it more
appealing to look at". R9: `Ads.show_rewarded` resets the interstitial pacing (saved) at the
tap, not when the ad opens, so it holds when the ad fails or never opens. R10: the Run over's
`WatchAdButton` is a flare `RewardButton` (new theme variation) with a "3×" badge, "Watch ad",
and the payoff (`earned × GameRoot.AD_REWARD_MULTIPLIER`, e.g. +3,822), under a warm glint that
sweeps every 3 s while it can be tapped (a tween moves a once-drawn `RunOverSheet.RewardShine`,
~1.2 µs a frame, Run over only); "Opening ad…" and 45% while its ad is on its way. Rulings in
`docs/superpowers/plans/2026-10-13-in-game-ads.md` (tasks 15, 16). Review shot:
`REWARD=1|wait bench/shot_run_over.gd` → `build/run_over_a55_reward*.png`. Suite 1017/1017,
75/75 scripts, nothing leaked; gdformat/gdlint clean; 0 SCRIPT ERROR headless. 0.1.23 (code
24, `godot/build/peril-point-0.1.23-a55.apk`, A55 key) is on the A55: installed 2026-10-14
12:16 over 0.1.22 while locked, then rebuilt from the same tree and reinstalled at 12:18 once
the user unlocked it ("ive unlocked it rebuild"), data kept, launched: the save loaded (best
1,459,665, 1,228 points, 42/57), consent `can_request_ads=true`, no SCRIPT ERROR; menu frame
time mean 16.66 ms, p95 24.9 (same as 0.1.22). Next A55 build uses code
25. Next: the user's A55 pass (VERIFY-ME §ADS R9/R10 lines, §DASH /
ITEM / HUD / HTP R3, §ADS Part A), then PR `feat/dash-and-abilities` → `staging`.

**Earlier (2026-10-14, later still): HUD R4.** User: "it should also be on the right when tilt
is selected. on touch, when the jostick is stickied to the right show it on the left, else
right". The ability bar is bottom left only for the Touch stick anchored Right
(`GameRoot.is_ability_bar_left`, re-applied on a scheme change); tilt keeps it bottom right.
0.1.22 (code 23, `godot/build/peril-point-0.1.22-a55.apk`, A55 key) is on the A55, installed 2026-10-14 02:00 over 0.1.21, data kept (the phone was locked, so not launched). Suite 1012/1012 green. Next A55 build uses code 24.

**Earlier (2026-10-14): HUD R3.** User: "having the background on abilities/items seem
bad". The item buttons have no panel (empty styleboxes; the orb is 42 of the 48-unit target) and
the dash gauge has no disc (track ring + fill on the playfield; the seconds carry the HUD's void
outline). `dash.ogv` re-recorded. 0.1.21 (code 22, `godot/build/peril-point-0.1.21-a55.apk`, A55
key) is on the A55 (user: "build it"; installed 2026-10-14 01:50 over 0.1.20, data kept, launched, booted with no SCRIPT ERROR). Everything below still holds.

**Earlier (2026-10-14): dash, items (active abilities), and the play-screen rework, on branch
`feat/dash-and-abilities` (from `feat/in-game-ads` at `31040da`, which holds `staging`), not
merged.** User: "1. Dash ... 2. Active abilities ... 3. ... hard to see the middle upper center
due to the score and multiplier. 4. ... show the Dash cooldown and clickable items. 5. Update the
how to ... Create a new branch for this". Plan `docs/superpowers/plans/2026-10-14-dash-and-abilities.md`
(rulings DASH R1-R5, ITEM R1-R2, HUD R1-R2, HTP R3; all 7 tasks ticked). **Dash:** a double tap
anywhere in a live run (`src/input/double_tap.gd`, Android's rule: a quick still tap, then a
second press within 0.3 s and 100 units; any finger; GameRoot feeds it before the stick), or
Shift / a real mouse double-click on desktop, asks `RunController.abilities`
(`src/sim/ability_system.gd`) for a dash at the next tick: a 0.12 s burst a quarter of the arena
along the ship's velocity (facing when still), stopped by the arena edge and Corridor walls
(`GauntletMaze.blocks`), raising the shield to 2 s; the 20 s cooldown starts when the dash's own
shield window ends; ready at every run start; a request while not ready is dropped. Upgrades in
the save (`dash: {cooldown, shield}`): cooldown 20 → 15 s in 5 ranks, shield 2.0 → 5.0 s in 6,
priced as weapon ranks. DASH R5: these are game seconds (the sim runs at `Tuning.GAME_SPEED`
0.75, like every timer), ~27 s on a stopwatch — flip in `AbilitySystem.reset` if the user wants
wall-clock. **Items:** each of the seven power-ups can be bought once (`ITEM_COSTS` × 2,
2,400-4,000) and equipped in one of 2 slots (`unlockedItems`, `equippedItems`); in a run each
equipped item fires once via its HUD button (or 1 / 2), as an orb pickup would (perks,
milestones, the timer), and is back next run. **Armory:** a sixth tab, Abilities (dash rows +
slots + item cards with buy / Equip / Unequip); the tab buttons pad 8 a side (was 12) so six
tabs and a 7-digit balance fit the 844-px header. **HUD:** the score block moved into the left
column (score 22 px with the chip beside it, BEST under it, then lives and toasts); a bottom-corner
`AbilityBar` (`src/ui/ability_bar.gd`): the dash gauge (display only) and the item buttons,
bottom left when Stick position is Right. **How to play:** page 3 "Dash and items" with a recorded
clip (`assets/how_to_play/dash.ogv`), the Abilities line, and a re-recorded `armory.ogv`
(`tools/record_htp_clips.gd`, `HTP_CLIP=dash`). `GameEvents.dash_activated` (Haptics: 25 ms).
MVP R3 (clickable power-ups) is marked superseded in the roadmap. Review shots:
`bench/shot_hud.gd`, `bench/shot_armory.gd`, `bench/shot_how_to_play.gd` (all windowed,
`build/shots/`). Tests: 1010/1010, 75/75 scripts, nothing leaked; gdformat/gdlint clean;
0 SCRIPT ERROR headless. Perf: desktop full run tick 68-69 µs vs 70-73 before; the bar's
per-frame update 1.3 µs. **0.1.20 (code 21, `godot/build/peril-point-0.1.20-a55.apk`, A55 key)
is on the A55** (installed 01:42, data kept); someone was playing it at once and dashed twice;
frame time mean 16.66 ms, p95 25.0 (same as 0.1.18). Seen, not
fixed: the Armory weapon list clips "Blackhole" beside a two-digit rank ("9/15"). Next: the
user's A55 pass (`VERIFY-ME.md` §DASH / ITEM / HUD / HTP R3, and §ADS still open), then PR
`feat/dash-and-abilities` → `staging`.

**Earlier (2026-10-14): ads round 2 — pacing by games, a 3× rewarded ad, dearer Armory (ADS
R5-R8), and a Gauntlet stripe fix; merged into `staging` from `feat/in-game-ads` (user:
"commit push create pr and merge to staging for now"), not yet in `main`.** Plan
`docs/superpowers/plans/2026-10-13-in-game-ads.md` (rulings and tasks 10-12). R5 (user: "after
every 5-10 games at random or total ingame time"): an interstitial is due after a random 5-10
games or 300 s of run time, whichever first, never after the first run ever or a run under 20 s;
the counts are saved in `user://peril_point_ads.json` (`Ads.SAVE_PATH`) across launches;
`Ads.clock` is gone. R6 (user: "watch ads button for 3x the coins"): the Run over's
`WatchAdButton` "Watch ad · 3× points" (under Points earned) shows a rewarded ad
(`PerilAds.loadRewarded/showRewarded`, AARs rebuilt; test unit 5224354917, real one goes in
`peril/ads/android_rewarded_id`); earning it makes the run's points 3× (`RunController.
claim_reward`, the extra through `ProgressionManager.add_points_bonus`, no Points Multiplier),
once a run; a rewarded view resets the interstitial pacing; HudController ignores Retry while an
ad is on its way. R7 (user: "make the weapon upgrades more expensive ... ships, arena and
boosts"): `ProgressionManager.PRICE_SCALE` = 2 doubles every Armory price where it is read; the
tables keep their figures. R8 (user: "The upgrades still seem cheap"): weapon ranks and
keystones use `UPGRADE_PRICE_SCALE` = 4 instead. The A55 log showed "Invalid polygon data, triangulation failed" up to
60/s in Gauntlet: a stripe clipping a wall's corner leaves a sub-pixel sliver (442 of 3.5 M
pieces in a sweep); the maze now draws each (convex) piece as a fan (`EntityLayer.fan_indices`).
`peril/ads/test_device_hashed_id` = the A55's hash is committed (UMP debug device, SDK test
device). Tests: 70/70 scripts, nothing leaked, gdformat/gdlint clean, 0 SCRIPT ERROR headless.
0.1.18 (code 19) ran on the A55 2026-10-14 00:44: a rewarded ad opened, earned and closed;
mean 16.67 ms, p95 25.0 on screen. 0.1.19 (code 20, `godot/build/peril-point-0.1.19-a55.apk`, no
test switches, R8 prices) is the build for the user's pass. Next A55 build uses code 21. Next: the user's A55 pass
(`VERIFY-ME.md` §ADS Part A, incl. the R6 rewarded check and the stripe check), AdMob setup
(Part B, now with a rewarded unit), then `staging` → `main`; then Remove ads (Play Billing).

**Earlier (2026-10-13): in-game ads (rulings ADS R1-R4), on branch `feat/in-game-ads`, not
merged.** User: "We need to implement in-game ads - create a plan and push through with the
plan". Plan `docs/superpowers/plans/2026-10-13-in-game-ads.md` (MVP R1's ad half). AdMob
interstitials at one break, leaving the Run over by Retry or Menu (`GameRoot.restart_run` /
`return_to_menu` call `Ads.ad_break` when the phase is GAME_OVER; Pause's Restart/Quit do not),
paced by `AdPacing`: not after the first run ever, not after a run under 20 s, at most one per 3
runs and 3 minutes (from launch too), never waiting on a load; a 4 s watchdog; the Master bus is
muted under the ad. UMP consent at every launch (`Ads.start()`, deferred from `GameRoot._ready`);
Settings → Data → **Ad privacy · Manage** when UMP requires it. Our own small Android v2 plugin
`PerilAds` (Java, `android/peril-ads/`, built by `tools/build_ads_plugin.sh` into
`godot/addons/peril_ads/bin/*.aar`, committed) on Google Mobile Ads 25.5.0 + UMP 4.0.0; the
export plugin `godot/addons/peril_ads/` adds the AAR, the SDKs and the manifest app ID. IDs live
in project settings via `AdsConfig` (`peril/ads/*`); unset = Google's **test** IDs, so every ad
is a test ad until the user does `VERIFY-ME.md` §ADS Part B (AdMob app, unit, GDPR message,
app-ads.txt, Play Console declarations). `peril/ads/every_break=true` skips the pacing for a
device check; never commit it on. Facade in Telemetry's shape: `Ads` autoload
(`src/core/ads.gd`), null `AdsBackend`, `AndroidAdsBackend` (the only file naming the plugin).
924 tests green (`test_ads.gd`, `test_ad_break.gd`), nothing leaked, gdformat and gdlint clean,
0 SCRIPT ERROR headless. Emulator (Pixel_10, Play Store image): the EEA consent form, the
privacy options form, test interstitials on Retry and Menu with the action after ✕, and no ad
on a short first run, all seen. 0.1.15 (code 16, same code as 0.1.14, `godot/build/peril-point-0.1.15-a55.apk`)
is on the A55, installed 2026-10-13 22:10 with data kept, and launched: consent answered in ~2 s,
`can_request_ads=true privacy_options_required=false` (GDPR does not apply in PH), no load
failure; menu frame time mean 16.66 ms, p95 25.1. The A55's ads hash is
`9A0837A109CE8195013D1AF3E32EC41B`, now committed as `peril/ads/test_device_hashed_id` (UMP debug
device and SDK test device). User: "rebuild it i do not see the consent" — outside the EEA/UK/CH
UMP shows no form, by design. 0.1.16 (code 17, `godot/build/peril-point-0.1.16-a55-eea.apk`)
was built with `ads/debug_geography=1` uncommitted (release.sh restored project.godot) and
installed 2026-10-14 00:07, data kept: the EEA form showed over the menu, a choice was tapped
(`CONSENT_SIGNAL_SUFFICIENT`), and the game logged `can_request_ads=true
privacy_options_required=true`. The A55 now carries that EEA test build and its stored consent;
the form will not show again by itself (Settings → Ad privacy · Manage reopens the choices).
User: "now how do i simulate the ads?" — 0.1.17 (code 18,
`godot/build/peril-point-0.1.17-a55-ads-test.apk`) was built with `ads/every_break=true` and
`ads/debug_geography=1`, both uncommitted, and installed on the A55 2026-10-14 00:10, data kept:
every Retry or Menu on the Run over shows a test interstitial. Next A55 build uses code 19; a
build from HEAD drops both switches and brings back the real pacing. Surprises: a static factory that called its own
class's `new()` from an autoload kept every script alive at exit (306 leaked instances; fixed by
building the backend in `Ads._ready`); a SceneTreeTimer bound into its own signal is a leaking
cycle. The APK grew to 95 MB (the SDK's dex is ~9 MB; no R8). Next: the user's A55 pass
(`VERIFY-ME.md` §ADS Part A) and AdMob setup (Part B), decide the package name question there,
merge; then the ₱15 Remove ads purchase (Play Billing, roadmap Week 2), which turns the break
off.

**Latest (2026-10-13): the How to play guide (rulings HTP R1/R2), merged into `main` from
`staging`.** Branches: `add-onboarding` (worktree `../dread-flock-staging`) → `staging` → `main`
by PR; `staging` is kept. The public guide (perilpoint.newzenith.ph/how-to-play) is in the game:
`ui/how_to_play_screen.gd`, three pages (The basics with a recorded run dodging red dots,
Power-ups with the site's seven clips, The Armory with a recorded tab tour; Theora in
`assets/how_to_play/`, the two recorded clips made by `tools/record_htp_clips.gd`). A first
launch opens it (`GameSettings.how_to_play_seen`, saved on close); the menu's **How to play**
button reopens it; Android back closes it; the attract swarm holds still under it. 895 tests
green. 0.1.13 (code 14, `godot/build/peril-point-0.1.13-a55.apk`) is on the A55; the next A55
build uses code 15. A55 frame time on Power-ups with a clip (0.1.11): mean 16.71 ms, p95 25.2.
A worktree needs `godot/android/` copied from the main checkout (gitignored) and `godot/build/`
made. Plan `docs/superpowers/plans/2026-10-13-add-onboarding.md`. Next: the user's A55 pass
(`VERIFY-ME.md` §HTP R1/R2). Not mine, on `main`: a stray committed
`godot/bin/~libperil.windows.template_debug.x86_64.dll~RF1858cea.TMP`.

**Latest (2026-10-13): Copilot PR comment triage, merged into `main` by PR #12.** User: "check all comments left by copilot on all recent PRs". 19 comments verified
(PRs #5-#11): 12 fixed or covered, 1 deferred (#11 API-33 guard), 6 moot. Code fixes: a Stick position
change releases a held stick; Set level from Settings redraws the Settings board. 880 tests
green. Plan `docs/superpowers/plans/2026-10-13-copilot-pr-comment-triage.md`. Then
`fix/test-run-own-user-dir`: `tools/run_tests.sh` runs each suite with its own temp `user://`
(two suites at once both 880/880; shared, they flaked save tests). Copilot threads on PRs
#5-#11 answered and resolved. Next: nothing in flight; ask the user what to pick up. No A55 build was made for it: the two fixes
(the stick release, the Settings redraw) change device behaviour but rest on their regression
tests, and every later build (0.1.13 on) carries them.

**Also (2026-10-13): BUG-101 R4, Pause → Keep tilt level, merged into `main` by PR #11
(after HAPTICS R1, PR #10).** User: "merge them all -- they all pass". User: "make tilt every run on the pause menu toggle-able, toggled
on -> keep on every run -> toggle off -> recalibrates when play /resume is pressed". Pause has a
Keep tilt level switch (tilt only); off = Each start, which now also levels on Resume; on = All
runs, keeping the level in use. 876 tests green. 0.1.10 (code 11) is on the A55; next A55 build
uses code 12. Next: nothing in flight; ask the user what to pick up. The A55 checks in `VERIFY-ME.md`
§BUG-101 and §HAPTICS R1 all passed (user: "they are working now"). Seen, not fixed: the calibrate toast draws under the
menu's PERIL POINT title.

**Also (2026-10-13): HAPTICS R1, vibration fixed, merged into `main` by PR #10.** User: "vibration isnt working". Godot's `vibrate_handheld` tags pulses `usage: TOUCH`;
the A55 has touch-feedback vibration off, so Android dropped every pulse. `Haptics` now calls
the Android Vibrator as media (`JavaClassWrapper`, `AndroidRuntime`); verified on the A55
(`usage: MEDIA`, `finished`) and by the user ("vibration works now as well"). Switching Vibration on buzzes once. 871 tests green. 0.1.9
(code 10) is on the A55; next A55 build uses code 11. Plan
`docs/superpowers/plans/2026-10-13-fix-haptics-media-vibration.md`.

**Latest (2026-10-13): BUG-101, calibration sticks, merged into `main` by its PR** (R1-R3).
R3: the home page's calibrate icon is removed; the Calibrate screen's Cancel no longer falls off
the A55 (left block grows both ways); Settings shows Touch stick only under Touch. 869 tests
green. 0.1.8 (code 9, `build/peril-point-0.1.8-a55.apk`) is on the A55, installed 2026-10-13
14:39. Next A55 build uses code 10. Next: the user's A55 pass (`VERIFY-ME.md` §BUG-101). Earlier in this fix (R1): User: the tilt calibration set on the home screen was replaced in game by the pose
at Play. Cause: `calibrate_current_position()` only arms a capture that the next `poll()` takes,
and nothing polls in the menu, so the run's first poll took it. The port armed one at boot, on
Retry and on choosing tilt (none in the TS), and Armory's Calibrate tilt armed one from the menu.
Fixed in `game_root.gd`: those three calls are gone and `calibrate_gyro` polls at once. 857 tests
green, gdformat and gdlint clean. Plan `docs/superpowers/plans/2026-10-12-fix-bug-101-calibration-sticks.md`.
Then ruling R2 (user 2026-10-13: "give 2 options, auto-calibrate on start, or calibrate for all
runs"): Settings → Controls → **Tilt level**, Each start (default, levels at Play/Retry without
saving) / All runs (the saved level); any Set level picks All runs. 867 tests green. Version is
0.1.7 (code 8); the A55 has it (`build/peril-point-0.1.7-a55.apk`, installed 2026-10-13 14:24),
so the next A55 build used code 9 (0.1.8, above). Seen, not fixed: the calibrate toast draws under the menu's PERIL POINT title.
Open: a user clip of the ship that "can't go to the right": a fresh launch straight into a tilt
run, so the boot calibration took the pose at Play; the ship does reach right once. Likely the
same bug; re-test on this build (plan §Open).

**Latest (2026-10-12): `fix/handling-top-speed-label`, ruling HANDLING R1, merged into `main` by its PR.** The
Armory → Handling "Turn rate" slider (inherited from the TS) never changed turning: it scales
top speed on phones (tilt and touch) and the cursor's reach on desktop. User: "Rename it". Now
**Top speed** / "Higher moves faster.", the Settings link reads "Speed & sensitivity: Armory ›
Handling", and the Handling preview no longer turns sharper with the slider. Copy only; feel and
saves unchanged. 854 tests green, gdformat and gdlint clean, 0 SCRIPT ERROR headless. Plan
`docs/superpowers/plans/2026-10-12-fix-handling-top-speed-label.md`. Next: nothing in flight; the user
updates the public guide (perilpoint.newzenith.ph/how-to-play); A55 checks in `VERIFY-ME.md`
§HANDLING R1. Offered, not ruled: the Handling preview turns at 1.0x for every ship; it could
use the equipped ship's `turn_rate` (0.45x-1.60x), as the run does.

**Latest (2026-10-12): `fix/runover-score-and-scheme-cards`, the Run over big score is fixed,
merged into `main` by its PR.** A score of 11+ digits used to widen the sheet past Retry/Menu/Armory. Ruling
RUNOVER R2: `FinalScoreLabel` clips and `RunOverSheet._fit_score` shrinks its font until every
digit fits the left column. 852 tests green, gdformat and gdlint clean, 0 SCRIPT ERROR headless.
The Settings scheme-card clip ("Drag anywhe…") is **not a phone defect**: it shows only with
the desktop-only Keys card (three cards); the phone layout fits. It was left as is. Plan
`docs/superpowers/plans/2026-10-12-fix-runover-big-score.md`. Next: nothing in flight. Ask the user
what to pick up (an A55 look at a big score is optional). Open question 1 (R7/I3) below still
waits for a ruling.

**Latest (2026-10-12): ENH-302, Stick position (GitHub #4), done** — merged into `main` by its
PR. Settings → Controls → Touch stick: Dynamic (default, unchanged) / Left / Right. A fixed stick
sits in that bottom corner (`ANCHOR_INSET` 1.5 radii), is grabbed within `GRAB_FRACTION` 2 radii,
draws at `ANCHORED_SCALE` 1.3x, its base follows an overshooting thumb up to `ANCHOR_LEASH` 1
radius and returns home on release, and it shows faintly at rest (`IDLE_ALPHA` 0.4). Rulings
R1-R5 in `docs/superpowers/plans/2026-10-12-enh-302-joystick-position.md`. A55: pass 1 (0.1.4)
"a bit scuffed" (drift, too small) → R5; pass 2 (0.1.5) "feels better", and the user asked to
merge. The A55 has `build/peril-point-0.1.5-a55.apk` (0.1.5 code 6, A55 key), so the next A55
build must use code 7. The five tunables (`GRAB_FRACTION`, `ANCHOR_INSET`, `ANCHORED_SCALE`, `ANCHOR_LEASH`,
`IDLE_ALPHA`) are provisional; retune on request.

**Also (2026-10-12): `fix/exit-image-leak`, merged (PR #5)** — the suite sometimes printed "Image /
texture RID leaked at exit" yet passed. Cause: the Separate render thread (`thread_model=2`,
P24) drops a texture free queued just before quit, an engine race (0 of 25 runs on Safe, about
1 in 6 on Separate). `tools/run_tests.sh` now runs with `--render-thread safe` and fails any run
that leaks at exit (CONVENTIONS §1.3). The game keeps Separate. Plan
`docs/superpowers/plans/2026-10-12-fix-exit-image-leak.md`.

Next: nothing in flight. Open question 1 (R7/I3, lifetime goals double-count a run) below
still waits for a ruling. (The Run over big score noted here was fixed by RUNOVER R2, above.)

**Latest (2026-10-12): ENH-301, power-ups and coins at a glance, is done: R2 confirmed on the A55**
on branch `ENH-301-powerup-coin-glance` (67/67 test scripts, 831 tests green, gdformat and
gdlint clean; A55 pass done, `VERIFY-ME.md` §ENH-301). User: "power ups and coins can be hard to identify"
in busy play. R1 (pickups drawn over the swarm, 1.3x) was tried on the emulator and replaced by
R2 (user: "keep how it previously was ... but make it bigger. make the glow better. make the
colors more pop out", "a bit smaller" than 1.3): the TS draw order (pickups under enemies),
`PICKUP_DRAW_SCALE` 1.25 (1.15 was "make it bigger"), and a soft saturated glow (`CircleSprites.draw_glow`,
`EntityLayer._glow_color`; pad 20 px, alpha 1.0, saturation x1.25). Render-only. Plan
`docs/superpowers/plans/2026-10-12-enh-301-pickup-glance.md`. Benches: `bench/shot_pickups.gd`
(static, every pickup buried) and `bench/play_pickups.gd` (plays main.tscn windowed). Known: a
pickup fully under a cluster is hidden again, as in the TS. Emulator: the x86_64 image runs the
arm64 debug APK by translation (`--export-debug "Android" build/peril-point-debug.apk`, then
`adb -s emulator-5554 install -r`; check `lastUpdateTime`, it dropped offline once). The A55
has this build (`build/peril-point-0.1.3-a55.apk`, 0.1.3 code 4, A55 key, installed 2026-10-12
18:26), so the next A55 build must use code 5. A55: confirmed ("power ups look good now", "the enhancement for powerups are
confirmed"). Merged into `main` through PR #3. Next: ENH-302 (joystick position, GitHub #4);
brainstorm it with the user first, its open questions are in the issue. Found 2026-10-12: the Run over big score had no width cap; fixed
by RUNOVER R2 (above).

**Latest (2026-09-29): the Settings overflow is fixed** (831 tests green, gdformat and gdlint
clean, 0 SCRIPT ERROR headless; A55 pass pending, `VERIFY-ME.md` §Settings scroll). User: "fix the
menu overflow specially after adding reporting. we are not able to scroll to it." Cause: the
Settings board (`TiltMenu._options_body`) was three columns in an HBox with no scroll view; the
Audio column grew in Week 1 (Vibration, the Data heading, "Share anonymous usage data", the
usage-reporting opt-out) past the A55's height, so the last rows and Reset were off screen and
nothing could scroll. Now the columns sit in `OptionsScroll` (a vertical `ScrollContainer`),
`open_options_modal` keeps the scroll position across the re-render a toggle causes, and drags
that start on a switch scroll the board (`UiTheme.let_drags_scroll`, moved out of `ArmoryUI`,
which now calls it with `[HandlingPreview]`). Tests in `test_tilt_menu.gd`. Verified with
`godot/bench/shot_settings.gd` (windowed shot at 2340x1080, top and end). Not fixed, predates
this: the Touch and Tilt scheme cards clip "Drag anywhe…" and "Tilt the…" at that size.
The arena work below is unchanged and still awaits the A55 pass.
Version is now 0.1.3 (code 4). The shared dev-key APK `godot/build/peril-point-0.1.3.apk`
has everything above (renames, ten themes and skins, arena patterns, Settings scroll). The A55
has the same content as 0.1.2 (code 3, A55 key), so the next A55 build must use code 4.

**Before that (2026-09-29): every arena theme now has its own look, phase 1 (background pattern
and motion) is code-complete** (828 tests green, gdformat and gdlint clean, 0 SCRIPT ERROR
headless; A55 pass pending, `VERIFY-ME.md` §Theme R2). Ruling THEME R2 (user: "arena themes
kinda look similar which makes getting other arenas kinda pointless"; scope: pattern + motion
first, then grid styles, all 16 themes). Plan `docs/superpowers/plans/2026-09-29-arena-looks.md`.
`ArenaThemeConfig.pattern` (`ProgressionManager.ArenaPattern`, 16 distinct values, void is NONE)
picks a procedural effect in `arena_background.gdshader` (moves with `TIME`, no CPU cost):
synthwave sun, nebula stars, matrix code, supernova heat, blueprint drafting, arctic snow,
ember sparks, neon rain, ocean bubbles, desert sand, ph rays, jp ripples, br diagonal bands,
us stars and bars, de three bands. New uniforms `pattern`, `accent` (= `dust_color`, which was
never drawn before), `accent2` (= boundary colour) and `unit` (height / 1080); `GridLayer` and
`ArenaPreview` set them, so the Armory preview matches the run (preview scale floors at 0.5).
Headless tests cannot compile the shader; `godot/bench/arena_sheet.gd` renders a contact sheet
windowed (`build/shots/arena_sheet.png`; `ARENA_SHEET_ONLY=id,id` for a larger subset) and
was reviewed. Not measured: frame time with an effect on the A55 (the effects are per-pixel
GPU work; use `tools/frametime.sh` with a theme equipped). Next: the user's A55 pass, then
phase 2 (a grid line style per theme: lines, dots, crosses, brick, diagonal), plan task 3.

**Before that (2026-09-29): ten new arena themes and enemy skins are code-complete** (825 tests
green, gdformat and gdlint clean; A55 pass pending, `VERIFY-ME.md` §Theme R1). Ruling THEME R1
(user: "more variety to the map backgrounds and enemy backgrounds", "flags" = country flags,
colours only): five concept pairs (`arctic` Arctic Lattice / Frostbite, `ember` Ember Ruins /
Ashen Husk, `neon` Neon Tokyo Night / Sakura Pulse, `ocean` Deep Ocean / Anglerfish, `desert`
Desert Signal / Sandstorm) and five country-colour pairs (`ph` Perlas Archipelago /
Sampaguita, `jp` Rising Sun / Hinode, `br` Carnaval / Verde Ouro, `us` Liberty Grid / Star
Spangled, `de` Black Forest / Gilded Ember), appended to both catalogs in
`progression_manager.gd` (16 each; TS six first, so saved ids keep their meaning). Arena
prices 1400 (concept) and 1600 (flags), skin prices 1600 and 1800 (guesses; tune on the
device). Each skin paints a pattern from four shared shapes (rays, rings, stripes, dots) in
`enemy_textures.gd` (SKIN R1). No flag emblem is drawn. The two catalog parity tests now
check the TS six and `>=`; the new ones are in `test_progression_catalogs.gd`. Not done: no
unlock goals for the new items (the goal catalog stays the TS 57), no per-theme grid shape or
motion (roadmap option 2/3, only if the recolours feel samey). Version is 0.1.2 (code 3); the
A55 has this build (`peril-point-0.1.2-a55.apk`), the shared dev-key APK
`peril-point-0.1.2.apk` was built BEFORE this change and must be rebuilt to include it.

**Before that (2026-09-29): MVP Week 1, the mode renames are done** (821 tests green, gdformat
and gdlint clean; A55 pass pending, `VERIFY-ME.md` §MVP Week 1 — mode names). Ruling MVP R4:
Standard → **Survival**, Gauntlet → **Corridor**, Code Red → **Overdrive**. Strings only:
`GameOptionsManager` mode names, `GoalManager` titles/descriptions of the three mode goals,
`EffectLayer.banner_copy` (`OVERDRIVE PROTOCOL`, `THE CORRIDOR`, `SURVIVAL`), and the
tests. The `GameMode` ids, goal ids (`mode_code_red_30`), metrics and save keys are
unchanged, so old saves load. The parity tests keep the TS fixtures and map the names
(`MODE_DISPLAY_NAMES`, `_renamed`). Not renamed: the achievement "Red Alert Survivor", the
`web/src/tilt-to-live/` citations. Store text must not say Tilt to Live. Next in Week 1,
unblocked once the tablet is on `adb`: the tablet texture error (no cause found by reading
the code; needs a dev-key debug build and logcat). Analytics steps 3-4 still wait on the user
saying "Firebase done". Version is now 0.1.2 (code 3): the shared dev-key APK is
`godot/build/peril-point-0.1.2.apk`; the A55 has the renames as 0.1.1 (code 2, A55 key), so
the next A55 build must use code 3 or higher.

**Before that (2026-09-29): MVP Week 1, the AAB export is done with an interim upload key** (no game code changed, so tests were not re-run; a dev-key AAB exported and
`jarsigner -verify` said `jar verified`). `PERIL_AAB=1 tools/release.sh` exports
`godot/build/peril-point-<version>.aab`: it flips `gradle_build/export_format` to 1 for
that run and restores it on exit, so the preset stays on APK for the tester builds.
`tools/make-upload-key.sh` was run by the user (`PERIL_UPLOAD_PW` skips the prompt): it made
`~/.android/peril-upload.keystore` + `.env`, an interim key to replace at deployment; I never
read those files. An AAB signed with it exported (`PERIL_AAB=1 PERIL_KEYS=~/.android/peril-upload.env`). Steps in
`VERIFY-ME.md` §MVP Week 1 — AAB. Note for step 3 of analytics: the preset has
`permissions/internet=false`; Firebase needs it on. Next in Week 1, unblocked: mode
renames (needs the user's names), the tablet texture error. Analytics steps 3-4 still wait
on the user saying "Firebase done".

**Before that (2026-09-29): MVP Week 1, haptics are code-complete** (821 tests green, gdformat
and gdlint clean; A55 pass pending, `VERIFY-ME.md` §MVP Week 1 — haptics). `src/core/haptics.gd`
is an autoload (`Haptics`) that listens to `GameEvents`: a nuke (`weapon_activated`), the
last life lost (`life_lost(0)`) and the new `GameEvents.close_call` (emitted by
`RunController._collide` beside the audio call). `Haptics.vibrate` is a Callable so tests
record pulses. `GameSettings.haptics_enabled` (save key `hapticsEnabled`, Settings → Audio
"Vibration", `VibrationSwitch`) is applied at boot in `GameRoot._ready` and on toggle.
`export_presets.cfg` `permissions/vibrate=true`. Pulse lengths are guesses to tune on the
device. Next in Week 1, unblocked: AAB + upload key, mode renames (needs the user's names),
the tablet texture error. Analytics steps 3-4 still wait on the user saying "Firebase done".

**Before that (2026-09-29): MVP Week 1, the Android back button and focus-loss pause are
code-complete** (812 tests green, gdformat and gdlint clean; A55 pass pending,
`VERIFY-ME.md` §MVP Week 1). `project.godot` `config/quit_on_go_back=false`;
`GameRoot.go_back()` (called from `NOTIFICATION_WM_GO_BACK_REQUEST`) and
`pause_on_focus_loss()` (from `APPLICATION_FOCUS_OUT` and `APPLICATION_PAUSED`); tests in
`tests/test_go_back.gd`. Next in Week 1, unblocked: haptics, then AAB + upload key, mode
renames (needs the user's names), the tablet texture error. Analytics steps 3-4 still wait
on the user saying "Firebase done".

**Before that (2026-09-29): MVP Week 1, analytics steps 1-2 are done; steps 3-4 wait on the
user** (803 tests green, gdformat and gdlint clean; nothing run on a device). Ruling MVP R6:
Firebase Analytics + Crashlytics behind one `Telemetry` autoload facade. Spec:
`docs/superpowers/specs/2026-09-29-analytics-crashes-design.md`. Built (spec §6 step 1):
`src/core/telemetry.gd` (autoload; `log_event`, `run_start`, `run_end`, `upgrade_buy`, and
`achievement` from `GameEvents.goal_completed`), `src/core/telemetry_backend.gd` (the null
backend; the Firebase one will extend it), `tests/recording_telemetry_backend.gd`,
`GameStats.killer` (set in `RunController._collide`, and `"maze_wall"` for a Gauntlet crush),
`GameSettings.share_usage_data` (Settings row "Share anonymous usage data", `UsageSwitch`).
Callers: `GameRoot._begin_cinematic` (run_start), `GameRoot._on_run_ended` (run_end),
`ArmoryUI._log_buy` (upgrade_buy). No sim class calls Telemetry. Step 2 done: `VERIFY-ME.md`
§MVP R6 part B is the user's Firebase checklist (project, package `com.jtg.perilpoint`, the
A55 debug-key and dev-key SHA-1s already filled in, `google-services.json` into
`godot/android/build/`). **Blocked on the user saying "Firebase done".** Then spec §6 step 3
(check which Firebase plugin is maintained for Godot 4.7 or write a small Kotlin one; Gradle
plugins; symbol upload in `tools/release.sh`; DebugView on the A55) and step 3 also wires the
events not yet sent (`mode_select`, `first_run_hint`, `settings_change`, `screen`, user
properties, `Log.error` forwarding), then step 4 (forced test crash). Tests that swap
`Telemetry.backend` must restore it and reset `Telemetry.run_count`. **Meanwhile, unblocked
and next in the roadmap's Week 1:** AAB + upload key, mode renames (needs the
user's names), the tablet texture error.

**Before that (2026-09-29): MVP Week 1, first run is code-complete** (786 tests green, A55
pass pending, `VERIFY-ME.md` §MVP R5). `RunController.is_first_run`
(`first_run_done` unset and `best_score == 0`) gently ramps the swarm (0.5x) and shows
the HUD's one-time hint.

**Before that (2026-09-29): the game is feature-complete and in players' hands; next is the
MVP for a Play Store closed test.** The plan for that, with the user's rulings and
estimates, is `docs/superpowers/plans/2026-09-29-mvp-roadmap.md`. Start with its Week 1
(analytics and the first run). Release 0.1.1 (code 2) is on the A55 and on a Galaxy Tab
S9 FE (`R52WA05819H`). The tablet logs an empty-image texture error on two first frames,
still to find; see the roadmap.

**Earlier (2026-09-28): the game is feature-complete and shareable.** Every module is
done: M0–M11, the M11c performance work on the C++ path, and the user-requested
reworks since (economy, Armory, icons, achievements, keystones, UI R1–R12, SKIN R1,
ARMORY R5–R7). Active plan: `docs/superpowers/plans/2026-09-28-achievements-keystones-ui.md`.
The head of `## Next` below says what to do first; `README.md` says what the project is.

- **Release builds.** `tools/release.sh` exports a signed release APK
  (`godot/build/peril-point-<version>.apk`). The release native library is
  `godot/bin/libperil.android.template_release.arm64.so`. The signing key is a
  throwaway dev key, `~/.android/peril-dev-release.keystore`; its alias and password
  are in `~/.android/peril-dev-release.env`, outside git. Replace it before a store
  release.
- **The A55 build.** The user's A55 runs a release build signed with Godot's debug
  key, so it installs over the old debug install and keeps the save:
  `PERIL_KEYS=~/.android/peril-a55.env PERIL_OUT=peril-point-0.1.0-a55.apk tools/release.sh`,
  then `adb -s RRCXB04L8EJ install -r`. A backup of the save from 2026-09-28 is in
  `~/Documents/PerilPoint-A55-save-backup-2026-09-28/`. The A55 also has the Play Store build
  (`ph.newzenith.perilpoint`, installer `com.android.vending`); both show as Peril Point, so
  after a sideload, launch `com.jtg.perilpoint` with
  `adb -s RRCXB04L8EJ shell monkey -p com.jtg.perilpoint -c android.intent.category.LAUNCHER 1`. That install is no longer
  debuggable, so `run-as` save reads stop working until a debug build goes back on.
- **Native extension required.** Enemies are the C++ class `PerilEnemy`, so the game
  does not parse without `godot/bin/libperil.*`.

The paragraphs after this one are older history, kept for their evidence.

**M11c part 1 — Performance: code-complete, A55 measurement pending
(2026-09-26).** Plan `docs/superpowers/plans/2026-09-26-m11c-performance.md`;
its execution rulings are in the plan's task Status lines and below (the git-ignored ledger was cleared after the final review).
The user played HEAD `fbf7e94` on the A55 and reported frame collapse with
many things on screen, spikes on wall-formation spawns and power-up mass
kills, an off-centre cold open, a start ring too tight to escape, and
"some options don't show correctly" (parked by the user). A temporary probe
found it was CPU time in GDScript: at ~110 enemies, fps 12–14, the 120 Hz sim
spiralling to 8 ticks per frame, swarm 22–27 ms, grid 18–19 ms and entity draw
14–17 ms per frame. **`dumpsys gfxinfo` sees 0 Godot frames**; use
`tools/frametime.sh` (SurfaceFlinger) and the debug `PERF` log line.

User rulings (2026-09-26): no catch-up cap and no slow motion (P2 withdrawn);
options display out of scope for now; widen the start ring (P8); execute
natively. What landed, with desktop bench numbers (`godot/bench/`, 115
enemies on the A55's 2162×1056 arena, before → after):

| Change | Ruling | Desktop effect |
|---|---|---|
| debug-only `PerfProbe` (one `PERF` line/s) + `tools/frametime.sh` + `godot/bench/` | P1 | — |
| separation prefilter + packed 64-bit copies + dx² early reject, bit-exact (oracle test) | P4 | separation 2,100 → 230 µs/tick; swarm 2,400 → 430 |
| grid sleeps while gridlines are off; packed 64-bit arrays; blasts scan an exact window (radius + tracked max displacement), bit-exact | P3 | grid 790 → 0 µs/tick (340 awake); 30-kill tick ~7,000 → 210 µs |
| enemy dots, frozen dots and particles draw from shared disc/ring `GradientTexture2D`s (`render/circle_sprites.gd`) | P5 | `draw_circle` 7.5 µs and `draw_arc` 7.3 µs vs `draw_rect` 0.26; entity draw 5,200 → 800 µs/frame |
| `score_changed` only on change; chip restyled only on a tier change | P6 | removes 120 StyleBox rebuilds/s |
| Classic start ring radius `max(260, 0.42 × short side)` (~443 px on the A55) | P8 | — |
| cold-open stack grows both ways from its centre anchor (it grew right/down from a 0×0 pre-tree size: 529 px right, 99 px low at 2340×1080) | Task 7 | — |

Verification (fresh, 2026-09-26): `OK: 57/57 scripts collected, all tests
passed` (652 tests); `gdformat --check` 103 files unchanged; `gdlint` clean;
headless `--quit-after 240` 0 SCRIPT ERROR; `DIVERGENCE` total 264. The A55
dropped off `adb` at 02:11 and did not return, so `VERIFY-ME.md` §M11c part 1
(6 checks) is unrun. Finding, not fixed (options parked): `calibrate_screen.gd:175`
anchors a block `PRESET_CENTER_LEFT`, the same grow-direction pattern as the
cold-open bug.

**Final whole-branch review** (fresh opus reviewer, `fbf7e94..1151785`): 0
Critical, 1 Important, 6 Minor; both bit-exact claims and the grid-sleep/P6
wiring verified. **Fixed:** large thin texture rings blurred (one texel ≈ 2.9
px on the 85 px kill shockwave). `CircleSprites.ring_is_faithful` (texel ≤ 1
px, ratio ≥ 0.02) now gates particle rings; unfaithful ones keep `draw_arc`
(2 tests RED→GREEN, 654 tests). **Deferred minors** (for the user):
`circle_sprites.gd` `AA`/`DISC_EDGE`/`0.001` lack per-line Law 1 tags;
`PerfProbe.now()` still calls `Time.get_ticks_usec()` in release (~2,500/s,
negligible); **P3 wording**: waking the grid resumes its frozen ripple, it
is not "flat" as the plan says — the code's behaviour is the intended one, do
not change it to match the plan; `reset_run` emits `score_changed` twice on
the first tick (harmless); no test pins `apply_readability` → `_grid.awake`;
`godot/bench/bench_visual.gd` is scratch, and `export_presets.cfg` has no
`exclude_filter`, so `bench/` and `tests/` ship in the APK. Declined by the
reviewer: whether a freshly made `GradientTexture2D` shows a placeholder for
one frame (pre-warm at boot if the A55 shows a flicker). **Next: see Next
below.**

**M11b — Entrance cinematic: code-complete, device pass pending.** Exit: the
commit carrying this text (2026-09-26) — a commit cannot cite its own SHA.
Plan `docs/superpowers/plans/2026-09-20-m11b-entrance-cinematic.md` (3 tasks,
rulings R1–R12, 3 open questions); the user approved R1 (the ColdOpen board's
sizes win over the TS DOM's), R8 (the TS `returnToMenu` skip quirk, ported as
written), R10 (every Retry replays the cold open) and R12 (runs now start
with the handover armada, 2.5 s shield and nuke) as written on 2026-09-26.
Execution: subagent-driven (Task 1, Task 2, then a final whole-branch
review). `TiltEntranceCinematic.ts` ports to `src/ui/entrance_cinematic.gd`,
drawn on the ColdOpen board; the `CINEMATIC` phase now sits between Play/
Retry/Restart and a playing run. Full section: `## M11b — what landed`
below. Device checks: `VERIFY-ME.md` §M11b (A55 absent from `adb` on
2026-09-26 — only an emulator was attached). **Next: plan M11c** (see Next
below).

**M11a — Menu, Settings, Calibrate: code-complete, device pass pending.**
Exit: the commit carrying this text (2026-09-25) — a commit cannot cite its
own SHA (M5/M6 precedent). Plan
`docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md` (8 tasks,
rulings R1–R17). The user split M11 into M11a (menu, Settings, Calibrate),
M11b (entrance cinematic) and M11c (export + device pass) on 2026-09-25, and
ruled Q1 = fix Reset (also deletes progression and best score,
`DIVERGENCE(M11a Q1)`, R10) and Q2 = apply Settings' Sound/Music at once
(`DIVERGENCE(M11a Q2)`, R9); Q3 (Android back) stays open for the device
pass. Execution: subagent-driven (one implementer per task, then review), 8
tasks landed. Full section: `## M11a — what landed` below. Device checks:
`VERIFY-ME.md` §M11a (A55 absent from `adb` on 2026-09-25). **M11b is now
code-complete** (see the M11b paragraph above and Next below).

**M6 — Generative music: code-complete, device pass pending.** Exit verified at
`d489691` (2026-09-25); the exit commit carries this text. Plan
`docs/superpowers/plans/2026-09-20-m6-generative-music.md`. User ruling M6 R1: the TS
arrangement takes no game input, so `tools/bake-audio/bake_music.mjs` renders it once,
through `TiltAudio.ts`'s own `scheduleStep`, to a seamless loop
(`godot/assets/audio/music/music_loop.wav`). `AudioBank` plays it, and a run starts it in
`RunController.reset_run` until M11's cinematic exists. Full section:
`## M6 — what landed` below. Device checks: `VERIFY-ME.md` §M6. **Next: plan M11**
(see Next below).

**M5 — Audio bake and SFX: code-complete, device pass pending.** Exit verified at
`539d654` (2026-09-25); the exit commit is the one carrying this text. Plan
`docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md`. 37 SFX baked from
`TiltAudio.ts` to WAV (M5 R1) and played through a 32-voice `AudioBank`; music is
still `TODO(M6)`. Full section: `## M5 — what landed` below. Device checks:
`VERIFY-ME.md` §M5 (A55 absent on 2026-09-25).

**M10 — Modes: code-complete, device pass pending.** Final commit `2e6b2d2`
(exit commit for the whole module — final review fixes F-1..F-4 landed at
this same SHA). Plan `docs/superpowers/plans/2026-09-20-m10-modes.md`. Full
section: `## M10 — what landed` below.

**Final review fixes (M9)** (`.superpowers/sdd/2026-09-20-m9-milestones/final-review.md`,
`final-fix-report.md`, commit `cd77de6`): **I-1** — Run over now fills/shows 450 ms after
`run_ended`, ported from `TiltGame.ts:2084-2151` (`HudController._on_run_ended`
starts a one-shot `Timer`; stopped on Retry or any phase change so a stale
fill cannot reopen the sheet), so a total-goal completion on the death tick
(step 8, `run_controller.gd:227`) now reaches "Points earned" and the
balance. One script-level regression test pins the death-tick order (487th
test, +1 over Task 7's 486). **M-1, M-3, M-4** — PORT-NOTE added at `goals_hud.gd`'s Escape
handling; `VERIFY-ME.md`'s M9 Toast line reworded (Armory-close/mid-run total,
calibrate marked pending I-2); `goal_manager.gd:24`'s stale process-note
replaced. **I-2** (toast under Pause/Armory) is parked for the user — plan
Open question 6. Full section: "## M9 — what landed" below.

Last completed module before M10: **M9 — Milestones**, code complete
2026-09-24 (head `cd77de6`).
Code-complete, **device pass pending** (none ticked in `PORT-PROGRESS.md`,
all marked `DEVICE PASS PENDING`):
**M2.5 — Mobile feel** (head `37f9fd4` + the user's tuning `c023e09`),
**M3 — Enemy roster** (head `5bb5cc9`), **M4 — Weapons** (head `0b7fccf`),
**M7 — Persistence and economy** (head `dba9126`),
**M8 — Armory UI** (head `f0cac03`; its device pass is folded into M8.5's),
**M8.5 — Interface rework** (head `541e92c`),
**M9 — Milestones** (head `cd77de6`; its device pass is its own, `VERIFY-ME.md` §M9),
**M10 — Modes** (head `2e6b2d2`; its device pass is its own, `VERIFY-ME.md` §M10,
10 unticked checks — the A55 was absent from `adb` on 2026-09-25).
Also landed after M4/M8, still device-unchecked: **HUD score feedback**
(`9cc3e8f..31bf2ce`) and the **mobile scale split** (2026-09-22, see its
section below; the user skipped its A55 pass while the phone is absent).

What M8.5 did: the mobile-redesign boards (`peril-point-mobile-redesign/*.dc.html`)
became the visual authority for every screen (spec
`docs/superpowers/specs/2026-09-23-mobile-interface-system-design.md`, plan
`docs/superpowers/plans/2026-09-23-m8.5-interface-rework.md`). Fonts
(Archivo, IBM Plex Sans/Mono, OFL) are bundled; `ui/ui_theme.gd` replaces
`armory_theme.gd` with the System board's tokens and variations; HUD, Pause,
Run over and all five Armory tabs are rebuilt on it. Table in
`## M8.5 — what landed`.

**ui_scale ruling** (spec §4.3, plan time): `ui_scale = min(short/390,
long/844)`, clamped 0.75–3.0 — the width term keeps a 1280×720 window (1.52)
from overflowing the 700-px Run over sheet.

**Rulings A–P** (the plan's "Rulings" table has the citations):
- A — HUD lives hidden for a one-life run; count = `maxLivesThisRun`.
- B — weapon timer: shield wins, else the longest-remaining timed weapon.
- C — multiplier `"n×"` Chip tinted by `tier_color_for`, hidden at 1×.
- D — Pause stats `"<score> · <m:ss> · <mode>"`.
- E — Pause Calibrate shown only for the GYRO scheme.
- F — Calibrate = request permission, then calibrate; the toast is `TODO(M9)`.
- G — Sound/Music switches write and save options; music only while PLAYING.
- H — New best banner iff `is_new_best and best_score_diff > 0`.
- I — Run over earned = coin points (+ milestones, `TODO(M9)`); Spend = balance.
- J — Best chain `"%d×"` of `max(1, max_multiplier)`.
- K — cost buttons: grouped digits, no unit; ship buy `"600 pts"`; `"Max"` disabled.
- L — keystone locked = not unlocked and not affordable → LockedCard + lock glyph.
- M — Armory captions keep the TS strings in caps; preview caption/legend use spec strings.
- N — TS content with no board slot kept in board style (`TrackValue_*`, `LoadoutName`).
- O — Handling: tilt slider 0.5–2.0 (stored clamp 0.4–2.5); Reset still resets deadzone to 4.0.
- P — `ControlPicker` is Segmented, Touch | Tilt (+ Keyboard off-mobile), no `ButtonGroup`.
- Pre-flight M14 (applied in Tasks 6–7): spec-quoted explain lines win over TS strings.

Branch: `feat/godot-port` (pushed to `origin` on 2026-10-11 and fast-forwarded into `main`).

> ### ⚠ Read `godot/VERIFY-ME.md`
> Every check that needs a hand on the phone or a decision from the user is
> collected there, per module. M2.5's constants are all provisional until its
> section is run. **M7, M8 (folded into M8.5), M8.5, M9, M10, "Mobile
> scale split" and M11a device checks are all unrun** — the A55 has been
> absent from `adb` since 2026-09-21 (confirmed absent again 2026-09-25 at
> the M11a exit). The M8.5 debug APK exported at 31,561,743
> bytes (+1,030,646 over M8, mostly fonts).

## How to verify right now

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

node tools/bake-audio/bake_sfx.mjs | tail -1     # expect: OK: 37 files in …
node tools/bake-audio/bake_music.mjs | tail -1   # expect: OK: music_loop.wav 1263761 frames (loop_end) in …
git status --short godot/assets/audio/           # expect: empty (both bakes are deterministic)
tools/run_tests.sh                        # expect: OK: 50/50 scripts (559 tests, 17696 asserts)
gdformat --check godot/src godot/tests    # expect: 90 files would be left unchanged
gdlint godot/src godot/tests              # expect: Success: no problems found
grep -rn "TODO(M6)" godot/src/ godot/tests/   # expect: nothing
grep -rniE "ff4757" godot/src/ui/         # expect: nothing (rule 01)
grep -rn "DIVERGENCE" godot/src/ | wc -l  # expect: 181
grep -rn "DIVERGENCE(M6" godot/src/ | wc -l   # expect: 3
"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "SCRIPT ERROR"   # expect: 0
"$GODOT" --headless --path godot --quit-after 120 2>&1 | grep -c "missing baked"   # expect: 0
git checkout godot/project.godot          # headless runs strip one default-valued line; never commit that
```

Every command above was run fresh at M9 Task 7 (2026-09-23) and passed:
`OK: 48/48 scripts collected, all tests passed` (Tests 486, Passing 486,
Asserts 5462; GUT also prints `Deprecated 5`, pre-existing); `86 files would
be left unchanged`; `Success: no problems found`; the TODO(M9) grep printed
nothing; the ff4757 grep printed nothing; DIVERGENCE `174`, UI-SYSTEM `106`;
SCRIPT ERROR count `0`; `git status --short` empty afterwards (working tree,
before this task's own changes were staged). The module's leftover-marker
grep (a `TODO` tagged with the module id) finds nothing under `godot/`.

Re-run after the final review's I-1 fix and again fresh at Task 9's exit
(2026-09-24, commit `cd77de6`): `OK: 48/48 scripts collected, all tests
passed` (Tests 487, Passing 487, Asserts 5467 — +1 script-level regression
test for the death-tick order over Task 7's 486); `86 files would be left
unchanged`; `Success: no problems found`; TODO(M9) grep empty; ff4757 grep
empty; DIVERGENCE `174`, UI-SYSTEM `106` (unchanged from Task 7 — the I-1 fix
added no new UI literals); SCRIPT ERROR count `0`; `git status --short` empty
before and after. See "Final review fixes" above and "## M9 — what landed"
below.

Re-run fresh at **M10 Task 5's exit** (2026-09-25, temporary Pause mode
picker, R1): `OK: 49/49 scripts collected, all tests passed` (Tests 519,
Passing 519, Asserts 17277); `gdformat --check` — `88 files would be left
unchanged`; `gdlint` — `Success: no problems found`; DIVERGENCE **177** total,
`DIVERGENCE(UI-SYSTEM)` **106** (unchanged), `DIVERGENCE(M10 R1)` **3** (the
picker's stand-in tags in `pause_sheet.gd` and `hud_controller.gd`).

Re-run fresh again at **M10 Task 7's exit** (2026-09-25, commit `2e6b2d2`,
after the final-review fix wave F-1..F-4 — see "## M10 — what landed"):
`OK: 49/49 scripts collected, all tests passed` (Tests **520**, Passing 520,
Asserts **17359** — +1 script over Task 5's 519, the F-1 stripe brute-force
equality test); `gdformat --check` — `88 files would be left unchanged`;
`gdlint` — `Success: no problems found`; `grep -rn "TODO(M10)"` printed
nothing; `grep -rniE "ff4757" godot/src/ui/` printed nothing; DIVERGENCE
**177** total, `DIVERGENCE(UI-SYSTEM)` **106**, `DIVERGENCE(M10 R1)` **3**
(all unchanged from Task 5 — F-1..F-4 added no new literals or picker tags);
headless `--quit-after 120` SCRIPT ERROR count **0**; `git status --short`
empty both before this task's own doc changes were staged and after
`git checkout godot/project.godot`. This is the module's exit evidence —
M10 is now code-complete, device pass pending.

Re-run fresh at **M5 Task 6's exit** (2026-09-25, at `539d654`): bake printed
`OK: 37 files` and left `godot/assets/audio/sfx/` unchanged; `OK: 50/50 scripts
collected, all tests passed` (Tests **549**, Passing 549, Asserts **17667**);
`90 files would be left unchanged`; `Success: no problems found`; TODO(M5) and
ff4757 greps empty; DIVERGENCE **178**, `DIVERGENCE(M5 R2)` **1**; headless
SCRIPT ERROR **0**, "missing baked sfx" **0**; `git status --short` empty after
`git checkout godot/project.godot`. This is M5's exit evidence.

Re-run fresh at **M6 Task 4's exit** (2026-09-25, at `d489691` plus the review's
VERIFY-ME wording fix): the SFX bake printed `OK: 37 files`, the music bake printed
`OK: music_loop.wav 1263761 frames` (`kept`: within 1 LSB of the committed file), and
`godot/assets/audio/` was unchanged; `OK: 50/50 scripts collected, all tests passed`
(Tests **559**, Asserts **17696**); `90 files would be left unchanged`; `Success: no
problems found`; TODO(M6) and ff4757 greps empty; DIVERGENCE **181**,
`DIVERGENCE(M6` **3**; headless SCRIPT ERROR **0**, "missing baked" **0**. This is
M6's exit evidence.

Re-run fresh at **M11a Task 8's exit** (2026-09-25):

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
tools/run_tests.sh                              # OK: 53/53 scripts (609 tests, 17968 asserts)
gdformat --check godot/src godot/tests          # 96 files would be left unchanged
gdlint godot/src godot/tests                    # Success: no problems found
grep -rn "TODO(M11)" godot/src godot/tests      # nothing
grep -rnE "M10 R1([^0-9]|$)" godot/src          # nothing (plain "M10 R1" also hits R10/R11)
grep -rniE "ff4757" godot/src/ui/               # nothing (rule 01)
grep -rn "DIVERGENCE(M11a R1)" godot/src | wc -l   # 3
grep -rn "DIVERGENCE(M11a Q[12])" godot/src | wc -l   # 2
grep -rn "DIVERGENCE" godot/src/ | wc -l        # 232
"$GODOT" --headless --path godot --quit-after 240 2>&1 | grep -c "SCRIPT ERROR"   # 0
"$ADB" devices                                  # empty — A55 absent
git checkout godot/project.godot
git status --short                              # only this task's doc/src changes before staging
```

`OK: 53/53 scripts collected, all tests passed` (Tests 609, Passing 609,
Asserts 17968 — unchanged from Task 7); `96 files would be left unchanged`;
`Success: no problems found`; every grep above matched its expected count;
DIVERGENCE total **232** (unchanged from Task 7); headless `--quit-after 240`
SCRIPT ERROR count **0**; `"$ADB" devices` listed nothing (A55 absent from
`adb`). This was M11a's first exit-evidence pass, before the controller's own
review of `91ea153` (below).

Re-run fresh after the **controller's fix-round 1** (2026-09-25, same-day
follow-up commit): the I-2 addition got retagged `DIVERGENCE(M11a I-2)` (Law
4 — new behaviour, no TS counterpart, so `PORT-NOTE` was the wrong tag), and
two regression tests were added (I-2's stale-Pause-switch fix,
I-1(b)'s launch_run-must-not-recalibrate fix), both proven RED before the fix
and GREEN after by temporarily reverting each fix in turn.

```bash
tools/run_tests.sh                              # OK: 53/53 scripts (611 tests, 17972 asserts)
gdformat --check godot/src godot/tests          # 96 files would be left unchanged
gdlint godot/src godot/tests                    # Success: no problems found
grep -rn "DIVERGENCE(M11a I-2)" godot/src | wc -l  # 2
grep -rn "DIVERGENCE" godot/src/ | wc -l        # 234
"$GODOT" --headless --path godot --quit-after 240 2>&1 | grep -c "SCRIPT ERROR"   # 0
git checkout godot/project.godot
```

`OK: 53/53 scripts collected, all tests passed` (Tests **611**, Passing 611,
Asserts **17972** — +2 over the first pass, the two new regression tests);
`96 files would be left unchanged`; `Success: no problems found`; DIVERGENCE
total **234** (+2 over the first pass — the `options_closed` signal
declaration and the `_on_options_closed` doc comment, the two I-2 sites; the
`.connect()` call site keeps a plain comment, not its own tag, so the count
isn't triple-counted); headless `--quit-after 240` SCRIPT ERROR count **0**.
This is M11a's exit evidence — M11a is now code-complete, device pass
pending.

`--check-only -s` on `src/meta/progression_manager.gd`, `game_options.gd`,
`save_store.gd`, `sim/coin_system.gd` each fail with `Identifier not found:
Log` or `GameEvents` — **expected and inconclusive**: `--check-only` does not
load autoloads, so any file that calls `Log.*` or `GameEvents.*` at class
scope fails this check regardless of correctness. The real compile evidence
is `tools/run_tests.sh` passing: it compiles every script under the project's
nine warnings-as-errors. Don't read a `--check-only` failure on these four
files as a regression.

Re-run fresh at **M11b Task 3's exit** (2026-09-26, after the final
whole-branch review's fixes F-1..F-3):

```bash
cd /c/Users/Jesury/Documents/Personal/dread-flock
GODOT="/c/Users/Jesury/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
tools/run_tests.sh                              # OK: 54/54 scripts (631 tests, 18076 asserts)
gdformat --check godot/src godot/tests          # 98 files would be left unchanged
gdlint godot/src godot/tests                    # Success: no problems found
grep -rn "TODO(M11b)" godot/src godot/tests     # nothing
grep -rn "TODO(M11c)" godot/src | wc -l         # 4 (the M11a count of 3 + the ship glow, R3)
grep -rniE "ff4757" godot/src/ui/               # nothing (rule 01)
grep -rn "DIVERGENCE" godot/src/ | wc -l        # 244 (234 + 10 ColdOpen.dc.html tags)
"$GODOT" --headless --path godot --quit-after 240 2>&1 | grep -c "SCRIPT ERROR"   # 0
"$ADB" devices                                  # only emulator-5554 — A55 absent
git checkout godot/project.godot
git status --short                              # only this task's doc changes before staging
```

`OK: 54/54 scripts collected, all tests passed` (Tests **631**, Passing 631,
Asserts **18076** — +20 over the Task 2 exit's 611: Task 1 landed 621 and
Task 2 landed 630, then the final review's F-3 fix added one left-click-only
regression test); `98 files would be left unchanged`; `Success: no problems
found`; every grep above matched its expected count; `DIVERGENCE` total
**244**; headless `--quit-after 240` SCRIPT ERROR count **0**; `"$ADB"
devices` listed only `emulator-5554` (the A55 was absent). This is M11b's
exit evidence — M11b is now code-complete, device pass pending. Full
report: `.superpowers/sdd/2026-09-20-m11b-entrance-cinematic/task-3-report.md`.

## App identity and toolchain

| | |
|---|---|
| Package / label | `com.jtg.perilpoint` / **Peril Point** |
| Godot | `4.7.2.stable` — **not on PATH**, use the path above, always the `_console` exe |
| GUT | 9.6.1 vendored at `godot/addons/gut/` (never lint/format it) |
| gdtoolkit | 4.5.0 on PATH |
| Device | **SM_A556E** (Galaxy A55), serial `RRCXB04L8EJ`; always pass `-s` |
| ADB | `C:\Users\Jesury\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| Native (C++) | GDExtension `PerilNative` + `PerilEnemyDrawer` (N4) + `PerilParticle`/`PerilParticleDrawer` (N7) + `PerilEnemy` (the enemy record; required since N3 — the game does not parse without the library) in `native/` (godot-cpp 10.0.0 submodule, `api_version=4.7`); outputs `godot/bin/libperil.*` (committed), registered by `godot/peril_native.gdextension`. SCons 4.11 via `python -m SCons` (pip --user). NDK r29 at `Sdk/ndk/29.0.14206865`. Build from `native/`: `python -m SCons platform=windows target=template_debug` and `ANDROID_HOME=C:/Users/Jesury/AppData/Local/Android/Sdk python -m SCons platform=android arch=arm64 target=template_debug ndk_version=29.0.14206865` (`template_release` for release exports). Flags: `-ffp-contract=off` on clang (bit-exact with GDScript). Close the editor before rebuilding the DLL (it locks it). After a fresh clone: `git submodule update --init`. |
| macOS (second dev machine) | `libperil.macos.template_debug.universal.dylib` (committed) loads the extension in the macOS editor and test runs; rebuild it from `native/` with `python -m SCons platform=macos arch=universal target=template_debug`. `tools/*.sh` lack the exec bit, so run them with `bash`, and set `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`. The P32 missile hash is per platform (`PRE_P32_HASHES` in `tests/test_weapon_missiles.gd`): arm64 rounds some float math differently from x86_64, so an unrecorded `<OS>/<arch>` reports pending. |

The source web game keeps the name *Tilt to Live* in `web/src/tilt-to-live/`
and in every `# PORT:` citation. Never rename those — Law 1 depends on them.

## M2.5 — what landed

Spec `docs/superpowers/specs/2026-09-20-m2.5-mobile-feel-design.md`; plan
`docs/superpowers/plans/2026-09-20-m2.5-mobile-feel.md`. 23 commits,
`7de1fa2..37f9fd4`.

| Area | Files |
|---|---|
| Control-scheme persistence | `src/native/control_settings.gd` → `user://peril_point_settings.json` |
| Tilt rework (deferred calibration, one rotation transform, sensitivity/smoothing) | `src/input/tilt_input.gd` |
| Floating joystick | `src/native/floating_joystick.gd`, `src/render/joystick_layer.gd` |
| Arena inset (origin-offset model) | `src/core/game_root.gd` (`arena_origin`, `arena_inset()`, `MAX_ARENA_SCALE`), the four render layers, `src/input/touch_input.gd` |
| Picker, pause, UI scale, HUD anchoring | `src/ui/control_picker.gd`, `src/ui/hud_controller.gd`, `scenes/control_picker.tscn`, `scenes/main.tscn` |
| Tests | `tests/test_control_settings.gd`, `test_floating_joystick.gd`, `test_arena_inset.gd`, `test_tilt_input_device.gd`, `test_main_scene.gd` (+ additions to existing specs) |

**Deliberately untouched (spec §2.3):** `player_ship.gd`, `enemy_swarm.gd`,
`weapon_system.gd`, `run_controller.gd`, `particle_engine.gd`,
`score_manager.gd`. The inset is an origin offset; the simulation never learns
it exists. Verified zero changes across the whole range.

**Deferred to M11 knowingly:** death-screen asset research (spec §7.5, D8).

### Why `MAX_ARENA_SCALE` is 1.75 (read before touching it)

`arena_scale()` is `clamp(min(w,h)/680, 0.60, MAX_ARENA_SCALE)`, cited from
`TiltGame.ts:2422-2431`. On the desktop window (1267×717) the raw value is
1.054 — under the old 1.15 ceiling and confirmed good by the user. On the A55
(2340×1080) the raw value is 1.588 and the old ceiling cut it to 1.15; that cut
*was* the "everything is too small" defect. The proportion the phone needs
(1080/717 = 1.506) equals the formula's own unclamped ratio (1.588/1.054), so
the formula was always right. A post-hoc multiplier was rejected because it
would also inflate the desktop. `tests/fixtures/arena_scale.json` is TS ground
truth and must **not** be regenerated; `test_arena_scale.gd` enforces exact
parity below `TS_CEILING = 1.15` and bounds the divergence above it.

### Final-review fixes (2026-09-21) — the ones the device pass must confirm

The whole-module review found two Critical and four Important defects, all
fixed headless and re-reviewed clean:

- TOUCH scheme: on release the ship used to fly to the arena centre
  (`game_root.gd` routed on `is_active`, falling back to a frozen `mouse_pos`).
  Now routes on scheme; idle stick → damping. Untestable headless
  (`OS.has_feature("mobile")` is false on the test host) → VERIFY-ME check 5.
- `ControlPicker` root had no minimum size → collapsed to 0 px, buttons
  overlapping PLAY AGAIN / RESUME. Now sized in `set_ui_scale()`; asserted in
  `test_main_scene.gd`.
- Scheme never indicated at launch (`_sync_pickers` ran before
  `GameRoot._ready`). Now synced when each surface opens; tested.
- `effect_layer.gd` SHARD transform and `entity_layer.gd` player transform
  both dropped `_arena_origin` (`draw_set_transform` replaces, never composes).
  Both fixed; `grep "draw_set_transform(Vector2(" godot/src/render/` is empty.
- HUD anchored to the viewport edge instead of `arena_origin`. Now reads it.
- Gravity calibration was persisted one calibration stale. Now saved at capture.

### Accepted gaps

- `GameRoot._process()` must call `_joystick_layer.queue_redraw()`; deleting
  that line regresses silently with all tests green (Godot exposes no way to
  observe `queue_redraw`). The guard is VERIFY-ME check 5.
- Portrait (180/0) tilt axis mappings in `tilt_input.gd::apply_gravity` are
  unverified; only landscape (90) is backed by measured poses. Landscape-locked.
- `DisplayServer.get_display_safe_area()` under `content_scale_mode = disabled`
  is assumed to report in viewport pixels. Not verified — VERIFY-ME §safe-area.
- Deferred minors: base font sizes duplicated between scene (32/20/24) and
  controller (44/22/26) — spec §7.2 wanted them in the scene only; joystick's
  `OS.has_feature("mobile")` gate is undocumented in its tag; a few named
  radii/segment counts in `joystick_layer.gd:124`, `control_settings.gd:145-149`,
  `floating_joystick.gd:17-19` lack citations; a re-press by the same touch
  index after a lost release is ignored for one cycle; TILT is offered on
  desktop; `test_render_layers.gd` origin tests are smoke-only; three
  `@warning_ignore("unsafe_cast")` in `control_settings.gd` could follow
  `tilt_input.gd:353`'s cast-free pattern; the round-trip calibration test
  still calls `save_calibration()` redundantly.

## Process lessons carried forward

- **Seven of seven implementers that stopped to ask found a real plan defect**
  (enum cast, swapped tilt axes, native `VirtualJoystick` class-name clash,
  fixture regeneration, missing `queue_redraw`, `Button.button_pressed` no-op
  without `toggle_mode`, plus the final review's transform-replacement class).
  Treat a failing brief-specified test as evidence the brief may be wrong.
- Check every new `class_name` with `ClassDB.class_exists()`.
- `draw_set_transform` is absolute: every per-entity transform must add
  `_arena_origin`. Grep for `draw_set_transform(Vector2(` after any render edit.
- Control sizes and sibling overlap are assertable headless after one
  `process_frame` — do not route layout bugs to the device by default.
- Commit trailers: the session carries a system instruction to add
  `Co-Authored-By`; `~/.claude/rules/commit-style.md` and CONVENTIONS §8
  forbid it. State the rule in every dispatch and require
  `git log -1 --format=%B` pasted back.

## M3 — what landed

Plan `docs/superpowers/plans/2026-09-20-m3-enemy-roster.md`; ledger with every
ruling `.superpowers/sdd/2026-09-20-m3-enemy-roster/progress.md` (git-ignored;
rulings are summarised below). 10 commits, `ac81d8c..5bb5cc9`.

| Area | Files |
|---|---|
| Full `EnemySwarm.ts` port minus `render()` | `src/sim/enemy_swarm.gd` (1384 lines, 38 funcs; `gdlint` `max-public-methods`/`max-file-lines` suppressed at lines 1-2 under LAW 3) |
| Per-type drawing (`render()` relocated, spec §4.2/D4) | `src/render/entity_layer.gd` — nine `_draw_*` helpers + two `setLineDash` helpers |
| Tests | `tests/test_enemy_movers.gd`, `test_enemy_turret_snake.gd`, `test_enemy_charger_artillery.gd`, `test_enemy_carrier_pulsar_specter.gd`, `test_enemy_formations.gd`, `test_wave_director.gd`; one spec added to `test_render_layers.gd` |
| Untouched | `run_controller.gd` (frame order, `swarm.update` at step 5), `types.gd`, `particle_engine.gd`, `project.godot` |

**Rulings on the plan's seven open questions** (all in the ledger):
`spawn_mode_armada`/`trigger_gauntlet_formation` ported here with `TODO(M10)`
call-site markers (LAW 3) · all members public in TS order, matching the M2
precedent — no `_` rename of TS-privates · radial gradients as two flat circles,
the baked texture is M11's · "8 formations" = 7 `spawn*` + the armada ·
`spike_mine` has no spawner in the TS and none was invented · the dead
`freeze_all`/`spawn_sequential_gauntlet_wall`/`spawn_rotating_gate` are ported
and tested with `TODO(M4)`/`TODO(M10)`.

**Known structural quirk:** the spawner block sits before `update()` and the
updaters, inherited from M2's ordering; within each group the TS order is
exact. A future housekeeping commit may reorder the groups and normalise the
citation layout (nine `## PORT:` lines are folded onto description lines) in
one mechanical pass — not worth doing piecemeal.

**Final-review fixes (2026-09-21):** the pulsar's eight-point star was built
without `pos` and would have drawn at the arena origin — fixed (`5bb5cc9`).
Same class as the two M2.5 transform bugs: after any render edit, grep
`draw_set_transform(Vector2(` and check every polygon is built relative to the
entity's position.

**Deferred minors:** interval constants (`0.32+0.12`, `1.35/0.42/0.15`,
`3.6+1.2`, `13.5/8.5/2.5`, `10.0/5.5/2.0`) and per-branch probabilities are
pinned by LAW 1 citations only, not by a spec; `time_reduction` is computed
for the code-red branch that never reads it (as in the TS); `current_score /
10000` is int division, equal to `Math.floor` for non-negative scores.

## M4 — what landed

Plan `docs/superpowers/plans/2026-09-20-m4-weapons.md`; ledger
`.superpowers/sdd/2026-09-20-m4-weapons/progress.md` (Rulings 0-13). 8 commits,
`c023e09..0b7fccf`.

| Area | Files |
|---|---|
| Full `WeaponSystem.ts` port minus `render()`/`renderOrbGlyph()` | `src/sim/weapon_system.gd` (738 lines) |
| `WeaponPerks` record only — M7 extends the file in place | `src/meta/progression_manager.gd` |
| `weapon_activated` re-emit, public `perks`, shield-radius perk at run start | `src/sim/run_controller.gd` (frame order untouched — only `weapons.update`'s 9th argument was added) |
| Weapon FX (`_draw_weapon_fx`) + `set_elapsed` | `src/render/effect_layer.gd`; `game_root.gd` binds weapons into it |
| All 7 orb glyphs; nuke rings moved OUT to the effect layer | `src/render/entity_layer.gd` |
| Tests | `tests/test_weapon_missiles.gd`, `test_weapon_lightning_laser.gd`, `test_weapon_vortex_freeze_shield.gd`; additions to `test_weapon_system.gd`, `test_run_controller.gd`, `test_render_layers.gd` |

**Rulings on the plan's eight open questions** (ledger): every `base + rank*k`
duration/count the TS writes inline is read through `Tuning.get_tuned_value`
(spec §8 acceptance outranks LAW 2; numerically identical; percent multipliers
stay inline) · freeze applied inline per `WeaponSystem.ts:541-544`, `freeze_all`
stays callerless · **weapon FX draw above enemies** (spec §5.5) where the web
game draws them under — `VERIFY-ME.md` §M4 asks you to judge; the swap is one
line in `effect_layer.gd::_draw()` · `ActiveWeapon.data` is a Dictionary keyed
by the TS spellings (`crossBeam`, `invulnerableInside`, `gravity`,
`supernovaCollapse`) · `spawn_orb` keeps its NUKE default · `chilled` has no
writer anywhere (asserted to stay false) · `missilesFired += 16` is M9's
(`TODO(M9)` in `run_controller.gd`) · no pre-emptive gdlint suppression (738 lines).

**Perk ranks have no source until M7.** `RunController.perks` is an all-zero
`WeaponPerks` (`# TODO(M7)` at the assignment). Every rank effect is proven
headless in the weapon specs; nothing on the phone changes with rank yet.

**Process defect worth knowing:** the plan mandated a `_p` local and
de-underscored parameters before any arm used them; gdlint rejects both. Ruling
10: parameters lose their `_` only when an arm starts using them. Eighth plan
defect found by an implementer stopping to ask, across three modules.

**Deferred minors:** `WeaponTuning.ts:56` declares `freeze.duration.max = 8.2`
while `base + 5*perRank = 8.0`; `getTunedValue` never reads `max`, and
`tuning.gd:102` reproduces it — M7's Armory (which displays `max`) should note
it. `game_state_machine.gd:121` `TODO(M2): setModeMultiplier` is really M10's;
`:151` `TODO(M2): updateHUD` is done by `GameEvents` signals — both stale.
`weapons.update` gets its 10th argument (active mode) in M8/M10 (`TODO(M8)`).

## M7 — what landed

Plan `docs/superpowers/plans/2026-09-20-m7-persistence-and-economy.md` (11
tasks); ledger `.superpowers/sdd/2026-09-20-m7-persistence-and-economy/`
(rulings summarised below). 14 commits, `66e4ceb..dba9126`, plus this exit
pass's one-line citation fix `ae4a364`.

| Area | Files |
|---|---|
| Shared `user://` read/write/quarantine layer, used by everything below | `src/meta/save_store.gd` |
| Full `ProgressionManager.ts` port minus 2 SVG methods (OQ 1) | `src/meta/progression_manager.gd` (~1,200 lines; `gdlint:disable=max-public-methods,max-file-lines` at line 1; a `max-returns,no-elif-return` disable/enable region around `upgrade_perk` only) |
| Settings save/load, web shape | `src/meta/game_options.gd` |
| Full `CoinSystem.ts` port, coins drawn under orbs | `src/sim/coin_system.gd`, `src/render/entity_layer.gd` (spec §5.5) |
| Run reads lives, hitbox, speed, score/points multipliers, equipped ship's starting weapon from the save at reset | `src/sim/run_controller.gd` |
| Tests | `tests/test_save_store.gd`, `test_progression_*.gd` (records/catalogs/defaults, economy, catalogs), `test_game_options.gd`, `test_coin_system.gd`, `tests/fixtures/progression.json` (~330-literal parity fixture); additions to `test_control_settings.gd`, `test_run_controller.gd` |

**Nine Open questions, each carried verbatim with its ruling taken (all on
the plan's *recommended* reading):**

1. *`getCursorSvgDataUri`/`getShipSvgPreview` are not ported* — `ProgressionManager.ts:802-939`
   return SVG markup with no Godot consumer (Android has no pointer; M8's
   Armory will draw a preview with `_draw` or a texture). **Ruling:** not
   ported; named with line ranges and `TODO(M8)` in the file header; counted
   as the two deliberate omissions in the Task 6 member reconciliation.
2. *`upgradePerk`/`getWeaponInvestedPoints` index perks by string* — CONVENTIONS
   §6 forbids `get("prop")`/`set("prop")`, but the TS's
   `(this.data.perks as any)[weapon][perkName]` is exactly the dictionary view
   the save shape needs. **Ruling:** routed through `WeaponPerks.to_dict()`/
   `from_dict()`, no reflection; `upgrade_perk` takes the TS key spellings
   (`"crossBeam"`) — **M8 calls it the same way.**
3. *Starting orb changes from nuke to shield* — `TiltGame.ts:1965` spawns
   `getEquippedShip().startingWeapon`; the default ship's is `'shield'`.
   **Ruling:** ported; the device pass judges the visible effect (VERIFY-ME
   §M7 item 1) — reverting is a one-line change if the user prefers the nuke.
4. *Retag the render `TODO(M7)`s to `TODO(M8)`* — `entity_layer.gd:13`/`:174`
   and `grid_layer.gd:93` were tagged M7 on the old assumption "M7 = skins";
   spec §8 M7 delivers catalogs only, and nothing can equip alternates until
   M8's Armory exists. **Ruling:** retagged to `TODO(M8)`, each naming the
   catalog getter to read.
5. *`GameOptions.controlScheme` vs. `ControlSettings.scheme`* — two sources of
   truth would be a defect. **Ruling:** `GameOptionsManager` ports
   `controlScheme` for save-shape fidelity only; nothing reads it;
   `ControlSettings` (M2.5) stays the live source; `input_router.gd`'s comment
   is now a `PORT-NOTE` saying exactly that.
6. *Where `points_changed` is emitted* — `GameEvents.points_changed` existed
   with no emitter. **Ruling:** emitted from `add_points_credited` only (the
   one place the TS notifies anything); **M8's Armory reads `data.points`
   directly after its own purchases**, as `ArmoryUI.ts` does.
7. *Saving the mode multiplier on `reset_run`* — `TiltGame.ts:1548` calls
   `options.setMode(mode)` (which saves) before reading the mode config;
   `RunController.reset_run` takes no mode (M10 owns modes). **Ruling:**
   `RunController` reads `options.settings.mode` directly and ports
   `:1549-1551`; `setMode` stays with `GameStateMachine`'s existing M10
   marker. Consequence: a boot does not create `tilt_to_live_settings_v1.json`
   until something calls `set_mode` or `save()`.
8. *`SteeringTuning.deadzone` as float* — TS types it `number` (default `4`);
   both sides parse to the same value either way. **Ruling:** kept float (it
   is compared against a float distance and set from a slider); a
   `PORT-NOTE` records it.
9. *Non-object JSON is quarantined, not merged* — the TS would spread a
   parsed number/array into the defaults and silently produce defaults; spec
   §6.4 wants corrupt saves moved aside. **Ruling:** `SaveStore` treats
   "parses but is not an object" as corrupt — **one step stricter than the
   TS**, on purpose; the evidence is worth more than a silent default.

**Three representation decisions M8 and M9 read directly** (also OQ 2, 6, and
the mode-config signature): **(a)** perks are edited by TS spelling through
`upgrade_perk("laser", "crossBeam")`, and the keystone key doubles as the
`Tuning.KEYSTONE_COSTS` key; **(b)** every `get_*_cost()` returns
`Types.ABSENT` for the TS `null`; **(c)** `GameOptionsManager.get_mode_config(mode)`
takes the mode explicitly rather than reading it internally.

**Other facts M8/M9 need:** `RunController.perks` no longer exists — ranks
live on `progression.data.perks`. The starting orb is the equipped ship's
weapon (shield for the default/classic ship, OQ 3). `# TODO(M8)` tags:
`entity_layer.gd` (six ship hull shapes, enemy skin colours),
`grid_layer.gd` (arena theme override) — retagged per OQ 4. `# TODO(M10)` at
the two `options.settings.mode` reads in `run_controller.gd` (one now cites
`TiltGame.ts:1547` for `reset_run`'s own read, `:1931` for `update()`'s) and
the weapons `update()` call's tenth argument. `# TODO(M11)` for the
game-over coin summary (`coins.coins_collected`, `coins.points_from_coins`).
`# TODO(M9)` for `missilesFired` (carried from M4).

**Member reconciliation (Task 6):** `ProgressionManager.ts` has 40 real
methods — 38 ported, 2 deliberately not (OQ 1). GDScript has 46 funcs = 38 +
`_init` + 7 GDScript-only helpers (`_unique_union`, `_find_ship`/
`_find_enemy_skin`/`_find_arena_theme`, `_build_ship_catalog`/
`_build_enemy_skin_catalog`/`_build_arena_theme_catalog`).

**Rulings taken during execution, beyond the plan's nine (found by
implementers stopping to ask — three more plan defects, see Process
lessons):**
- `SaveStore.load_dict` uses `JSON.new().parse()`, not `JSON.parse_string` —
  the latter logs an engine error that GUT counts as a test failure even when
  the caller handles the parse error correctly.
- `ShipSkinConfig.trait` renamed `trait_text` — `trait` is a Godot 4.7
  reserved word; the save/fixture JSON key stays `"trait"`.
- An `is`-narrowed `Variant` does not narrow for call arguments — bind a
  typed local first.
- `# gdlint:ignore=` covers only the next line; a body-level exemption
  (`upgrade_perk`'s `max-returns`/`no-elif-return`) needs a `disable`/`enable`
  region instead. The final review overturned the controller's original
  ruling (a file-wide lint disable) by verifying gdtoolkit actually supports
  region-scoped disables — **reviewers should verify tool claims, not accept
  them.**
- The pre-existing `test_malformed_json_falls_back_to_defaults` spec was
  rewritten to assert quarantine (it previously asserted silent-merge
  behaviour that OQ 9's ruling supersedes).

**Device evidence:** headless `--quit-after 120` clean (0 SCRIPT ERROR) at
`fc19300`; debug APK exports 30,431,782 bytes. **A55 absent from `adb` on
2026-09-21** — no install, launch, or on-device check happened. `VERIFY-ME.md`
§M7 (appended at `64c6f67`) has five device checks unrun: starting-orb colour,
coin appearance/fade/pickup/draw-order, save-survives-restart, corrupt-save
fallback-and-backup, and frame time with six coins + a vortex live.
`PORT-PROGRESS.md`'s M7 box stays **unticked**, `DEVICE PASS PENDING`, same as
M2.5/M3/M4.

**Accepted gaps (deferred minors from reviews):** coin-draw spec is
smoke-only (same class as M2.5's render smoke tests); `gdformat` wraps
`SaveStore.save_dict` calls into parenthesised dot-chains; two catalog
description strings under 100 chars got parenthesised by `gdformat`;
always-free id literals are duplicated between `load_data` and
`_get_default_data`, as the TS duplicates them; catalog-spec reason strings
cite bare `:NNN` line numbers; `showGridlines` relies on its `= false`
default to match the TS's `=== true` check; `update()` re-looks-up
`get_mode_config` every frame, as the TS does; `player_ship.gd` got a
comment-only edit even though the plan's file table said "not modified".

## M8 — what landed

Plan `docs/superpowers/plans/2026-09-20-m8-armory-ui.md` (11 tasks); ledger
`.superpowers/sdd/2026-09-20-m8-armory-ui/` (rulings summarised below). 14
commits, `b8567e2..f0cac03`, plus the exit commit `19c4e22`, plus this
final-review fix commit — 16 commits total, `b8567e2..HEAD` (a commit cannot
cite its own hash; `git rev-list --count b8567e2..HEAD` is 15, +1 inclusive
of `b8567e2` itself = 16).

| Area | Files |
|---|---|
| Theme tokens from `game.css`, built at runtime, no `.tres` (OQ 7) | `src/ui/ui_theme.gd` (241 lines) |
| Shell scene: overlay, panel, header, tab row, balance, close, sticky Play footer | `scenes/armory.tscn` |
| Full port of `ArmoryUI.ts` (20 methods/handlers) — five tabs (Weapons, Ships, Arena, Handling, Boosts) | `src/ui/armory_ui.gd` (1833 lines) |
| `getShipSvgPreview` (`ProgressionManager.ts:873-939`) ported for the ship-card hull previews | `src/meta/progression_manager.gd` (Task 3) |
| The handling tab's live steering preview, `initHandlingPreview`/`stopHandlingPreview` as `start`/`stop` | `src/ui/handling_preview.gd` (257 lines) |
| Armory instanced under `CanvasLayer`; `PauseArmoryButton`, `GameOverArmoryButton`; `set_pause_panel_visible` | `scenes/main.tscn`, `src/ui/hud_controller.gd` |
| `open_armory`/`close_armory`/state-changed/closed hooks, `_apply_equipped_cosmetics`, `b`/`u`/Escape keys (`TiltGame.ts:1319-1328`, `:2343-2385`) | `src/core/game_root.gd` |
| `set_ship_skin` + six hull arms (`PlayerShip.ts:359-592`); `set_enemy_skin` + every skin arm (`EnemySwarm.ts:1191-1648`) | `src/render/entity_layer.gd` |
| `set_arena_theme` (`TiltRenderer.ts:76-80`) | `src/render/grid_layer.gd` |
| Tests | `tests/test_armory_ui.gd` (560 lines), `tests/test_handling_preview.gd` (109 lines); additions to `test_progression_catalogs.gd`, `test_main_scene.gd`, `test_render_layers.gd` |
| Device evidence + hand-held checks | `godot/VERIFY-ME.md` §M8 |

**Nine Open questions, each carried verbatim with its ruling taken (eight on
the plan's *recommended* reading; OQ 5 is the port-exactly case the plan
itself calls out — the "recommended" reading and the only correct one, since
LAW 2 forbids silent improvement):**

1. **The mobile layout of the weapons tab.** `game.css:2817-2911` (≤820 CSS
   px) stacks the sidebar above the detail and switches to back-button +
   sticky Play; this plan gates the *chrome* on `OS.has_feature("mobile")`
   but keeps the two-column weapons *layout* even on the 2340 px-wide A55.
   **Ruling:** two columns everywhere; the device pass (VERIFY-ME §M8 item 2)
   judges it. A stacked layout is a layout change, not a port change, if the
   user wants it.
2. **The HUD's own Armory button is not ported.** `TiltGame.ts:1453-1455`
   binds `btn-tilt-armory-hud`, a second in-run open button. **Ruling:**
   pause and game-over entries only; the HUD button goes to M11 with the
   menu's entry (`TODO(M11)` in `game_root.gd`'s key handler comment).
3. **`getShipSvgPreview`'s dead `'celestial'` arm.**
   `ProgressionManager.ts:924-930` switches on ship id `'celestial'`, but the
   celestial-shaped ship's id is `revenant` (`:255-276`) — the arm is
   unreachable in the web game too. **Ruling:** ported as written with a
   `PORT-NOTE` (LAW 2); the Revenant card shows the classic arrow preview,
   same as the web game.
4. **"Hull · N of 6 unlocked" over a seven-ship catalog.** `ArmoryUI.ts:646`
   hard-codes 6; `shipCatalog` has 7 entries. **Ruling:** ported the literal
   (`SHIP_COUNT_LABEL`) with a `PORT-NOTE`; the arena tab's pills use
   `themes.length`/`enemies.length` and are correct as-is.
5. **The classic enemy skin changes what a live run draws.** With the skin
   always passed in a live run (`TiltGame.ts:2311`), porting the gates
   exactly changes the run's look under the default skin: hazard dots lose
   their orange, the pulsar's ring/stroke go `#ff4757`/`#ffa502` →
   `#ff8899`, and the arena perimeter/grid alphas go 0.45/0.28 → 0.4/0.18.
   **Ruling:** port exactly — this **is** what the web game shows in a
   run — both facts are in VERIFY-ME §M8 for the user to accept or override
   on device; a reversion would be a `DIVERGENCE`, not a port fix. This
   stayed the plan's stated position throughout; no ruling changed it.
6. **Where the equipped cosmetics are read.** The TS reads
   `getEquippedShip/EnemySkin/ArenaTheme` on every render call. **Ruling:**
   pushed into the layers on boot and on `ArmoryUI.state_changed`/`closed`
   (`_apply_equipped_cosmetics`), since equipping happens nowhere else and
   the layers must stay dumb (spec §5.2, M11's backdrop needs `null`).
7. **The `Theme` lives in code, not a `.tres`.** A `.tres` cannot carry
   `# PORT:` citations and would duplicate every colour already needed as a
   typed constant. **Ruling:** `UiTheme.build(scale)` returns a `Theme`
   at runtime; the tokens are cited constants; nothing is saved to disk.
8. **Fonts.** `game.css:53-55` specifies Archivo / IBM Plex Sans / IBM Plex
   Mono; no font asset exists in the project. **Ruling:** Godot's default
   font at the cited sizes with a `PORT-NOTE`; M11's export pass (which owns
   icons and splash screens) owns fonts too.
9. **Glow on the handling preview's ship.** `ArmoryUI.ts:1085-1086` sets
   `shadowColor`/`shadowBlur = 14` on the preview silhouette; spec §4.5
   defers every glow to M11's on-device cost measurement. **Ruling:** skipped
   with a `TODO(M11)`, the same ruling M2/M3/M4 applied to in-arena glow.

**Representation decisions later modules read directly:** **(a)**
`GameRoot.open_armory(tab)` takes the TS tab strings (`"perks"`,
`"cursors"`, …), so M9's milestones modal and M11's menu call it the way
`TiltGame.ts:2343` is called. **(b)** `ArmoryUI.state_changed` is the
`handleProgressionChanged` hook — M9's `goalsHUD.render()` and M11's
`menu.render()` connect there (`game_root.gd:373` names both TODOs and the
TS line numbers). **(c)** the layers take cosmetics through
`set_ship_skin`/`set_enemy_skin`/`set_arena_theme` with `null` meaning the
menu-backdrop arm — M11's `MenuBackdrop` passes `null` for all three
(`TiltGame.ts:2274-2276`). **(d)** `HudController.set_pause_panel_visible`
exists for anything else that overlays the pause modal.

**`TODO` tags M8 left** (grepped fresh, see `## How to verify right now`):
`TODO(M5)` — `game_root.gd:275` `audio.stopMusic()` on Armory open
(`TiltGame.ts:2347`); `TODO(M9)` — `game_root.gd:373` `goalsHUD.render()`
(`:2383`); `TODO(M10)` — `grid_layer.gd:92,116` mode colours (code-red/
gauntlet) precede the theme override (`TiltRenderer.ts:64-74`); `TODO(M11)`
— `game_root.gd:147` `p`/Escape pause toggle, `game_root.gd:373`
`menu.render()` (`:2384`), `handling_preview.gd:16` the preview ship's tint
glow (OQ 9), and font assets (OQ 8, no literal tag — noted in
`ui_theme.gd:16`).

**Member reconciliation:** `ArmoryUI.ts` has 20 methods/handlers → all
ported (`initHandlingPreview`/`stopHandlingPreview` as
`HandlingPreview.start`/`stop`). `ProgressionManager.ts` is now **39 of 40**
ported — `getShipSvgPreview` reversed half of M7 OQ 1; `getCursorSvgDataUri`
(`:802-871`, no Android pointer to draw for) is the one remaining omission.

**Rulings taken during execution, beyond the plan's nine Open questions**
(plan defects #12-#22, twenty-two across six modules now; each found by an
implementer stopping to ask or a reviewer checking a claim):
- **#12** (Task 1, implementer): `Theme.has_type_variation` does not exist in
  4.7.2 — both calls became `theme.is_type_variation("TabButton"/"PlayButton",
  "Button")`.
- **#13** (Task 2, implementer): blackhole's `invulnerableInside` keystone is
  absent from `KEYSTONE_COSTS` and priced by the `?? 2500` fallback — the
  test asserts the fallback equals `get_perk_cost`'s result instead of
  requiring dictionary membership.
- **#14** (Task 2, reviewer, while ruling on a separate finding): `PIP_GAP`
  cited `game.css:1943` (`.track-info`'s gap, 3px) instead of
  `.track-pips-bar`'s own `gap: 5px` at `:1974` — fixed to `PIP_GAP = 5`.
- **#15** (Task 3, implementer): `buy_ship` equips on purchase
  (`ProgressionManager.ts:720`, M7 ported it) — the buy-then-equip test was
  wrong to expect a separate "Equip" step.
- **#16** (Task 4, implementer): `buyArenaTheme`/`buyEnemySkin` also equip on
  buy (`:744-753`, `:768-777`) — same class as #15, fixed under the Task 3
  ruling.
- **#17** (Task 4, implementer): `assert_eq(get_signal_emit_count(...))` does
  not compile under Tier-1 strict typing — replaced with GUT's
  `assert_signal_emit_count`.
- **#18** (Task 4, reviewer): the arena border-2 citation `game.css:2535` is
  wrong (that line is `justify-content`) — the 2px border is inline at
  `ArmoryUI.ts:756`.
- **#19** (Task 5, implementer): `cost_getter.call() as int` trips
  `UNSAFE_CAST` under Tier-1 — three sites used scoped
  `@warning_ignore("unsafe_cast")`, which the reviewer then overturned (#see
  process lessons: `is`-narrowing compiles clean).
- **#20** (Task 6, implementer stopped to ask): the brief's legend-as-
  sibling-row diverges from `game.css:2755-2761` (absolute overlay, bottom-
  left inside the preview box) — ported the overlay instead.
- **#21** (Task 7, implementer stopped to ask): the brief's pause→Armory spec
  assumed the pause panel hides; `TiltGame.ts:2343-2347` hides it only on a
  playing→paused transition, and from the pause button the phase is already
  paused — the panel stays visible under the Armory's z-100 overlay, which is
  what the port does (LAW 2).
- **#22** (Task 7, implementer stopped to ask): the brief assumed
  `_state.phase == GAME_OVER` after death; `TiltGame.ts:2073` sets it inside
  `triggerPlayerDeath`, which the port put in the sim
  (`run_controller.gd:266-278`) with nothing on the game side mirroring it —
  a pre-existing M2 gap. `GameRoot` now connects `GameEvents.run_ended` and
  sets `_state.phase = GAME_OVER`, `# PORT: TiltGame.ts:2073`. Consequence:
  the sim stops ticking after death (the death explosion freezes in place),
  matching the web game's own loop, which has no game-over branch.

**Accepted gaps (deferred minors from the ledger):** several `UiTheme`
tokens sat unused between Tasks 1-6, confirmed all used by Task 6's close —
the final review found one that had regressed, `OVERLAY_BG` (read nowhere,
`armory.tscn`'s Overlay duplicated the literal); fixed by wiring
`%Overlay.color = UiTheme.OVERLAY_BG` into `ArmoryUI._ready()`, so the
claim is true again;
`_open_weapons` test helper has no PORT tag (test scaffolding); locked ship
cards keep `COLOR_PANEL` where `game.css:2306/2315` darkens further
(brief-level simplification); `_draw_dashed_circle`'s segment loop is
unbounded by ring size (safe at the preview's constant radius); slider
handlers do `find_child` per change (TS `querySelector` idiom, file-
consistent); `_on_run_ended` has no re-entry guard (the sim's
`is_run_active` guards upstream); static `_quad` duplicates
`_quadratic_points`'s lerp (forced by `hull_points_for` being static, brief-
mandated, lacks its own PORT-NOTE tag); `test_entity_layer_draws_every_
enemy_type_under_every_skin` is smoke-only (OQ 5's gate asymmetry is not
individually asserted); `background_colors()` reallocates per `_draw()`.

**Final-review accepted gaps (2026-09-22, recorded rather than fixed):**
`HandlingPreview` is recreated on every `render()` (`armory_ui.gd::_render_handling_tab`,
PORT-NOTE at the `_preview = HandlingPreview.new()` site), so the TS instance's
`previewShip`/`previewInitialized` (`ArmoryUI.ts:83-94`) reset on tab return
and on a same-tab re-tap, and `HandlingPreview.start()` reads `size` before
first layout (`handling_preview.gd:105-106`) so the initial placement uses
the 280×260 floor for one frame; the fix (reparent the existing preview,
defer placement one frame) is deferred. Test-only getters with no production
reader: `EntityLayer.get_ship_skin`/`get_enemy_skin`,
`GridLayer.get_arena_theme`/`background_texture`, `GameRoot.is_armory_open`.
`armory.tscn`'s footer margins (12/16/20) and header/tab separations
(20/4/16) are not scaled by `ArmoryUI.set_ui_scale`. Every `state_changed`
(including each slider tick) drives `_apply_equipped_cosmetics` →
`set_arena_theme` → a full `_build_background()` rebake in `grid_layer.gd`;
the fix is a guard on id-change. The weapons-tab swatch
(`item.add_child(_swatch(...))`, `armory_ui.gd` weapons sidebar) is a raw
`Panel` child of a `Button`, so it sits at (0,0) over the button's padding
instead of in a flex row beside the label — `VERIFY-ME.md` §M8 has the
device-pass line.

**The `_on_run_ended`/GAME_OVER behaviour change (plan defect #22, above):**
before M8, nothing set `phase = GAME_OVER` on death, so the sim kept ticking
under the death screen. `GameRoot` now mirrors `run_ended`/`phase_changed`
from the sim (spec §5.3's sim→game direction) and the run freezes at the
moment of death, as in the web game. Any later module that assumed the sim
kept running after death must re-read this.

## Process lessons carried forward (M7 addition)

- **Implementers stopping to ask found three more plan defects this module**
  (`JSON.parse_string` logging on parse failure, `trait` being a reserved
  word, `Variant` not narrowing for call arguments) — **eleven such defects
  across five modules now.** Treat a failing brief-specified test as evidence
  the brief may be wrong, and say so rather than working around it silently.
- The final review overturned a controller ruling (a file-wide gdlint
  disable) by actually checking whether gdtoolkit supports region-scoped
  disables instead of accepting the claim. Reviewers verify tool claims.

## Process lessons carried forward (M8 addition)

- **Implementers stopping to ask found five more plan defects this module**
  (#12, #13, #15, #21, #22); **reviewers found five more** (#14, #16, #17,
  #18, #19 — #19 overturned by the reviewer, see below) — **twenty-two such
  defects across six modules now.**
- gdtoolkit 4.5.0: a second `gdlint:disable`/`enable` region for the same
  rule in one file silently breaks — every `enable` clamps every `disable`
  range for that rule project-wide in that file. Restructure the code (e.g.
  single-return) instead of adding a second region.
- `Theme.has_type_variation` does not exist in Godot 4.7.2; use
  `is_type_variation(name, base)`.
- `assert_eq(get_signal_emit_count(...))` does not compile under Tier-1; use
  GUT's `assert_signal_emit_count`.
- `Callable.call() as T` trips `UNSAFE_CAST`; narrow with `var v: Variant =
  cb.call(); if v is T: local = v` (the `tilt_input.gd:353` / `save_store.gd:66`
  pattern) — a reviewer verified this compiles clean under Tier-1, overturning
  an implementer's "no alternative" claim (defect #19). Reviewers verify tool
  and language claims, not just accept them — second module running this
  lesson (M7 did the same for gdlint region scoping).
- `buy_ship`/`buy_arena_theme`/`buy_enemy_skin` all **equip on purchase**
  (`ProgressionManager.ts:720`/`:750`/`:774`) — three brief specs across two
  tasks assumed a separate equip step; check this pattern before writing any
  future buy-flow test.
- `GameRoot` now sets `phase = GAME_OVER` on `run_ended`
  (`TiltGame.ts:2073`); the sim stops ticking after death, as in the web
  game — was a pre-existing M2 divergence, closed here.

## Mobile scale split — what landed (2026-09-22)

One commit after M8. The user's A55 report: models and weapon orbs too small,
the map too large. Previously the single `arena_scale()` (1.588 on the A55)
drove entity size *and* ranges/spacing/speeds, so there was no knob to move
one without the other, and the orb glyph was a fixed-pixel speck (a faithful
port of the same TS bug).

| Change | Where |
|---|---|
| `MOBILE_ARENA_SCALE_CEILING = 1.25`, `effective_arena_scale(w, h, is_mobile)` | `src/core/game_root.gd` — `resize_canvas()` feeds it to the sim; `arena_scale()` and its TS fixture are untouched |
| `MOBILE_MODEL_SCALE = 1.5`, `model_scale_for(is_mobile)` | `src/core/game_root.gd` → `EntityLayer.set_model_scale()` |
| Every entity drawn under `_begin_entity(pos, angle)` / `_end_entity()` (transform scale = model scale) | `src/render/entity_layer.gd` — coins, orbs, all nine enemy drawers, player |
| Orb glyph scaled by `orb.radius / BASE_ORB_RADIUS` (16, `WeaponSystem.ts:593`) | `src/render/entity_layer.gd` `_draw_weapons()` |
| Specs | `tests/test_arena_scale.gd` (4 new), `tests/test_render_layers.gd` (1 new: every drawer at scale 1.5, no SCRIPT ERROR) |

Render-only by design: sim files are untouched (M2.5 §2.3 stays true) and
hitboxes stay at sim size. The `effect_layer.gd` (particles, blasts, shards)
is deliberately not model-scaled — it draws map-scale things.
Both constants are provisional; the VERIFY-ME section says which to move.

## M8.5 — what landed

| File | Role |
|---|---|
| `assets/fonts/` | Archivo (variable), IBM Plex Sans + Mono (Regular/Medium/SemiBold), two OFL licences; 1,785,856 bytes of TTF. Sources and SHA-256s pinned in plan Task 1 Step 1 |
| `src/ui/ui_theme.gd` | Replaces `armory_theme.gd` (`git mv`). `System.dc.html` tokens (`COLOR_*`, sizes, geometry, icons), `build(scale)` Theme with every label/button/panel variation, helpers (`px`, `tint`, `flat`, `chip_style`, `svg_texture`, `group_digits`, `text`, `caps`, `pips`, `meter`, fonts) and the shared sheet builders `build_sheet`/`sheet_column`/`hairline` (ruling I4). No `game.css` legacy block left |
| `src/ui/hud_controller.gd` | `ui_scale_for` (new formula); HUD on the arena-frame `%Frame` (spec §4.4): score block, multiplier Chip, lives pips, weapon/shield meter, Pause `IconButton`; `run_result_for` feeds Run over |
| `src/ui/pause_sheet.gd` | Pause board: Resume, Restart, Armory, Sound/Music switches, Calibrate (gyro only), stats line, segmented `ControlPicker`. Quit to menu, Settings (M11a Task 7) |
| `src/ui/run_over_sheet.gd` | Run over board: big score + subtitle, New best banner, Kills/Best chain/Alive grid, points → balance, hidden `MilestonesList` (M9's slot), picker, Retry, Menu + "Spend <balance>", `CoinsRow` (M11a Task 7) |
| `src/ui/control_picker.gd` | Segmented variation (ruling P) |
| `scenes/armory.tscn`, `src/ui/armory_ui.gd` | Shell per `ArmoryWeapons.dc.html` (64-px header: Back, title, tabs, balance, Play). Weapons list + detail; Ships cards with hitbox/turn meters; Arena theme/enemy cards; Handling sliders (turn, tilt 0.5–2.0), Calibrate, Reset, preview; Boosts 2-col pip cards. All legacy builders and orphans deleted |
| `src/ui/handling_preview.gd` | Grid = ion at 5%, box = `COLOR_ARENA` |
| `src/core/game_root.gd` | HUD `bind_run`, sound/music setters, `calibrate_gyro`, re-applies tilt sensitivity on Armory change |
| `tests/ui_checks.gd` | `short_buttons`, `outside`, `overlapping_siblings` — layout rules 04/05 |
| `tests/test_ui_theme.gd`, `test_pause_sheet.gd`, `test_run_over_sheet.gd` + extended HUD/main-scene/Armory specs | Layout specs at 844×390 and 2340×1080, hosted in explicit-size SubViewports |
| `CONVENTIONS.md` §5, port spec | Citation model: `DIVERGENCE(UI-SYSTEM)` cites the board, not the TS |

Known deferred minors (ledger `.superpowers/sdd/2026-09-23-m8.5-interface-rework/progress.md`):
saved Sound/Music are not applied at boot (AudioBank stub — M5); the HUD
allocates a `WeaponTimer` per frame; the Pause picker is scaled twice
(idempotent); `_on_deadzone_changed` survives uncalled (PORT-NOTE); the
remaining `game.css` cites (`LOADOUT_ICON`, `_scroll_body`, `ArenaGridLines`)
are deliberate.

## Process lessons carried forward (M8.5 addition)

- **Six more plan defects this module — twenty-eight across seven modules
  now.** Implementers stopped on two: the plan claimed the headless GUT root
  is usable for layout (it snaps to 64×64 — host screens in an explicit-size
  SubViewport), and it removed `ControlPicker.BASE_TOUCH_TARGET` without
  listing its three callers. Reviewers found two plan-mandated bugs: weapon
  names collapsing to 1 px in an HBox (needs `SIZE_EXPAND_FILL`) and arena
  previews missing the board's fill. The controller caught two brief
  contradictions at dispatch (a TS caption vs pre-flight M14; Task 7 Step 8's
  orphan loop vs Step 4).
- **When the brief's code and the board disagree, the board wins** (spec
  §6.4) — rule it in the ledger, fix it, add a spec.
- A usage limit can cut an implementer off mid-step with work uncommitted;
  the next session reads `git status` and finishes inline rather than redoing.

## Process lessons carried forward (M9 Task 5 addition)

- **`Timer.time_left` has no setter in Godot 4.7.2** (getter only; `ClassDB`
  shows no `set_time_left`) — a plan-specified test tried
  `timer.time_left = 0.4` to fake a partway-elapsed toast timer and failed to
  parse ("Cannot assign a new value to a read-only property"). Fixed to
  `timer.start(0.4)`, which drives the timer into the same state (twenty-ninth
  plan defect across modules). Anything that needs to fake a Timer's elapsed
  state should restart it at the target `wait_time` instead of writing
  `time_left`.

## M9 — what landed

Plan `docs/superpowers/plans/2026-09-20-m9-milestones.md` (9 tasks); ledger
`.superpowers/sdd/2026-09-20-m9-milestones/progress.md` (git-ignored — every
`Ruling:` line was copied verbatim, in order, into the plan's new
"## Execution rulings (SDD ledger, 2026-09-23)" section before this handoff,
since the ledger itself will be deleted). 9 commits (Task 1 through the final
fix), `b119229..cd77de6`.

| Area | Files |
|---|---|
| Full `GoalManager.ts` port — all 57 goals, `CumulativeStats`, `RunTracker`, `evaluate_run`, `evaluate_live_total_goals`, `evaluate_unlock_goals` | `src/meta/goal_manager.gd` (`gdlint:disable=max-file-lines` line 1, LAW 3 — 1002 lines, plan defect #30) |
| Full `GoalsHUD.ts` port — rail, toast, full-screen Milestones screen, built to the interface boards | `src/ui/goals_hud.gd` |
| Run tracker wired at frame-order step 10; `evaluate_run`/`evaluate_live_total_goals` calls | `src/sim/run_controller.gd` |
| Rail hosted on the HUD arena frame, toast in the HUD `ToastSlot` (R8) | `src/ui/hud_controller.gd` |
| "Points earned" total, earned-milestones list, screen opener; I-1's 450 ms post-`run_ended` fill timer | `src/ui/run_over_sheet.gd` |
| Bare-array save shape (R3) | `src/meta/save_store.gd` (`load_string_list`/`save_string_list`) |
| Tests | `tests/test_goal_manager.gd`, `test_goal_parity.gd`, `test_goals_hud.gd` (the three new scripts); additions to `test_run_controller.gd`, `test_run_over_sheet.gd`, `test_hud_controller.gd`, `test_save_store.gd`, `test_main_scene.gd` |

**Rulings R1–R11** (plan, recorded 2026-09-23 before execution; full text in
the plan's Rulings section):
- **R1** — Run over's "Points earned" total and earned-milestones list are
  ported into `RunOverSheet`; tapping either opens the Milestones screen. The
  rail replaces the old tappable-rail plan (R11); the coins row stays dropped.
- **R2** — `TiltGame.ts`'s second, always-hidden `railProgress` rail is not
  ported (PORT-NOTE; the stale `TODO(M9): railProgress` removed).
- **R3** — completed-goal ids keep the TS's bare-array JSON shape.
- **R4** — callback wiring order matches the TS: `GoalsHud.bind()` installs
  its own callbacks and runs `check_unlock_goals()` before `GameRoot`
  overrides them.
- **R5** — `GameEvents.goal_completed` is emitted by `GameRoot._on_goal_completed`.
- **R6** — Run over row styles come from `TiltGame.ts:855-874`'s injected
  sheet (superseded by `RunOver.dc.html`, interface spec §2).
- **R7/I3** — the run is double-counted at every `evaluate_run` (not only the
  death tick); preserved (LAW 2), PORT-NOTEs added — Open question 1.
- **R8** — rail and toast live in the HUD (`%Frame`/`%ToastSlot` hosts); the
  Milestones screen is `GoalsHud`'s own child between `Hud` and `Armory`.
- **R9** — a 4+ row milestones list clips in Run over rather than scrolling —
  Open question 2, confirm at the device pass.
- **R10** — open run goals show no progress bar (spec §6.5 wins over the
  TS's empty bar) — Open question 3.
- **R11** — the rail is not tappable and there is no backdrop-click close;
  openers are Run over's rows, the `M` key, and (M11) the menu link.

**Pre-flight rulings** (dispatched in parallel with Task 1, scan found 5
Blocking/5 Important/15 Minor, folded into the task text before execution —
full text in the plan's "Execution rulings" section): B1 fixed two Task-3
tests instead of `evaluate_run` (LAW 2); B2 compares the sorted cumulative
key set; B3 keeps the TS's render-before-listeners bind order so pre-owned
unlocks complete silently (Open question 4); B4/B5 are test-only; I1
region-scoped a `gdlint` disable on `get_metric_value`; I2 disabled
`max-public-methods` on four test scripts; I3 is R7 (both double-count sites
covered by one PORT-NOTE + Open question 1); I4 moved the ion ring SVG into
`UiTheme.ICON_RING`; I5 put `next: M9 Task N` in commit messages; M1–M15 were
mechanical fixes (wrapped lines, citations, a rename, a doc string); M8
dropped `GameRoot.get_run_controller()`; M10 accepted GUT orphan-node
warnings from rebuilt children; M14 kept `CapsText` on the header points unit
pending the device pass.

**Plan defects found this module (implementers stopping to ask, #29–31 —
thirty-one across eight modules now, three found here):**
- **#29** (Task 3): the brief's mode-isolation test assumed `survive_*` goals
  check the mode, but `run_survival` (`:930-932`) does not — fixed the
  expected id arrays with a citing comment; the test still proves mode goals
  count only in their mode.
- **#30** (Task 3): `goal_manager.gd` came in at 1002 lines, over gdlint's
  `max-file-lines` — `# gdlint:disable=max-file-lines` at line 1, same
  precedent as `armory_ui.gd`/`entity_layer.gd`/`progression_manager.gd`.
- **#31** (Task 5): `Timer.time_left` has no setter in Godot 4.7.2 — a
  brief-specified test tried `timer.time_left = 0.4`; fixed to
  `timer.start(0.4)`, the same state by another route (see the M9 Task 5
  process-lesson above — this is that defect, restated as the module total).

**Final whole-module review** (`.superpowers/sdd/2026-09-20-m9-milestones/final-review.md`,
opus, over `b119229..4179296`): **Ready with fixes** — 0 Critical, 2
Important, 7 Minor.
- **I-1 — fixed in `cd77de6`.** Run over now fills 450 ms after `run_ended`
  (`TiltGame.ts:2084-2151`, `HudController._on_run_ended` starts a one-shot
  `Timer`, stopped on Retry/any phase change), so a death-tick goal
  completion (step 8's `evaluate_live_total_goals`, which runs after
  `run_ended` in the same frame per R7) now reaches "Points earned" and the
  balance instead of a stale, already-filled sheet.
- **I-2 — parked, plan Open question 6.** The calibrate toast sits in the HUD
  `ToastSlot`, under Pause's scrim and the Armory, so calibration currently
  gives no visible feedback while either overlay is up. LAW 5: stop, don't
  guess — the user rules on where that toast should draw.
- **M-1 through M-4 — fixed in `cd77de6`** (PORT-NOTE on the shared-Escape
  handling that can close both Armory and Milestones; `VERIFY-ME.md`'s M9
  toast line reworded; `goal_manager.gd:24`'s stale process-note replaced).
  **M-5, M-7** — pre-existing patterns outside M9's scope, recorded, not
  fixed. **M-6** — already accepted (belongs to M10).
- One deferred item from the fix pass: the I-1 regression test calls
  `evaluate_live_total_goals` directly rather than driving a real `update()`
  tick; accepted (the re-reviewer verified `run_controller.gd:190-227` has no
  early return between death and step 8), but a future reorder of step 8
  would not be caught by this test.

## Open questions (M9; for the user — copied from the plan's own Open questions section)

1. **R7/I3 — the run is double-counted at every `evaluate_run`, not only the
   death tick.** `evaluate_run` commits the run into `cumulative` (step 1)
   and then, while evaluating that call's own total goals,
   `get_metric_value`'s `total_*` arms add the same tracker a second time
   (`:955-962`) — every game over double-counts a cumulative goal's progress
   by one run's worth, not just the extra death-tick call from
   `evaluate_live_total_goals` (it can complete e.g. *Century of Destruction*
   at 30 lifetime + 40 this run, twice over on death). The plan preserves it
   (LAW 2). Fixing it is a spec change to `evaluate_run`'s step 2/3 ordering,
   not a one-line skip.
2. **R9 — a long Run over list clips** rather than scrolling or growing the
   sheet. Confirm at the device pass, or choose another treatment.
3. **R10 — open run goals show no progress bar** (spec §6.5), where the TS
   draws an empty one. Confirm.
4. **B3 — pre-owned unlocks at bind complete without paying spendable points
   or showing a toast**, as in the TS (`bind()` runs `_init_dom()`, which
   calls `check_unlock_goals()` before `_setup_listeners()` installs the
   callbacks). Only `cumulative.totalPointsEarned` moves;
   `ProgressionManager.data.points` and the toast are untouched. Confirm this
   is kept (LAW 2), or rule that owned unlocks at boot should pay out like a
   normal completion.
5. **Toast slide-in** (`game.css:595`) is not ported; the boards draw no
   motion. Say if it should be.
6. **I-2 — the calibrate message toast sits in the HUD `ToastSlot`, under the
   Pause scrim/Armory, so calibration gives no visible feedback.** Interface
   spec §5 wants both Calibrate controls (Pause's `CalibrateButton`, the
   Armory's Handling "Calibrate tilt") to give "an immediate calibrate +
   toast"; spec §6.5 fixes the toast's position under the lives icons, where
   Pause's sheet and the Armory both draw over it. Where should the toast
   draw while an overlay is up — a host above the overlays (e.g. a slot in
   `GoalsHud`, a top-level layer above the Armory), or an inline confirmation
   in Pause/Handling instead of the shared toast? (final-review.md I-2,
   parked per LAW 5.)

## Process lessons carried forward (M9 addition)

- **Three more plan defects this module (#29–31, all found by an implementer
  stopping to ask) — thirty-one across eight modules now.** #29 (mode
  isolation) and #31 (`Timer.time_left` read-only) are the kind machine
  checks can't catch — a failing brief-specified test was, again, evidence
  the brief was wrong, not the implementation.
- **The pre-flight scan (dispatched in parallel with Task 1) found 5
  Blocking/5 Important/15 Minor issues before any task but Task 1 ran** —
  cheaper than finding them piecemeal across nine tasks. Worth repeating for
  a plan of this size (9 tasks, two behaviour rulings R7/R9 flagged for the
  user at plan time).
- **A ledger `Ruling:` line is load-bearing and the ledger is git-ignored.**
  Every ruling that isn't restated in the plan or `HANDOFF.md` is lost at
  session end. This module's exit copied all of them into the plan verbatim
  (`## Execution rulings`) specifically so a future session (or the user)
  can still see the reasoning behind R1–R11, B1–B5, I1–I5, M1–M15, I-1/I-2,
  M-1–M-7 without the ledger.
- Docs-only task steps (Task 8's VERIFY-ME append) don't always need a
  reviewer seat — the controller reading the diff in place of one is a
  legitimate ruling, but log it as a ruling, not a silent skip, and let the
  final review cover the gap explicitly.

## M10 — what landed

Plan `docs/superpowers/plans/2026-09-20-m10-modes.md` (7 tasks; rulings
R1–R11 at its top, plus an `## Execution rulings` section added at this
exit copying the SDD ledger verbatim); ledger
`.superpowers/sdd/2026-09-20-m10-modes/execution-rulings.md` (git-ignored,
13 lines, copied into the plan before this exit). 8 commits, `2c235eb..2e6b2d2`:
`2c235eb`, `1da36c2` (Task 1, GauntletMaze sim), `42883d0` (Task 2, run
wiring), `5c723b9` (Task 3, mode visuals), `62c1402` (Task 4, banner),
`1677df2` (Task 5, Pause picker), `bbb3b5c` (Task 6, device checks recorded
unrun), `2e6b2d2` (final-review fixes F-1..F-4, folded in before Task 7 per
the ledger's "final review runs before Task 7" ruling).

| Area | Files |
|---|---|
| Full `GauntletMaze.ts` port minus `render()` | `src/sim/gauntlet_maze.gd` (new) |
| Mode captured at `reset_run`; owns the maze; passed through steps 4–8 | `src/sim/run_controller.gd` |
| `TODO(M10)` retags (R3, R7) | `src/sim/enemy_swarm.gd`, `src/core/game_state_machine.gd` |
| Owns/scales the maze; boots the saved mode; `_apply_game_mode()`/`set_game_mode()`; `restart_run` syncs `_state.mode` (F-2); grid clock refreshed on resize (F-3) | `src/core/game_root.gd` |
| Mode colours (R6), code-red vignette, gauntlet corner brackets | `src/render/grid_layer.gd` |
| Maze drawing (`bind_maze`, `_draw_maze`), shared-clip `stripe_polygons` (F-1), `beacon_pulse` | `src/render/entity_layer.gd` |
| Mode announcement banner, 0–2.8 s of run clock (R2) | `src/render/effect_layer.gd` |
| Temporary Pause mode picker, `DIVERGENCE(M10 R1)` (R1) | `src/ui/pause_sheet.gd` |
| Pause stats / Run over subtitle read `run.mode` (R4); R10 no-badge note | `src/ui/hud_controller.gd` |
| Tests | `tests/test_gauntlet_maze.gd` (new); additions to `test_run_controller.gd`, `test_main_scene.gd`, `test_render_layers.gd` (+ F-1's brute-force equality test), `test_pause_sheet.gd` |
| Device evidence (unrun, phone absent) | `godot/VERIFY-ME.md` §M10, 10 unticked checks |

**Rulings R1–R11** (plan, recorded 2026-09-24 before execution; full text in
the plan's Rulings section):
- **R1** — a temporary Pause-sheet mode picker (Segmented `Standard |
  Gauntlet | Code Red`) stands in for `Main.dc.html`'s mode cards (M11).
  Picking calls `GameRoot.set_game_mode` (saves); the running run keeps its
  mode until the next Restart run or Retry. `DIVERGENCE(M10 R1)`,
  `TODO(M11): remove when Main.dc.html's mode cards land`.
- **R2** — the mode banner (`TiltRenderer.ts:513-565`, uncalled in `web/src`)
  is drawn by `EffectLayer` from the run clock (`RunController.elapsed`) over
  each run's first 2.8 s; it hides at run end and shows again at reset.
- **R3** — the opening armada (`spawn_mode_armada`) stays with M11's
  cinematic handover; M10 retags its `TODO(M10)` as `TODO(M11)` and adds no
  stand-in.
- **R4** — `RunController` captures `mode` once in `reset_run`; every in-run
  read and both HUD reads use it (needed because R1 can change the saved
  choice mid-run).
- **R5** — `RunController` owns and resets the maze at its TS position (after
  `scores.reset()`, before `grid.resize`); assigned after construction, like
  `goals`, to keep the constructor under gdlint's 10-argument limit.
- **R6** — mode backgrounds in `TiltRenderer.ts:64-74` are dead in the TS
  (the equipped arena theme always overrides them) — ported anyway per LAW 2;
  what the player actually sees of a mode is the overlays, the maze and the
  banner.
- **R7** — `spawn_sequential_gauntlet_wall`/`spawn_rotating_gate` stay
  uncalled (the TS never calls them; `GauntletMaze.ts` builds the walls
  instead) — their `TODO(M10)`s become PORT-NOTEs.
- **R8** — each 6-px stripe stroke is its true clipped rectangle
  (`Geometry2D.intersect_polygons`), standing in for `ctx.clip()`, which has
  no CanvasItem equivalent; F-1 later shares this clip's work without
  changing the geometry.
- **R9** — the beacon glow (`shadowColor`/`shadowBlur`) waits for M11's
  on-device glow-cost ruling, same class as M2–M4's in-arena glow.
- **R10** — no HUD mode badge; the boards decide what a screen shows (M9 R10
  precedent) — the mode name appears on Pause and Run over instead.
- **R11** — `playGauntletKlaxon` stays uncalled (only referenced by the menu
  audio stub, out of scope).

**Final-review fix wave** (`.superpowers/sdd/2026-09-20-m10-modes/final-fix-report.md`,
base `bbb3b5c`, commit `2e6b2d2`):
- **F-1** — `stripe_polygons` shares one interior stroke's clip, translated
  per stripe instead of re-clipping each one; end stripes still fall back to
  the original full clip. Geometry is byte-for-byte identical (a new
  brute-force equality test proves it) — only the work changed. Benchmark:
  2.06 ms → 0.63 ms per synthetic frame on desktop (~3.3x).
- **F-2** — `GameRoot.restart_run` now sets `_state.mode =
  _run_controller.mode` after `reset_run`, so `GameStateMachine.mode` never
  goes stale after a Pause pick + restart (M11 reads it for the cinematic
  handover).
- **F-3** — `resize_canvas` now also calls `_grid_layer.set_elapsed(...)`, so
  the code-red vignette pulse keeps ticking through a resize.
- **F-4** — `VERIFY-ME.md` §M10's frame-time line corrected to the real scale
  (~650 clipped stripe polygons at 2340×1080, not full-arena-width estimate),
  plus two new device checks: **Early resize** (pre-resize row width persists
  until scroll-off, TS-faithful) and **Ship vs walls on mobile** (the 1.5×
  mobile ship overlaps sim-size walls/gaps, a consequence of the M2.5
  mobile-scale divergence, not an M10 change).

**Deferred minors** (left by ruling, ledger line 65 — final-review triage):
- `_draw_mode_banner` allocates a `StyleBoxFlat` every frame for the banner's
  2.8 s window instead of caching it.
- `BANNER_SUB` duplicates `UiTheme.COLOR_TEXT_MUTED` — kept as a render
  colour with its own `# PORT:` citation rather than reaching into the UI
  theme from a render layer.

**Verification**: 49/49 GUT scripts, 520 tests (519 plan total + the F-1
equality test), 17359 asserts; `gdformat`/`gdlint` clean; `TODO(M10)` grep
empty; `ff4757` grep empty; DIVERGENCE 177 total (106 `UI-SYSTEM`, 3
`M10 R1`); headless `--quit-after 120` 0 SCRIPT ERROR. Full command block
and fresh output: "## How to verify right now" above.

**Device pass pending**: the A55 was absent from `adb` on 2026-09-25.
`VERIFY-ME.md` §M10 has 10 unticked checks (picker, banner, gauntlet walls,
gauntlet crush, gauntlet score, Code Red, multipliers, frame time, early
resize, ship-vs-walls).

## Open questions (M10)

None raised during execution beyond the plan's own rulings (all resolved by
user ruling at plan time, R1–R11 above) and the final review's four fixes
(F-1..F-4, all fixed, none parked). `M11` must still: **remove the R1 Pause
picker** (`DIVERGENCE(M10 R1)`, `TODO(M11)` in `pause_sheet.gd` and
`hud_controller.gd`) once `Main.dc.html`'s mode cards land, and **port the
cinematic handover** (R3 — `TiltEntranceCinematic.ts:192-215`'s
`spawn_mode_armada` call plus Classic's 8-seeker/nuke-orb/2.5 s-shield
opening).

## M5 — what landed

Plan `docs/superpowers/plans/2026-09-20-m5-audio-bake-and-sfx.md` (Tasks 1–6,
commits `160ebb2`..exit). No SDD ledger was kept; execution rulings are in the
plan's `## Execution rulings`.

| File | What |
|---|---|
| `tools/bake-audio/bake_sfx.mjs` | Runs `TiltAudio.ts` unmodified in headless Chrome (Puppeteer from `web/node_modules`), renders each `play*` through `OfflineAudioContext`, and writes 37 16-bit mono 44.1 kHz WAVs. Deterministic. |
| `godot/assets/audio/sfx/*.wav` (+ `.import`) | 37 baked files (15 `dot_pop_NN`, 4 `space_invader_step_N`, 18 singles), imported as QOA. |
| `godot/src/audio/audio_bank.gd` | `attach(host)` builds a 32-voice `AudioStreamPolyphonic` player and loads the bank. Every `play_*` plays its file. Mute and sfx volume drive `volume_linear`. Lightning is pitch-randomised. `music_gain` is stored for M6. `start_music`/`stop_music` are still `TODO(M6)`. |
| `godot/src/core/game_root.gd` | Calls `audio.attach(self)` in `_ready` (R10). |
| `godot/src/core/game_state_machine.gd` | `_init` takes `audio, options`. `unlock` fires at `launch_run`, `stop_music` at menu/stop/pause/armory, and `start_music` on resume when music is on. |
| `godot/src/sim/run_controller.gd` | Applies the mute/sfx/music options in `reset_run` (R11). |
| `godot/tests/spy_audio_bank.gd` | `SpyAudioBank`, a helper that records play and music-lifecycle requests. |
| `godot/tests/test_audio_bank.gd`, `test_audio_call_sites.gd` | Bank behaviour, plus proof that each live SFX fires at its TS moment. `test_game_state_machine.gd`, `test_run_controller.gd` and `test_main_scene.gd` were extended. |
| spec §4.2, §8 M5 | `.ogg` changed to `.wav`. |

Rulings, one line each:
- **R1** WAV (QOA import), not Ogg: this host has no Ogg encoder.
- **R2** 32-voice cap; overflow is dropped (`DIVERGENCE(M5 R2)`).
- **R3** The bake runs `TiltAudio.ts` unmodified, with only three page shims (offline context, instant `resume`, `Math.random` = 0.5).
- **R4** The baked level is the full TS graph (sfx 1.0 × master 0.28). At run time only sfx volume and mute are applied.
- **R5** Render length is each method's last `stop()` time, with no trim and no added tail.
- **R6** `dot_pop` ×15 and `space_invader_step` ×4. Lightning is baked at 1400 Hz and pitch-scaled at play time.
- **R7** No `GameEvents` wiring: the sim calls `AudioBank` directly, as the TS does.
- **R8** `ice_cascade`, `gauntlet_klaxon`, `space_invader_step`, `invasion_alarm` and `warp_in` are baked but not called. `play_warp_in` belongs to M11's cinematic.
- **R9** Music stays in M6. `music_gain` = clamp(vol) × 0.35 is public for M6.
- **R10** `attach()` stands in for `unlock()`'s context creation. `unlock()` is a no-op called at its TS site.
- **R11** Sound options are applied in `RunController.reset_run`, because Retry bypasses the state machine.

## Open questions (M5)

None raised during execution. The Task 4 milestone correction (a plan error,
not a port change) is recorded in the plan's `## Execution rulings`.

## M6 — what landed

Plan `docs/superpowers/plans/2026-09-20-m6-generative-music.md` (Tasks 1–4, commits
`c00cbfd`..exit), executed inline. The execution rulings are in the plan's
`## Execution rulings`. The final whole-branch review (fresh reviewer) found 0 Critical
and 0 Important issues. Two Minor findings about VERIFY-ME wording were re-graded
Important and fixed. The deferred Minors are listed under Open questions (M6).

| File | What |
|---|---|
| `tools/bake-audio/bake_music.mjs` | Loads `TiltAudio.ts` unmodified in headless Chrome and calls its `scheduleStep` for steps 0–511 on the scheduler's `+=` grid. It keeps cycle 2 (frames 1263761..2527522) and writes a 16-bit mono 44.1 kHz WAV. A fresh render within 1 LSB of the committed file keeps that file (Chrome jitters about 4 samples by 1 LSB). |
| `tools/bake-audio/wav.mjs` | The WAV encoder, shared by both bakes (moved out of `bake_sfx.mjs`, whose output is byte-identical). |
| `godot/assets/audio/music/music_loop.wav` (+ `.import`) | 28.66 s, peak 0.058. The import is QOA with `loop_mode=2`, `loop_begin=0` and `loop_end=1263761`. |
| `godot/src/audio/audio_bank.gd` | `attach` adds `_music_player`. `start_music` has the `:86` guard and plays from 0. `stop_music` stops. `_apply_volume` sets music to `0` when muted, else `music_gain / 0.35`. `set_music_volume` applies live. A PORT-NOTE marks the scheduler methods, which run inside the bake. |
| `godot/src/sim/run_controller.gd` | `reset_run` calls `start_music` when `music_enabled`, just before the starting-orb spawn (`TODO(M11)`: both move to the cinematic's end). |
| tests | `test_audio_bank.gd` +7 (now has `gdlint:disable=max-public-methods`), `test_audio_call_sites.gd` +2, `test_main_scene.gd` +1. |
| spec | D5, §4.2 and §8 M6 amended (R1). |

Rulings, one line each:
- **R1** One baked loop: no stems and no `music_sequencer.gd` (user ruling 2026-09-25).
- **R2** Steps 0–511 on the TS `+=` grid; keep cycle 2, whose head holds cycle 1's tails; 1263761 frames.
- **R3** The noise buffer is filled from a seeded mulberry32 (`0x5eed`), not `Math.random`. The bake is deterministic to ±1 LSB.
- **R4** Baked level = musicGain 0.35 × master 0.28. Run time: `volume_linear = music_gain / 0.35`, and 0 when muted.
- **R5** `start_music` returns early if playing, else plays from 0. `stop_music` stops. Resume restarts from the top, as in the TS. `unlock()` is not called.
- **R6** Mute keeps the loop running silently. The TS backlog burst is dropped (`DIVERGENCE(M6 R6)`). Today nothing reaches it: Pause has already stopped the music.
- **R7** Run start is at the end of `RunController.reset_run` until M11.
- **R8** No 50 ms lead-in, stop is immediate, and the first cycle carries the bar-15 tails (`DIVERGENCE(M6 R8)` ×2).
- **R9** The import loop settings are set explicitly. `loop_end=-1` would drop a frame.

## Open questions (M6)

None raised during execution. Deferred Minors from the final review, for the user:
- `test_the_boot_run_starts_the_music_when_it_is_on` checks only the silent branch if
  the host's saved options have music off.
- `bake_music.mjs` prints `kept` for a real TS change whose effect is ≤1 LSB. It could
  print the number of differing samples.
- `bake_music.mjs`'s mulberry32 and WAV-header literals have no citation comment.
- Spec §8 M6 still lists the old stems / `music_sequencer.gd` bullets above the R1
  amendment.

## M11a — what landed

Plan `docs/superpowers/plans/2026-09-20-m11a-menu-and-settings.md` (8 tasks,
rulings R1–R17, `## Execution rulings` section at its end copying the SDD
ledger verbatim, same precedent as M9/M10). Execution: subagent-driven (one
implementer per task, then a review pass). Commits `2664835..HEAD` (Task 1
through this exit).

| Area | Files |
|---|---|
| The menu backdrop — a second, independent autopilot sim mirrored to the board (R1) | `src/render/menu_backdrop.gd` (new), `tests/test_menu_backdrop.gd` |
| Screen shake + Enemy-outlines halo wiring (R2) | `src/sim/run_controller.gd` (`trigger_shake` Callable), `src/core/game_root.gd` (`trigger_shake`/`camera_shake`/`apply_readability`), `src/render/entity_layer.gd` (`set_high_contrast_halo`) |
| The menu screen — Main.dc.html | `src/ui/tilt_menu.gd` (new, 523-line TS source), `tests/test_tilt_menu.gd` |
| MENU phase: boot, `launch_run`/`return_to_menu`/`is_in_menu`, TS key map, HUD R12 menu-visibility guards | `src/core/game_root.gd`, `src/core/game_state_machine.gd`, `src/ui/hud_controller.gd`, `scenes/main.tscn` (`Menu` node) |
| Settings (options modal) + reset confirm — Settings.dc.html (R3, R6–R11) | `src/ui/tilt_menu.gd` (`open_options_modal`/`close_options_modal`, `OptionsModal`/`ResetConfirm`), `src/core/game_root.gd` (`reset_progress_files`, signal wiring) |
| Calibrate — Calibrate.dc.html, a live tilt dot (R4, R5) | `src/ui/calibrate_screen.gd` (new, single-file), `scenes/main.tscn` (`Calibrate` node) |
| Pause reaches the menu: Quit to menu, Settings | `src/ui/pause_sheet.gd` (`QuitToMenuButton`, `PauseSettingsButton`) |
| Run over reaches the menu: Menu button, Coins row (R17) | `src/ui/run_over_sheet.gd` (`GameOverMenuButton`, `CoinsRow`, `set_coins`) |
| M10 R1 Pause mode picker + `GameRoot.set_game_mode` removed | `src/ui/pause_sheet.gd`, `src/ui/hud_controller.gd`, `src/core/game_root.gd` |
| Exit: TODO(M11) retag, VERIFY-ME §M11a, PORT-PROGRESS/index/spec rows | `src/input/tilt_input.gd`, `src/render/entity_layer.gd`, `src/sim/enemy_swarm.gd`, `src/sim/run_controller.gd`, `src/ui/handling_preview.gd`, `VERIFY-ME.md`, `PORT-PROGRESS.md`, the index plan, the port design spec §8 |

**Rulings R1–R17** (plan, recorded 2026-09-25 before execution; full text in
the plan's `## Rulings` section):
- **R1** — the backdrop's autopilot ship and orbs stay clear of the mode
  panel, mirrored to its right-side board position (`x' = w - x`);
  `DIVERGENCE(M11a R1)` ×3 (orb band, wander, side margins).
- **R2** — `TiltRenderer.triggerShake`/`cameraShake` ported into `GameRoot`
  through a `Callable` `RunController` holds; decays ×0.88 per rendered
  frame, skipped in `MENU`; `high_contrast_halo` reaches `EntityLayer` at
  boot and on every Settings change.
- **R3** — the TS "Aim line" switch is omitted (no pointer on Android, no
  board slot); Background grid stays (Rule N).
- **R4** — Calibrate's dot is drawn every frame from `TiltInput.tilt_vector`,
  clamped to the top-speed ring, `DIVERGENCE(UI-SYSTEM)`; Set level
  calibrates + closes; Cancel closes; the sensor starts on open and stops on
  close only from `MENU`.
- **R5** — Calibrate is a new file (`ui/calibrate_screen.gd`), opened from
  the menu icon and from Settings' "Calibrate tilt"; Pause keeps its
  immediate calibrate (M8.5 Rule F).
- **R6** — mode names/taglines/multipliers/labels/"Play"/"Armory"/
  "Milestones"/"Screen shake"/"Reset progress"/confirm text are TS strings;
  two board-string exceptions (Enemy-outlines hint, Data hint, Handling
  link) per M8.5 pre-flight M14; the title is `"PERIL\nPOINT"` (app identity).
- **R7** — Settings shows Touch/Tilt/Keys (off mobile), same set as
  `ControlPicker`; no Mouse/Both card; a card writes through
  `GameRoot.set_control_scheme`; the Calibrate link shows only for Tilt.
- **R8** — the next-milestone teaser and the Background-grid row are kept
  with no board slot (Rule N), `DIVERGENCE(UI-SYSTEM)`; the stats row stays
  hidden while `best_score == 0`.
- **R9 (Q2)** — the options modal's Sound/Music switches apply at once, like
  Pause's, not only at the next `reset_run`; `DIVERGENCE(M11a Q2)`.
- **R10 (Q1)** — Reset progress deletes options, both goal files,
  progression **and the best score** (fixing a TS bug where the real save
  keys were never named); keeps `ControlSettings` and calibration;
  `DIVERGENCE(M11a Q1)`; reload is `get_tree().reload_current_scene()`.
- **R11** — the reset confirm is a board-styled `UiTheme.build_sheet`
  sheet (no native `window.confirm`), `DIVERGENCE(UI-SYSTEM)`.
- **R12** — `HudController` hides/shows `ScoreBlock`/`LivesRow`/
  `PauseButton`/`WeaponTimer` (+ Pause/Run-over sheets) on `MENU`/`PLAYING`;
  `Frame` and `ToastSlot` stay visible so the Calibrate toast shows on the
  menu; `GoalsHUD.set_menu_mode` follows the TS call sites.
- **R13** — in `MENU`, `GameRoot` rebinds the render layers to the backdrop
  (grid theme `null`/mode `CLASSIC`, entity layer to the backdrop's
  player/swarm/weapons with no coins/skins/maze, effect layer to shared
  particles with no floating text/banner); `launch_run` restores the run
  bindings; backdrop entities are never `set_scale`d (PORT-NOTE).
- **R14** — the backdrop steps at the real, unscaled `delta` (no
  `GAME_SPEED`) and keeps its own `elapsed`, independent of the run's
  (PORT-NOTE).
- **R15** — the key map: p/Escape (armory/pause toggle), Space/Enter/r in
  `GAME_OVER` → `restart_run()` (cinematic skip is M11b's, `TODO(M11b)`).
- **R16** — `updateCursor` has no port (Android has no pointer); one-line
  PORT-NOTEs at each TS call site, no TODO.
- **R17** — the Run over Coins row (Rule N): `"<n> · +<pts> pt|pts"` shown
  iff `coins_collected > 0`.

**Execution rulings** (SDD ledger, copied verbatim into the plan's own
`## Execution rulings` section before this handoff):
- Task 4: the p/Escape key path reaches the Pause sheet refresh through
  `HudController.set_pause_panel_visible(true)` → `_refresh_pause_sheet()`.
- Task 4: delta +9 (588 tests) for a regression test covering the two R12
  HUD guards.
- Task 7: 1 test deleted in `test_pause_sheet.gd`, 2 in `test_main_scene.gd`
  (the old mode-picker tests); total 605 + 6 − 2 = 609. The one-line commit
  rule wins over naming deletions in the commit message.
- Task 7: Pause's Settings is a `SecondaryButton` "Settings" beside Armory
  (`Pause.dc.html:46`), not a gear icon — UiTheme has none.
- Task 7: the coins row caption is the TS `"Coin pickups"`, under
  `PointsRow` in the TS's own order.
- Task 7: `UiChecks.overlapping_siblings` skips hidden Containers.
- Task 7: `TiltMenu.close_options_modal()` also hides `ResetConfirm`;
  `GameRoot.set_game_mode` removed (no caller left); `DIVERGENCE` total 232
  (−3 `M10 R1`, +3 `UI-SYSTEM`).

**Task 8 (exit)**: retagged the five remaining `TODO(M11)`s —
`TODO(M11b)` for the cinematic handover (`enemy_swarm.gd:355`,
`run_controller.gd:128`, plus the three already retagged in
`game_state_machine.gd` at Task 4) and `TODO(M11c)` for glow/iOS
(`entity_layer.gd:253`, `handling_preview.gd:16`, `tilt_input.gd:113`);
`TODO(M11b)`/`TODO(M11c)` count 10. Appended `VERIFY-ME.md` §M11a (16 device
checks, the brief's 10 plus 6 more surfaced in review — mode-card tagline
clipping, the Play icon's left-edge placement, Settings' Readability column
fit, Calibrate's flush-right layout, the Touch joystick drawing behind the
menu backdrop, the menu title's missing letter-spacing). `PORT-PROGRESS.md`'s
single M11 row replaced with three: M11a (code complete, device pass
pending), M11b and M11c (both not yet written). Index plan module map and
spec §8 Module 11 updated to the same three-way split. A fresh whole-module
reviewer then found 2 Important bugs (Set level never actually calibrated;
Settings closing over Pause left it stale) and 5 Minor findings — both
Important bugs fixed, Minors deferred; see "Open questions (M11a)" below for
the full write-up.

**Verification** (fresh at this exit): 53/53 GUT scripts, 609 tests (unchanged
from Task 7), 17968 asserts; `gdformat --check` 96 files unchanged; `gdlint`
clean; `TODO(M11)` grep empty; the boundary-aware `M10 R1` grep
(`grep -rnE "M10 R1([^0-9]|$)"`) empty; `ff4757` grep empty; `DIVERGENCE(M11a
R1)` ×3; `DIVERGENCE(M11a Q[12])` ×2; `DIVERGENCE` total 232 (unchanged from
Task 7); headless `--quit-after 240` 0 SCRIPT ERROR; `"$ADB" devices` listed
nothing (A55 absent). **After the controller's own review of this exit
commit (fix-round 1, same day):** DIVERGENCE total **234** (+2,
`DIVERGENCE(M11a I-2)`, retagged from `PORT-NOTE` per Law 4 — new behaviour
with no TS counterpart requires a divergence tag, not a plain note), tests
**611** (+2, regression coverage for I-2 and I-1(b), both proven RED before
their fix and GREEN after). **After fix-round 2 (final review, same day):**
53/53 GUT scripts, tests **611** (unchanged — every fix strengthened an
existing test rather than adding a new one), 17973 asserts (+5); `gdformat
--check` 96 files unchanged; `gdlint` clean; `DIVERGENCE` total **234**
(unchanged — the CoinsRow fit check needed no new board literal); `ff4757`
grep empty; headless `--quit-after 240` 0 SCRIPT ERROR. Full command block
and fresh output: "## How to verify right now" above.

## Open questions (M11a)

1. **Q1 — ruled 2026-09-25: fix it.** Reset progress also deletes
   progression and the best score, closing a TS bug where the confirm
   promised this but the real save keys were never named
   (`DIVERGENCE(M11a Q1)`, R10).
2. **Q2 — ruled 2026-09-25: apply at once.** Settings' Sound/Music switches
   take effect immediately, like Pause's own switches, not only at the next
   `reset_run` (`DIVERGENCE(M11a Q2)`, R9).
3. **Q3 — open.** Android's system back gesture/button has no TS
   counterpart. What should it do on the menu, in Settings and in Calibrate?
   `VERIFY-ME.md` §M11a check 10 asks the device pass to record what actually
   happens (especially whether it quits the app from Settings) so this can
   be ruled then.
4. **Sensor-on-in-MENU — open, device judgment.** The tilt sensor starts at
   cold boot (`GameRoot._ready`) and again on picking Tilt in the Steer row
   (`set_control_scheme`), and stays on for as long as the menu is up;
   `return_to_menu` and `_on_calibrate_closed` are the only places that stop
   it. No TS counterpart drives this (the web page has no persistent sensor
   cost). `VERIFY-ME.md` §M11a check 18 asks the device pass to judge any
   battery or feel issue.

**Final whole-module review** (dispatched at Task 8 Step 5, a fresh reviewer
over `b65eb14..HEAD`): 0 Critical, 2 Important, 5 Minor.
- **I-1 — fixed.** Two calibration bugs: (a) `CalibrateScreen._on_set_level_pressed`
  closed the screen (stopping its poll, then stopping the sensor) before any
  poll ever consumed the pending calibration flag `calibrate_current_position()`
  arms — Set level silently did nothing; fixed by forcing one `_tilt.poll()`
  between the emit and `close()`. (b) `launch_run`'s uncited
  `_tilt.calibrate_current_position()` (no TS citation — `launchRun`/`resetRun`
  never recalibrate) silently overwrote whatever pose Calibrate had just set,
  since Play always follows it back to the menu — removed (`restart_run`'s own
  call is untouched; that one is M2.5's, not this module's).
- **I-2 — fixed.** `TiltMenu.close_options_modal()` emitted nothing, so
  closing Settings from Pause left Pause's Sound/Music switches, its
  `ControlPicker` scheme and its Calibrate-button visibility stale. Fixed: a
  new `TiltMenu.options_closed` signal, connected in `GameRoot._ready` to
  `_on_options_closed` → `_hud.set_pause_panel_visible(is_paused())`, the
  same refresh `_on_pause_pressed` already does; harmless (not a true no-op)
  when Pause was never the opener — `is_paused()` reads false, so it just
  re-hides an already-hidden panel.
- **Controller review round 1 of this exit commit** (same day, follow-up
  commit): the I-2 signal/handler is new behaviour with no TS counterpart, so
  Law 4 requires `DIVERGENCE(M11a I-2)`, not `PORT-NOTE` — retagged both
  sites (DIVERGENCE total 232 → 234). Added regression tests for I-2 and
  I-1(b), both RED-then-GREEN verified by temporarily reverting each fix
  (tests 609 → 611). VERIFY-ME §M11a check 7 amended to flag the
  Restart/PLAY AGAIN-vs-first-Play calibration asymmetry the I-1 fix leaves
  (M2.5's `restart_run` still recalibrates on every restart; the menu's
  `launch_run` no longer does on the very first Play) for the device pass to
  judge.
- **Deferred Minors** (recorded, not fixed at Task 8 — M-1 and M-2 fixed in
  the final review wave below; full text in the plan's
  `## Execution rulings`, Task 8 entries): M-1 `return_to_menu`'s
  `camera_shake = 0.0` reset is miscredited to R2 in its comment; M-2 —
  widened from four to **six** stale pre-split "M11" comments (should read
  M11a/M11b/M11c) once the final reviewer found two more:
  `game_root.gd` (×2), `audio_bank.gd`, `effect_layer.gd`,
  `game_state_machine.gd`, `entity_layer.gd` — now fixed; M-3
  `calibrate_screen.gd`'s legend SVGs hardcode two hex colours instead of
  formatting `UiTheme` tokens in, unlike `tilt_menu.gd`'s own SVGs; M-4
  Settings-over-Pause p/Escape resumes underneath the modal (TS-faithful,
  device-irrelevant); M-5 three draw-arc point counts in
  `calibrate_screen.gd` are uncited (matches existing uncited precedent
  elsewhere). M-3, M-4 and M-5 remain deferred.

**Final review (controller), fix-round 2, same day.** A fresh finding pass
over the Task 8 exit turned up one Important and five Minor items, all fixed
in one commit:
1. The Run over sheet's fit tests never exercised the visible CoinsRow
   (`ui_checks.gd` skips hidden Containers and `_assert_fits` never called
   `set_coins`). `test_run_over_sheet.gd`'s `_assert_fits` now calls
   `sheet.set_coins(3, 120)` before asserting; the real layout already fits
   at both 844×390 and the A55 size, so no board literal changed (DIVERGENCE
   stayed 234) — proven by a temporary oversized `CoinsRow` that made the fit
   check fail, then reverted.
2. `GameRoot._unhandled_input` now skips the joystick branch while
   `is_in_menu()`, so a Touch-scheme tap on the menu backdrop no longer draws
   the floating joystick over the menu. `OS.has_feature("mobile")` gates the
   whole branch and is false headless, so this cannot be exercised by a
   headless test; no test was added (VERIFY-ME §M11a check 15 still covers
   the device check).
3. `return_to_menu`'s untagged `camera_shake = 0.0` reset (M-1) removed —
   the TS `returnToMenu` (:1496-1517) never resets shake and `_process`
   already decays it; no test asserted the line.
4. `test_the_menu_calibrate_icon_opens_the_screen_and_set_level_calibrates`'s
   `ToastSlot.get_child_count() > 0` (always true — `GoalToast` lives there
   permanently) replaced with an assertion on the toast's actual title text.
   Headless has no gyro (`TiltInput.is_supported` is Android/iOS only), so
   `calibrate_gyro` shows the "GYRO SENSOR" fallback there, not "TILT
   CALIBRATED" — the test now asserts that title and the toast's visibility.
   The `is_listening` assertion is kept, reworded to say it is trivially true
   headless for the same reason.
5. `test_main_scene.gd`'s save-clearing `before_each`/`after_each` now also
   remove `TiltInput.CALIBRATION_PATH` — proven leaking a real file
   (`user://tilt_gyro_calibration.json`) across runs before the fix, clean
   after.
6. M-2 widened and fixed (see above) — six stale "M11" comments retagged to
   M11a/M11b/M11c; comments only, no behaviour change.

Verification after this wave: 53/53 GUT scripts, 611 tests (unchanged — every
change strengthened an existing test), 17973 asserts; `gdformat --check` and
`gdlint` clean; `DIVERGENCE` total 234 (unchanged); `ff4757` grep empty;
headless `--quit-after 240` 0 SCRIPT ERROR. Full report:
`.superpowers/sdd/2026-09-20-m11a-menu-and-settings/final-fix-report.md`.

## M11b — what landed

Plan `docs/superpowers/plans/2026-09-20-m11b-entrance-cinematic.md` (3 tasks,
rulings R1–R12, `## Execution rulings` section at its end, same precedent as
M9/M10/M11a). Execution: subagent-driven (Task 1, Task 2, then one final
whole-branch review). Commits `402c161..8ba3745` (plan approval through the
final-review fix commit; this doc commit is the exit).

| Area | Files |
|---|---|
| `TiltEntranceCinematic.ts`: start/update/skip/finish on the run's sim systems, plus the ColdOpen board overlay | `src/ui/entrance_cinematic.gd` (new), `tests/test_entrance_cinematic.gd` (new) |
| `start_cinematic` enters `CINEMATIC`; the skip PORT-NOTEs corrected for R9 | `src/core/game_state_machine.gd` |
| Owns `_cinematic`; `_begin_cinematic`, `_on_cinematic_finished`, `skip_cinematic`; launch/restart/return; the CINEMATIC key map; the cinematic tick; resize | `src/core/game_root.gd` |
| `finish_cinematic` takes over the music and the starting orb from `reset_run` (M6 R7 closed) | `src/sim/run_controller.gd` |
| `_on_phase_changed` hides the sheets on `CINEMATIC` too (R9) | `src/ui/hud_controller.gd` |
| `spawn_mode_armada`'s `TODO(M11b)` (M10 R3) resolved into a caller citation | `src/sim/enemy_swarm.gd` |
| `ColdOpen` node between `GoalsHud` and `Armory` in `CanvasLayer` | `scenes/main.tscn` |
| Tests for the phase, the handover, the moved music/orb, the CINEMATIC key map, Retry/Restart replay | `tests/test_main_scene.gd`, `test_game_state_machine.gd`, `test_run_controller.gd`, `test_audio_call_sites.gd` |
| Exit: VERIFY-ME §M11b, PORT-PROGRESS/index rows | `VERIFY-ME.md`, `PORT-PROGRESS.md`, the index plan |

**Rulings R1–R12** (plan, recorded 2026-09-26 before execution; full text in
the plan's `## Rulings` section):
- **R1** — the ColdOpen board is the layout authority over the TS DOM's own
  sizes (52 px ship, 58 px title, 160×2 bar at bottom 44), per the M8.5
  precedent; the title is `"PERIL POINT"` (app identity), not the TS
  `"TILT TO LIVE"`.
- **R2** — `TiltEntranceCinematic.render()` paints a canvas the player never
  sees (an opaque overlay sits above it); not ported, PORT-NOTE only.
- **R3** — the ship glyph's glow waits for the M11c device measurement
  (spec §4.5); drawn flat with `TODO(M11c)`.
- **R4** — the fill bar sets whole-percent width every tick, as the TS does;
  the CSS 50 ms transition is not ported (PORT-NOTE).
- **R5** — `GameRoot` owns the cinematic; `GameStateMachine` holds no UI
  (spec §5.1) and only flips `phase = CINEMATIC` after `reset_run`.
- **R6** — the TS `onFinish` splits: `GameRoot._on_cinematic_finished` sets
  `PLAYING`; `RunController.finish_cinematic` starts the music and spawns
  the starting orb.
- **R7** — a tap/click or Space/Enter/Escape skips, checked before the
  restart and pause keys so Escape skips and never pauses; `{ once: true }`
  is not ported since `skip()` is already idempotent.
- **R8** — `return_to_menu` calls `cinematic.skip` after the phase flip, as
  the TS does, even though no path reaches a playing cold open there (the
  opaque overlay covers both callers); ported as written (Law 2).
- **R9** — `CINEMATIC` hides the pause and game-over modals the same way
  `PLAYING` does, so a restart key inside the run-over's 450 ms delay
  (M9 I-1) cannot reopen a stale Run over sheet during the new run.
- **R10** — every Retry, Pause→Restart and Space/Enter/r after death replays
  the 600 ms cold open, as the TS's `startCinematic` calls do.
- **R11** — the cinematic ticks at the real, unscaled `dt`, joining the
  grid and particles in the existing `CINEMATIC` arm of `_physics_process`.
- **R12** — the start armada is new gameplay in the port, faithfully ported:
  Classic gets 8 ringed seekers + a nuke + a 2.5 s shield; Code Red gets the
  24-seeker armada + a vortex + a nuke; Gauntlet gets the edge-seeker armada
  + a nuke. Resolves `spawn_mode_armada`'s `TODO(M11b)` (M10 R3).

**Execution rulings** (SDD ledger, copied into the plan's own
`## Execution rulings` section before this handoff):
- Task 2 deviations, accepted by review: a `SubViewport(1280×720)` host in
  `test_play_opens_the_cold_open_and_hands_over_to_the_run`, because the tiny
  headless viewport let the shielded ship ram all 8 seekers;
  `gdlint:disable=max-returns` around `GameRoot._unhandled_input`;
  `shield_timer = 0.0` before a forced `lose_life()` in death tests, a new
  precondition from the 2.5 s spawn shield; an extra `skip_cinematic`/
  `finish_cinematic` call in the unlisted tests
  `test_p_and_escape_follow_the_ts_key_map` and
  `test_starting_orb_is_the_equipped_ships_weapon`.
- Task 2 fix round 1 restored `test_run_over_menu_returns_to_the_menu` past
  the spawn shield (the test passed without ever reaching `GAME_OVER`,
  because the shield blocked `lose_life`).
- Final whole-branch review (opus, `8451536..b9780f4`): 0 Critical, 0
  Important, ready "with fixes." **F-1 (comment-only)** — three stale
  `game_state_machine.gd` PORT-NOTEs corrected: the run HUD and the pause/
  game-over modals now cite `phase_changed(CINEMATIC or PLAYING)` (M11a R12,
  M11b R9), and `setMenuMode(false)` now credits both `GameRoot.launch_run`
  and `GameRoot.restart_run`. **F-2 (comment-only)** — `entrance_cinematic.gd`
  `_glow()`'s `fill_to = Vector2(1.0, 0.5)` now carries the same
  `DIVERGENCE(UI-SYSTEM): ColdOpen.dc.html — at 50% 50%` tag as the
  preceding `fill_from` line (Law 1). **F-3 (code + test)** — `_gui_input`
  skipped on any pressed `InputEventMouseButton`, including the scroll
  wheel and right-click; the TS listens for `click` (primary button only,
  `TiltEntranceCinematic.ts:101`) and `touchstart`. Now requires
  `button_index == MOUSE_BUTTON_LEFT` for the mouse branch; one new
  regression test proves the wheel and right-click emit nothing and a left
  click does (631 tests, +1 over Task 2's 630). `GameStateMachine.stop()`
  has no caller in the port.

**Verification** (fresh at this exit, after F-1..F-3): 54/54 GUT scripts,
631 tests, 18076 asserts; `gdformat --check` 98 files unchanged; `gdlint`
clean; `TODO(M11b)` grep empty; `TODO(M11c)` grep 4 (the M11a count of 3 +
the ship glow, R3); `ff4757` grep empty; `DIVERGENCE` total 244 (234 + 10
`ColdOpen.dc.html` tags); headless `--quit-after 240` 0 SCRIPT ERROR;
`"$ADB" devices` listed only `emulator-5554` (A55 absent). Full command
block and output: "## How to verify right now" above. Full report:
`.superpowers/sdd/2026-09-20-m11b-entrance-cinematic/task-3-report.md`.

## Open questions (M11b)

1. **R8's unreachable quirk.** The TS `returnToMenu` and `stop` call
   `cinematic.skip` after leaving the cinematic phase. A playing cold open
   would then spawn its armada and set `PLAYING` under the menu. Nothing
   reaches this today, so it is ported as written. If M11a's Q3 ruling makes
   Android back call `return_to_menu`, the back handler must be a no-op
   during `CINEMATIC`, or this needs its own ruling.
2. **R1, the layout authority.** The board's sizes are used, not the TS
   DOM's (72 px ship, a clamp(48–76) title, a 200 px bar at bottom 120).
   This follows the M8.5 precedent. The user can overrule it at review.
3. **R10, the replay cost.** Every Retry now costs 0.6 s of cold open (a tap
   skips it), as in the TS. The device pass judges this (`VERIFY-ME.md`
   §M11b check 6).
4. **F-4, parked (final review Minor).**
   `test_a_tap_on_the_cold_open_skips_it` calls `_gui_input` directly and
   never goes through the viewport. **Ruling:** the tree order was checked
   by hand (Armory is the only later sibling under `CanvasLayer` and it is
   hidden when closed, so it cannot steal the input ahead of `ColdOpen`),
   and the device pass covers the real input path.
5. **Parked (final review Minor).**
   `test_music_starts_once_at_the_handover` cannot count `start_music`
   calls, because `AudioBank._music_player.playing` is a boolean, not a
   counter. **Ruling:** `start_music` is idempotent (`audio_bank.gd:166`),
   and the test's orb-count assertion (one starting orb, not two) already
   guards the single handover Review Focus 1 cares about.
6. **Parked (final review Minor).**
   `test_restart_inside_the_run_over_delay_keeps_the_sheet_shut` never
   asserts that the run-over timer was running before the restart key is
   pressed. **Ruling:** an R9 regression (the timer not stopping on
   `CINEMATIC`) still fails the test regardless, and M9's own tests cover
   the timer actually starting — the missing precondition weakens the test's
   story but not its coverage.

## Next

**Now (2026-09-29): the MVP roadmap.** Read `docs/superpowers/plans/2026-09-29-mvp-roadmap.md`
and work its Week 1 top down:
1. analytics and crash reporting (step 1 done; step 2 is next, see Latest above);
2. the first run (Standard by default, a one-time hint);
3. ~~the Android back button and pause on focus loss~~ (done, see Latest);
4. ~~haptics~~ (done, see Latest);
5. the AAB export and a real upload key;
6. the mode renames (MVP R4), once the user names them;
7. the tablet's texture error.

Open decisions for the user: MVP R3 (clickable power-ups) and the new mode names. Since
the last entry: UI R13 (one nav button with glyphs on every screen), ORB R1 (power-up
magnet; opening orbs exempt), TOUCH R1 (the stick's base follows the thumb, it reaches
tilt's top speed, Stick size slider), and 0.1.1 built and installed. Suite 775.


**Done (2026-09-28): Armory / economy / icons rework** — plan
`docs/superpowers/plans/2026-09-28-armory-economy-icons.md` (user request; rulings ECON
R1–R5, ARMORY R1–R4, ICONS R1–R3, RUNOVER R1; all 9 tasks ticked). In short: each run
now pays `60 + 3·seconds + 4·kills^0.7` (× mode) at death, coins 10, milestones ×50;
prices rescaled (perk ranks 250→1,600, boosts 500–7,000), fresh saves start at 500 and
the TS "< 500 → 7,331" reset is gone; only keystones with an effect are sold (Supernova,
Cross Beam; the others refunded on load); the black hole's inside-shield is innate.
Armory weapons and boosts are single-column rows (`ArmoryUI._upgrade_card`: now → next,
"Need N", Max, pip pop); one icon set (`render/weapon_icons.gd`) drives the Armory, the
HUD timer and the playfield orbs (baked sprites); the Run over shows only "+earned"
(count-up), Destroyed, and an "N upgrades ready" nudge. Suite 734.
`tools/emulator/deploy.sh [--fresh]` builds, installs and launches on the emulator.

**Then (2026-09-28, plan `docs/superpowers/plans/2026-09-28-achievements-keystones-ui.md`):**
Milestones are "Achievements" to the player (code names unchanged), a run's achievements
all reach the Run over (scrolling list under the stats) and their toasts queue; Armory
buttons show plain prices; every power-up has 3 coded keystones (21, `tests/test_keystones.gd`);
a UI pass fixed the menu balance, menu legibility, multiplier format, stale Settings copy
and the achievement marks. Suite 752.

With every upgrade maxed, missiles are the heaviest power-up (Cluster Split + Second
Salvo triple the missiles); P35 (native missile snapshot) cut their weapon cost ~30%.
The menu fits itself to each device's height (UI R7) and `tests/test_device_matrix.gd`
checks 8 real resolutions. Suite 757.

An idle menu no longer fills with enemies (UI R10): the backdrop's swarm spawns on its
own only below 24 (`EnemySwarm.spawn_cap`) and never picks the 72-dot wall
(`EnemySwarm.formation_pool`); runs are unchanged. 10 min desktop idle peaks at 32
enemies (was 147). PERF's `men=` is the menu swarm; `tools/emulator/menu_idle.sh <tag>…`
idles `build/peril-point-<tag>.apk` on the menu and logs PERF. Suite 762.

The menu's controls read at a glance (UI R11): the selected Steer segment is ion with a
Touch/Tilt glyph (all `SegmentButton`s), Armory and Achievements are raised `NavButton`s
with ion chevrons / a flare trophy, and Settings is a real cog.

No multiplier text remains in the Run over subtitle or the run-start banner (UI R12);
UI labels are sentence case, names Title Case. Unlockable enemy skins paint a pattern on
every default dot (SKIN R1, `render/enemy_textures.gd`, baked into the dot sprites). The
Arena tab buys only from an explicit button (ARMORY R5, superseded by R6/R7).

The Ships and Arena tabs are showcases (ARMORY R7): one item per carousel on the left (◀
▶ cycle, wrap), the arena preview on the right (`ui/arena_preview.gd`, the run's
background shader plus grid, edge, skin dots and ship). Disabled buttons are dim with a
lock on unaffordable prices; SecondaryButton is raised and bright; Equip is the ion
`EquipButton` (ARMORY R6). Suite 767.

Nav buttons share `UiTheme.nav_button()`: a glyph beside the label on the menu, Pause
and Run over (UI R13). Power-up orbs have a coin-style magnet, except the run's opening
orbs (ORB R1). Suite 770.

The touch stick's base follows the thumb, full push matches tilt's top speed, and its
size is a Handling slider (TOUCH R1, player feedback). Suite 775.

**Next, literally:** when the A55 is on `adb`, run VERIFY-ME §Armory / economy / icons
rework with the user (economy knobs are listed there), then continue with the list
below (kill path in C++, weapons section, release libs). The A55 pass on `b4901c1`
held 60 fps up to 251 enemies (VERIFY-ME §M11c 8, 15).

**Where it stands (2026-09-28, latest).** N6 (plan → N6): the PERF line now splits the
main-thread frame into `m_phys` / `m_proc` / `m_tail` (plus `rcpu`, `pmax`, `phmax`);
`tools/emulator/perf_buckets.sh` prints the split. On the emulator `m_tail` (RenderingServer
sync/draw and presentation, after the `_draw` flush) is **~26–31 ms at every enemy count**,
even under 50, and vsync off does not change it: a fixed emulator/engine cost. The game's
own share at 250+ is ~24 ms (m_phys 12.4 + m_proc 11.5) of a ~50 ms frame, so script wins
barely move emulator fps. Separate render thread re-confirmed (250+: ~22.5 vs ~14.5 fps
for Safe). `Performance.TIME_PROCESS` is a per-second max, not a per-frame cost.

**N7 landed** (plan → N7): particles are the C++ class `PerilParticle`; flush, draw
and all seven emitters run in C++ (`native/src/peril_particle.*`), bit-identical
(`tests/test_native_particles.gd` oracle incl. RNG; `bench/pixel_native_particles.gd` 0 px).
`ParticleEngine.use_native` / `EffectLayer.use_native_draw = false` are the references.
Emulator at 250+: s_particles 1.37 → 0.25, d_effect 1.76 → 0.45 ms/frame; fps within
noise (the emulator tail). Suite 712.

**Next, literally:**
1. The kill path (`RunController.on_enemy_killed` / `handle_enemy_killed`,
   `ScoreManager.register_kill`; slower since N3 on native fields): profile a mass kill
   (`bench/bench_sim.gd` 30 kills, `bench_powerups.gd` nuke worst tick), then move what
   dominates, output-identical as N3–N7. Then weapons (`s_weapons` 3.5–5 ms/frame at 150+).
   Judge by section times on the emulator (`perf_buckets.sh`), not its fps; reboot the
   emulator first if it has been up many hours (m_tail grows with uptime).
2. Items 2–3 of the list below (A55 pass — fps is judged there now; release libs).

**Earlier (2026-09-28, later).** N4 landed (plan, "Native swarm tick" → N4):
EntityLayer's enemy loop runs in C++ (`PerilEnemyDrawer`, `native/src/peril_draw.*`):
default and frozen dots draw natively, every other type calls its GDScript `_draw_*`
in place (same order). Pixel-identical (`bench/pixel_native_draw.gd`, windowed: 0 of
921,600 px, mutants caught); `tests/test_native_draw.gd` pins call order, satellite
map and caches; `EntityLayer.use_native_draw = false` is the reference. Suite 704.
Desktop entity draw 430 → 172 µs/frame (115 seekers). Emulator d_entity at 250+ 7.0
→ 4.8 ms/frame, **but fps did not move** (23.7 → 23.2, noise): the probed script
sections are ~17 ms of a ~43 ms frame, and the draw-call count is ~2 per enemy (669
at 327) because each dot alternates two textures, so nothing batches.

**N5 landed too** (plan → N5): each dot look is one atlas texture (two regions, no
`clip_uv`; ruling in the plan: 1 px at 1/255 vs the pre-atlas render, accepted).
Desktop draw calls 258 → 29 (115 seekers); emulator 250+ draws 651 → 477, **fps again
unchanged** (24.4 → 23.3, noise).

**Next, literally:**
1. Find the emulator frame time the PERF probes do not see (~26 of ~43 ms at 250+)
   before more script-side work: add `Performance.TIME_PROCESS` and
   `TIME_PHYSICS_PROCESS` to the PERF line (`GameRoot._report_perf`), and A/B a
   Safe-render-thread build against Separate (P24) at 250+. A/B recipe: build the
   native lib (toolchain row below), `tools/emulator/perf_patch.sh apply`, export
   `build/peril-point-god-<tag>.apk` per variant, `perf_patch.sh revert`, then
   `LOGS=<dir> tools/emulator/ab.sh <a> <b>` ×3 and `tools/emulator/perf_buckets.sh`.
   The emulator translates the whole arm64 engine, so the A55 is the real judge.
2. Then particles in C++ and the kill path (items (b), (c) below).
3. Items 2–3 of the list below (A55 pass; release libs) are unchanged.

**Earlier (2026-09-28).** N3 landed (plan, "Native swarm tick" → N3):
`Types.Enemy` became the C++ class `PerilEnemy` (`native/src/peril_enemy.h`, same
fields and defaults; renamed everywhere); the per-enemy loop
(`PerilNative.swarm_step`), separation over the enemies (`separate_enemies`) and the
collision x reject (`collision_candidates`) run in C++, bit-identical to the GDScript
reference (`EnemySwarm.use_native = false`; oracle `tests/test_native_swarm.gd`,
mutation-checked). Charger, artillery, pulsar and snake still run their GDScript
`update_*` from the C++ loop (randf/particles/bullets). Emulator at 250+ enemies:
fps 17.8 → 24.7 (25.0 with N3d), physics 34.7 → 11.8 (9.2 with N3d) ms/frame, swarm 26.5 → 4.4. Desktop full tick
198–293 → 68–76 µs. Cost: GDScript reads of enemy fields are ~1.5× slower (entity
draw 5.5 → 7.0 ms/frame at 250+ on the emulator; mass-kill ticks ~15% slower).

**Next, literally:**
1. The largest per-frame sections at 250+ enemies are now entity draw (7.0 ms) and
   the rest of the engine frame; in the sim, weapons 2.3, collide (N3d A/B in the
   plan: 2.96 → 0.59 ms/frame at 250+), particles 1.2, goals (~17 µs/tick desktop). Candidates, in order:
   (a) entity draw — gather each enemy's draw fields in C++ (one call returning
   packed arrays) instead of per-field reads; (b) particles in packed arrays / C++
   (the plan's Power-up FPS step 4); (c) the kill path (`on_enemy_killed`,
   `register_kill`), now slower on native fields. Each output-identical with an oracle
   or pixel check, as N3 was.
2. When the A55 is on `adb`: VERIFY-ME §M11c 7–14 (native build included).
3. Before any **release** export: build `template_release` libs (Windows and
   Android; only `template_debug` ones are committed) — with no GDScript fallback
   left, a release APK without them does not start. An iOS export would likewise
   need an iOS build of `libperil` (not set up; `TODO(M11c)` at `tilt_input.gd:113`).

**Earlier (2026-09-27, ~22:30):**

**Where it stands (2026-09-27, ~22:30).** Since the handoff was last rewritten
(`2371545`, the C++ scaffold), six commits landed (`33a34fa..9b4581e`), all in the
plan's sections "N2", "User rulings (2026-09-27, evening)" and "Power-up FPS":
- **N2 — separation in C++** (`PerilNative.separate`, `EnemySwarm.use_native`,
  default true). Bit-exact: every sweep oracle runs both paths. Blob of 325: 4.6×
  faster; late-mix swarm step −39%. Emulator A/B: fps 25.8 → 29.2 at 150–199.
- **P29 — wall formations spaced out** (user): spacing 32 × scale, TS dot radius 8,
  3-slot gap (`EnemySwarm.WALL_SPACING/RADIUS/GAP_HALF`). The default ship is still
  blocked; smaller hitboxes (Shuriken, Singularity, hull compact) can slip through,
  which is the user's call.
- **Milestone rail hidden** (user: "a bar on top which doesnt seem to be doing
  anything"). The Milestones screen and the toasts remain.
- **Arena clip:** entity, effect and grid-line layers are clipped to the arena
  outside the menu (blast rings and warped grid lines drew into the margin; the
  TS canvas *is* the arena).
- **P31 — grid step and big blasts in C++**, **P32 — missile snapshot**, **P33 —
  vortex locals**, all bit-exact with golden tests. Power-up extra cost
  (`bench/bench_powerups.gd`, µs/tick): missiles 184 → 70, vortex 179 → 55, nuke
  50 → 26; nuke worst tick 1.6–2.0 → 0.66–0.77 ms.
- **This commit:**
  - The APK now excludes `build/*, bench/*, tests/*` (the review's deferred
    minor). Export verified: 0 such files in the APK, and it boots on the
    emulator with 0 script errors.
  - The perf patch gained a **test mode** (user: "a test mode which just spawns
    faster and trigger different power ups between intervals"). Every
    `POWER_EVERY` s (default 3) it fires the next of `POWERS` (all seven by
    default) at the ship, with faster spawns (`FAST_SPAWN=0` turns them off),
    and logs `POWER <NAME> en=N`.
  - `tools/emulator/nuke_fps.sh` → `power_fps.sh` reads those lines.
  - The patch is never committed applied: `perf_patch.sh apply|revert`.
  - **The test mode has not been run yet.**
- **Open:** the debug APK is 87.8 MB (32 MB at the start of M11c; the Gradle
  build and the native libs landed since). Not investigated.

**Next, literally:**
1. Run the test mode on the emulator: `tools/emulator/perf_patch.sh apply`,
   export, install, play it, then `power_fps.sh`; then `perf_patch.sh revert`.
   Confirm it works, and record per-power-up fps and enemy counts in the plan's
   "Power-up FPS" item. The user's priority is "the FPS drop when powerups are
   used".
2. Then that item's remaining steps:
   - (3) the HUD score pulse once per frame, not per kill;
   - (4) particles in C++ (the particle flush is 45–96 µs/tick; laser kill
     bursts have a 0.85–0.93 ms worst tick).
   Each one output-identical with a golden or oracle test, as P31–P33 were.
3. When the A55 is on `adb`: VERIFY-ME §M11c 7–14.

**Review fixes in progress (2026-09-27) — plan
`docs/superpowers/plans/2026-09-27-m11c-review-fixes.md`.** The user said "for
now always proceed", so the rulings (P13–P16 and the UI calls) are Claude's,
recorded in that plan. Done: baked dot sprites + batched circles/dashes (P13/P14),
bit-exact windowed separation (P15), worker-thread saves (P16), HUD/menu
outlines, the black Handling preview ship (SVG colour bug), close-call popup
size, the "+0" payout hint, Armory scroll/purchase flash, wrapping taglines,
Settings header inset. Then Task 10 (FPS, the user's standing priority — "always
take a look at the fps"): P17 carrier satellite maps, P18 pre-triangulated polygons,
P19 baked carrier/pulsar/artillery/charger bodies, P21 collision early-out, P22 cached
live goals, P23 inlined seeker step (all output-identical: golden hashes / pixel
checks); P20 (glows-first batching) reverted — slower on the emulator. Emulator fps
at 150–249 enemies across the day: 5.4 → ~18. The sim now dominates (separation
~280 µs/tick desktop is near the GDScript floor). **Next:** read the P22/P23/
Separate-render-thread A/B in the plan; remaining levers need the user: 60 Hz sim +
interpolation (spec D8 says 120 Hz) or a GDExtension for the swarm tick; then the
rest of Task 9's UI list. Wall formations and carriers were the user-reported drop
points. Later the same day (Tasks 11–12): the grid is back on by default (active-set
springs keep it at ~0.45 ms/frame on the emulator), the arena background is a
dithered shader (no banding), the menu no longer shows a half border, and a boot
splash (rendered from the ColdOpen board by `godot/tools/make_splash.gd`) plus ship
app icons (`godot/tools/make_icons.gd`) replace Godot's. Open: the Android 12 system
splash background stays light without a Gradle build. Then the rest of Task 9 (boost
names were squeezed out by clip_text; "+N pt(s)" rewards; "Score …" on Pause; live
"NEW BEST"); the other review items were either already handled in code or TS/board
content (listed in the plan). The user said "no need to clear. just proceed
entirely" (2026-09-27): keep going task to task without /clear stops. Since then: the
Android build uses Gradle (dark system splash; one-time local setup in VERIFY-ME §0),
a fresh reviewer's four findings are fixed (reset flush, look-keyed sprite caches,
texture-sized frozen/satellite draws, scroll per tab), and particles integrate once
per rendered frame (P25: 150+ enemies `s_particles` 4.9 → 1.1 ms/frame on the
emulator). The sim is at GDScript's per-object floor (~1–2.5 µs/enemy/tick); further
FPS needs the user's call: a 60 Hz sim with interpolation (spec D8 chose 120 Hz) or a
native (GDExtension) swarm tick (Python 3.13, MSVC and Rust are installed; only the
NDK is missing). **Verification ×5 done (2026-09-27; results in the plan's last
section):** all automated checks, the UI pass (`tools/emulator/verify_ui.sh`), launch
and benches were stable 5/5. It caught one false "fixed" claim: the menu edge was still
there, and is now fixed (`GridLayer.grid_fills_viewport`). The ~3–5 s black gap between
the system splash and the boot splash is still open (engine start). P24 was confirmed
by a 5-pair Safe-vs-Separate A/B: Separate is ~40–50% faster at 100–249 enemies and
the same at 250+. FPS research (plan, section "FPS research") ranks the next sim
levers: a y-filtered separation window, inlined per-type updates, structure-of-arrays
enemy fields, then native separation. All but the native step are exact and need no
ruling beyond the user's go-ahead. A release export is only 5–12% faster than debug
(measured). Since then (2026-09-27 evening, all in the plan): a C++ GDExtension (`native/`,
godot-cpp 10) runs separation, the grid step and large grid blasts bit-exactly;
missiles use a per-tick snapshot; the HUD pulses once per frame; play layers are
clipped to the arena; wall formations are spaced out (32, TS radius 8); the milestone
rail is hidden. `tools/emulator/perf_patch.sh` is a never-committed test mode (fast
spawns, a power-up every 3 s, maxed upgrades, square autopilot, on-screen readout).
Emulator must run with `-feature -Uwb` (its UWB HAL crash-loops). **Next:** N3 — the
swarm's per-enemy loop in C++ (the main cost again), then particles in packed arrays;
or the A55 pass (VERIFY-ME §M11c 7–14). Desktop draw benches: run with `--render-thread safe`. Emulator notes: the arm64
APK runs under translation; reboot the emulator if the sensors HAL crash-loops
(it skewed one run); keep the host idle while measuring; a no-death build is a
temporary one-line early return in `RunController.lose_life`, never committed —
remove it with the exact inverse edit, **not** `git checkout -- run_controller.gd`
(that once wiped an uncommitted change in the same file). A/B protocol:
`scratchpad/ab.sh <build-a> <build-b>` installs each god APK, starts Code Red, steers
with `bot.sh` for 100 s and logs PERF; bucket by `en=`.

**Emulator UX review (2026-09-27):** the user asked for a nitpick pass by playing
over `adb`. The A55 was absent, so it ran on the emulator (the arm64 APK installs
and runs there under translation). Findings, ranked, in
`docs/superpowers/reviews/2026-09-27-emulator-ux-review.md`: 11 flaws (top ones:
entities draw over the HUD and menu text, the Handling preview ship draws black,
the HUD hides the playfield corners, close-call popups are unreadable, and a "+0"
payout has no explanation) plus UI/UX improvements for each screen. It also has
an **FPS-under-load** section: a Code Red run with a temporary no-death build
(reverted) reached 187–367 enemies. Entity draw is about 2/3 of the frame at every
load; a wall formation adds about 80 dots at once; the non-dot enemies still use
`draw_circle`/`draw_arc`; the death tick hitches. Nothing is fixed yet. **Get the user's rulings on which to fix**, then plan them. The A55
hitch analysis (below) is still pending the phone.

**A55 result (2026-09-26, build `580c854`):** the user played; no second
below 55 fps at any enemy count, >20 ms frames 1.7% (VERIFY-ME §M11c check 1,
ticked). The user then ruled **P9**: the ring formation keeps too little
room, so it drops to 8–10 dots (Classic) and 11 (Code Red). Remaining: checks
2–6 on the P9 build, and a longer late run (only 3 s above 100 enemies).
Entity draw (7.1 ms at 100+) is now the largest cost; the other enemy types
still use `draw_circle`/`draw_arc`.

**Finish measuring M11c part 1 on the A55.** When the phone is on `adb`: export and
install the debug APK (VERIFY-ME §0), then run `VERIFY-ME.md` §M11c part 1
with the user playing. If check 1 misses the target (fps ≥ 58 at 100+
enemies), read the largest remaining `PERF` section and stop for a ruling —
candidates are the other enemy types' draws (charger, artillery, carrier,
pulsar, specter keep `draw_circle`/`draw_arc`), `GoalManager.evaluate_live_total_goals`
(P7), or MultiMesh (spec §9).

**Then plan M11c part 2** (glow, icons/splash, signed release, the rest of
the device pass). Its first step: read spec §4.5 and §8 Module 11, all of
`godot/VERIFY-ME.md`, every `TODO(M11c)`, `export_presets.cfg` and this
file's toolchain section below. Facts already gathered on 2026-09-26:
- The TS has only 5 `shadowBlur` sites: `ArmoryUI.ts:1086` (preview ship),
  `GauntletMaze.ts:364` (beacons), `TiltEntranceCinematic.ts:150`
  (inside the unported `render()`, M11b R2), `WeaponSystem.ts:710,730`
  (vortex arms and photon ring). Add the board's `ColdOpen.dc.html`
  drop-shadow on the ship. A full-screen WorldEnvironment glow is not
  affordable, given part 1's numbers; the per-draw fallback of §4.5 fits 5 sites.
- Release signing: Godot 4.7 reads `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
  `_USER` and `_PASSWORD` from the environment; the user must create the
  release keystore outside the repo.
- The export warns `No project icon specified` (`application/config/icon`
  is unset; every `launcher_icons/*` in `export_presets.cfg` is empty).

Before starting: `git status --short` must be clean under `godot/` (the user
may leave device tuning uncommitted — never stash or revert it). If the A55
is back on `adb`, offer the M11a and M11b device passes first
(`VERIFY-ME.md` §M11a, 16 checks + Q3; §M11b, 10 checks). The A55 was
absent again on 2026-09-26 (only an emulator was attached).

Carried from the M6 exit into M11c:
- If a mid-play mute is ever ported (`btn-tilt-sound` → `toggleMute`, `TiltGame.ts:1441`),
  M6 R6's silent-loop mute becomes reachable — add a device check for it.
- Re-bake the music only if `TiltAudio.ts:82-479` changes (`node tools/bake-audio/bake_music.mjs`,
  then `--import`); update `edit/loop_end` if the frame count changes.
- M11c owns the device pass: M2.5, M3, M4, M5, M6, M7, M8, M8.5, M9, M10, the
  scale split, M11a and M11b are all pending in `VERIFY-ME.md`; M11c also owns
  `TODO(M11c)` at `entity_layer.gd:253`, `handling_preview.gd:16` (glow),
  `tilt_input.gd:113` (iOS export) and `entrance_cinematic.gd`'s ship glow
  (R3, the fourth `TODO(M11c)` site).
