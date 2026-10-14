# In-game ads — AdMob interstitials at the Run over, with UMP consent

Branch `feat/in-game-ads` (from `main` at `ebd7301`). Request (user, 2026-10-13): "We need to
implement in-game ads - create a plan and push through with the plan. Check resources whenever
needed - you have full autonomy". The monetization ruling is MVP R1
(`docs/superpowers/plans/2026-09-29-mvp-roadmap.md`): "AdMob interstitials on the Run over only,
capped (not after very short runs; at most one per 2–3 deaths); no banners during play", plus
Google's UMP consent message for EEA and UK users. The ₱15 "Remove ads" purchase in the same
ruling is its own roadmap item (Play Billing) and is not built here.

## Sources checked (2026-10-13)

- AdMob Android interstitial and privacy (UMP) guides, developers.google.com/admob/android.
  Interstitials belong at natural pauses; loaded ads expire after an hour; consent info is
  requested at every launch; when UMP says privacy options are required, the app must show a
  visible entry point that opens `showPrivacyOptionsForm`.
- Google Maven: `com.google.android.gms:play-services-ads` latest 25.5.0 (minSdk 24, does not
  pull UMP); `com.google.android.ump:user-messaging-platform` latest 4.0.0. The v24→v25 breaking
  changes are in mediation adapters and banners, not `InterstitialAd`.
- Godot 4.7.2 `GodotPlugin.java`: `emitSignal` posts to the render thread
  (`godot.runOnRenderThread(() -> nativeEmitSignal(...))`), so plugin callbacks on the UI thread
  may emit. `org.godotengine:godot:4.7.2.stable` is on Maven Central.
- Godot plugins considered and not used (see ADS R1): Poing Studios `godot-admob-plugin` 5.1.0
  and godot-sdk-integrations `godot-admob` 7.0.

## Ruling ADS R1 — the SDK and our own small plugin (my call, standing "always proceed")

- **Our own Android v2 plugin, `PerilAds`** (Java, ~250 lines): source in `android/peril-ads/`
  at the repo root (outside `godot/`, so Godot never imports it), built by
  `tools/build_ads_plugin.sh` with the Godot template's Gradle wrapper (8.11.1, AGP 8.6.1),
  output `godot/addons/peril_ads/bin/peril-ads-{debug,release}.aar`, committed like
  `godot/bin/libperil.*`.
- **SDKs:** the Google Mobile Ads SDK `play-services-ads:25.5.0` (Google now calls it "Legacy"
  next to its Next-Gen SDK; it is the documented, maintained one) and UMP
  `user-messaging-platform:4.0.0`. The export plugin adds both to the gradle build
  (`_get_android_dependencies`); the AAR compiles against them `compileOnly`.
- **Export plugin** `godot/addons/peril_ads/` (`plugin.cfg`, `peril_ads_plugin.gd`): the AAR,
  the two dependencies, and the manifest's `com.google.android.gms.ads.APPLICATION_ID`.
- **Why not a third-party plugin:** Poing 5.1.0 is 583 files (C#, samples, an editor manager),
  downloads binaries when the editor starts and patches `android/build/build.gradle` at export;
  godot-sdk-integrations 7.0 is a 1,544-line untyped node with no UMP privacy-options form (a
  Google requirement) whose export config instantiates every scene to find its node. We need
  one interstitial and consent.
- **IDs live in project settings** (`AdsConfig`, `src/core/ads_config.gd`), read by the game and
  the export plugin alike: `peril/ads/android_app_id`, `peril/ads/android_interstitial_id`.
  Unset, they are Google's test IDs (sample app `ca-app-pub-3940256099942544~3347511713`, test
  interstitial `ca-app-pub-3940256099942544/1033173712`), which serve only test ads. The user
  puts the real IDs in `project.godot` once the AdMob app exists (`VERIFY-ME.md` §ADS).
- `permissions/internet` and `permissions/access_network_state` go on in the preset (the SDK's
  manifest would merge them in anyway; the preset says so plainly). The SDK also merges
  `com.google.android.gms.permission.AD_ID`.

## Ruling ADS R2 — one ad break, and its pacing (MVP R1)

- **The break:** leaving the Run over by **Retry** (PLAY AGAIN, or R/Space on desktop) or
  **Menu**. The ad shows first; its action runs when the ad closes. Pause's Restart and Quit to
  menu, and the Armory from the Run over, are not breaks. Never at death, during play, at launch
  or on resume; no banners, rewarded or app-open ads.
- **An ad shows only when all hold** (`AdPacing`, `src/core/ad_pacing.gd`):
  - the run that just ended was not the player's first run ever (`RunController.is_first_run`);
  - it lasted at least `MIN_RUN_SECONDS` = 20 s ("not after very short runs");
  - at least `RUNS_PER_AD` = 3 runs ended since the last ad, or since launch ("at most one per
    2–3 deaths");
  - at least `MIN_SECONDS_BETWEEN_ADS` = 180 s since the last ad, or since launch;
  - consent allows ads (`canRequestAds`) and an ad is already loaded. A break never waits for a
    load: no ad ready, no ad.
- **Loading:** one interstitial is preloaded after consent, after each ad closes, and at each run
  end when none is loaded or loading (a failed load retries at the next run end, no timers). The
  plugin drops an ad older than 55 minutes (they expire at an hour) and reports it as not shown.
- **Safety:** if the ad has not opened `OPEN_TIMEOUT_SECONDS` = 4 s after `show`, the action
  runs anyway; whichever comes first (close, failure, timeout) runs it, exactly once. A second
  tap while an ad is opening is dropped (the first action still runs).
- **Sound:** the Master bus is muted while an ad is up and restored to its previous state after.
- **Test aid:** `peril/ads/every_break=true` skips the pacing (consent and a loaded ad are still
  required), for checking on a device. Default false; never commit it on.
- **Frame cost:** no per-frame code (no `_process`); the watchdog is one `SceneTreeTimer`.

## Ruling ADS R3 — consent and privacy

- **UMP at every launch, after the first frame** (`Ads.start()`, deferred from
  `GameRoot._ready`, once per process): request consent info → load and show the form if
  required (EEA, UK, Switzerland) → if `canRequestAds`, initialize the Mobile Ads SDK once (on a
  background thread, as Google's sample does) → preload an interstitial. If the update fails
  (offline), the previous session's `canRequestAds` decides.
- **Settings → Data → "Ad privacy" · Manage** appears only when UMP reports privacy options as
  required; it opens the privacy options form, after which the consent state is read again.
- **Request configuration:** maximum ad content rating **T** (the store plan targets 13+,
  roadmap Week 3); child-directed treatment left unspecified.
- **Test device:** `peril/ads/test_device_hashed_id` (UMP debug device and the SDK's test device;
  read the hash from logcat) and `peril/ads/debug_geography` (UMP's int: 1 EEA, 2 not EEA) force
  the form on the A55 in the Philippines. Both are blank/0 by default.
- The analytics opt-out ("Share anonymous usage data") stays separate from ad consent.

## Ruling ADS R4 — scope

- Not built: the Remove ads purchase (next roadmap item; it will switch the break off), banners,
  rewarded ads (MVP R3 is unapproved; the user asked for one on the Run over, ADS R6), mediation, iOS, Telemetry ad events (AdMob reports
  impressions; the analytics spec §7 keeps ad revenue out).
- The facade follows Telemetry's shape: `Ads` autoload (`src/core/ads.gd`), a null
  `AdsBackend` for desktop, headless and tests, and `AndroidAdsBackend`, the only file that
  names the plugin. No sim class calls `Ads`; GameRoot does.

## Ruling ADS R5 — pacing by games or play time (user, 2026-10-14)

User: "Can we run this after every 5-10 games at random or total ingame time e.g. actually
playing a mode". Replaces R2's 3 runs and 180 wall-clock seconds; the rest of R2 stands.
- **Due when either holds**, whichever comes first: `games_since_ad` ≥ a gap drawn at random
  from `MIN_GAMES_PER_AD` = 5 to `MAX_GAMES_PER_AD` = 10 (drawn again after each ad), or
  `play_seconds_since_ad` ≥ `PLAY_SECONDS_PER_AD` = 300 (run time from `GameStats.survival_time`,
  not menus). My call on the 5 minutes: about 7 runs of 40 s.
- **Kept from R2/MVP R1:** never after the player's first run ever, never right after a run
  under 20 s (the ad waits for the next longer run), consent and a loaded ad required.
- **A game** is a run that reaches the Run over; Pause's Restart and Quit count neither a game
  nor its time (they are not breaks either).
- **Saved across launches** (my call): `user://peril_point_ads.json` holds the two counts and the
  drawn gap (`Ads.SAVE_PATH`, written through `SaveStore` at each run end and each opened ad).
  Without it, players whose sessions are 3-4 games would never see an ad.

## Ruling ADS R6 — "Watch ad · 3× points" on the Run over (user, 2026-10-14)

User: "during game over screen, have a watch ads button for 3x the coins". The game's currency is
points ("Points earned"), so the button says points.
- **The offer:** a `WatchAdButton` ("Watch ad · 3× points", play glyph, Armory's Equip style)
  under the Run over's Points earned row. Shown while a rewarded ad is loaded, consent allows
  ads, and the run credited points it has not yet multiplied (`RunController.can_claim_reward`).
  Greyed while its ad is on its way; gone once claimed; back when a new ad loads if the player
  closed the last one early. Any run counts, the first one too (it is opt-in).
- **The reward:** the run's points become `GameRoot.AD_REWARD_MULTIPLIER` = 3 times what it
  credited (`points_credited_this_run`: payout, coins, milestones), once a run. The extra 2× is
  credited through `ProgressionManager.add_points_bonus`, which skips the Points Multiplier (the
  run's points already carry it). The earned figure counts up from the old total.
- **The ad:** Google's rewarded format (`PerilAds.loadRewarded`/`showRewarded`; test unit
  `ca-app-pub-3940256099942544/5224354917`; real one in `peril/ads/android_rewarded_id`).
  Preloaded with the interstitial after consent, after each ad and at each run end. Same mute,
  4 s watchdog and one-ad-at-a-time rule as the break. The reward is granted on Google's
  `onUserEarnedReward` (sent before the close), even if the watchdog had already let the game go
  on. A rewarded view resets the interstitial pacing, so Retry right after it shows none.
- **Retry while an ad is on its way** is ignored (HudController), so the sheet never hides
  under a dropped tap.

## Ruling ADS R7 — dearer Armory, so the 3× ad pays (user, 2026-10-14)

User: "make the weapon upgrades more expensive to incentive clicking the ads as well as the
ships, arena and boosts". My call on how much: **every Armory price doubles**, one constant,
`ProgressionManager.PRICE_SCALE` = 2, applied where prices are read: `get_perk_cost` (weapon
ranks and keystones), the five boost ladder getters, and every ship, enemy skin and arena theme
in the catalogs (`_init`). The tables keep their ECON R2 / TS figures, so parity tests still
check them and a retune is one number. The Armory's keystone cards read the price through
`get_perk_cost` (they read `Tuning.KEYSTONE_COSTS` directly before).
- **Why 2×:** with the 3× ad on every run a player progresses 1.5× as fast as before ADS R7;
  without ads, half as fast. The plan model (armory-economy plan, mid player ≈970 points a run)
  put "everything" at ≈115 mid runs before KEY R1/THEME R1; now ≈230 without ads, ≈77 with.
- **Unchanged:** run payout, coin value, milestone rewards, the starting 500 points (still one
  rank-1 perk at 500), the removed-keystone refund (ECON R4's own table). Owned items stay owned.

## Ruling ADS R8 — weapon upgrades at 4× (user, 2026-10-14)

User, after seeing 0.1.18's Armory: "The upgrades still seem cheap". My call: **weapon ranks and
keystones** go to `ProgressionManager.UPGRADE_PRICE_SCALE` = 4 times their table figure (ranks
1,000 / 1,600 / 2,600 / 4,000 / 6,400; keystones 10,000-20,000); ships, arena and boosts stay at
R7's 2× (the user named upgrades). With the 3× ad a mid player (≈970 points a run, ≈2,900 with
the ad) buys a first rank in about one plain run and a keystone in 3-7 ad runs. Retune: one
number.

## Ruling ADS R9 — choosing the 3× ad resets the count (user, 2026-10-14)

User: "for ads, if they manually select the 3x points to view ads, reset the count". ADS R6
reset the interstitial pacing when the rewarded ad *opened*. Now `Ads.show_rewarded` resets it
(both counts, a new 5-10 gap drawn, saved) at the tap, before the ad opens, so the reset holds
even when the ad then fails to show or never opens; the rewarded ad's opening only stands the
watchdog down (one gap drawn per choice). A tap while no rewarded ad is ready changes nothing
(the button is hidden then anyway). Interstitials still reset the pacing when they open. Built
on `feat/dash-and-abilities` (the branch in hand, which holds `feat/in-game-ads`).

## Ruling ADS R10 — a better-looking 3× offer (user, 2026-10-14)

User: "also make it more appealing to look at". The ion `EquipButton` strip with a dim play
triangle read as one more plain action beside Retry. My calls: the offer takes the points'
flare — a new `RewardButton` theme variation (flare edge on a 12% flare wash, 24% pressed) — and
a row of a solid flare "3×" badge (void text, `GameRoot.AD_REWARD_MULTIPLIER`), "Watch ad", and
the payoff: what "Points earned" becomes if the reward is earned (`+3,822` beside `+1,274`), in
the PointsText flare. A warm-white glint (22%, soft-edged, leaning) sweeps across it in 0.8 s,
then rests 2.2 s, looping; it runs only while the offer can be tapped. While its ad is on its
way the row dims to 45% and reads "Opening ad…". The old text stays as its tooltip. Same height
(touch target 48), so the sheet's layout checks are unchanged. Cost: the glint is drawn once and
moved by a tween, ~1.2 µs a frame, and only on the Run over.

## Rulings ADS R11-R14 — Copilot's PR #15 review (my calls, 2026-10-14)

User: "copilot left some comments on the pervious prs. take a look at those comments and fix if
needed". All four held on `staging` at `507e180`; triage in
`2026-10-14-copilot-pr-comment-triage-12-15.md`. Built on `review/copilot-pr-12-15`.
- **R11 — consent change drops loaded ads.** Closing the privacy options form re-reports consent,
  but the interstitial and rewarded ad held from before were still shown later, though they were
  requested under the old answer. Now the plugin's form callback drops both held ads and any
  load in flight (`consentGeneration`: a load that lands after a newer form close is ignored),
  and `Ads._on_consent_finished` clears the loaded and loading flags, then loads again only if the
  new answer allows ads. A close with no change costs one reload; UMP gives no cheap "did it
  change" check. AARs rebuilt (`tools/build_ads_plugin.sh`).
- **R12 — an ad stays out until its own close.** The watchdog ran the action at 4 s, but a late
  close or failure from that ad then ran `_finish_break` for whatever break came next. Now
  `Ads._showing` (NONE / INTERSTITIAL / REWARDED) holds from `show` until that ad's own close or
  failure, past the watchdog; no break or rewarded offer shows another ad meanwhile (the break
  runs its action at once), and a callback of the other kind, or with nothing out, does nothing.
  The backend has no per-show id, so one ad at a time is what keeps callbacks matched. Risk: an
  SDK that never sends a close or failure would hold ads off for the session; Google's callback
  contract sends one of them.
- **R13 — a late reward pays its own run.** The rewarded `on_reward` called `claim_reward` on the
  live `RunController`: after the watchdog let Retry start a new run, a late payout was lost (the
  new run has nothing credited) or landed on the next run. Now `RunController.run_number` counts
  runs, and GameRoot binds the run and its credited points at the tap; `claim_reward_for` claims
  normally on that run, else banks `credited × (multiplier − 1)` as a bonus and leaves the new
  run's claim alone. Once only: `Ads` clears `on_reward` after one call.
- **R14 — Retry keeps the sheet up while its ad opens.** `_on_restart_pressed` hid the Run over
  before `restart_run` started the break, so an interstitial slow to open (up to 4 s) left a
  blank arena. The sheet now stays; `_on_phase_changed` hides it when the run restarts (as it
  already did for the keyboard Retry).

Cost: none per frame — all four run on ad callbacks, a consent change, or a Retry tap.

## Tasks

- [x] 1. Plan (this file); branch. Commit.
- [x] 2. `android/peril-ads/` Java plugin + `tools/build_ads_plugin.sh`; both AARs built and
      committed under `godot/addons/peril_ads/bin/`.
- [x] 3. Export plugin (`godot/addons/peril_ads/`), enabled in `project.godot`; preset
      internet + network state. Check an exported APK's manifest: APPLICATION_ID, the
      `org.godotengine.plugin.v2.PerilAds` meta-data, INTERNET, and the SDK classes in the dex.
      *(Done 2026-10-13: an A55-key export built in 73 s. Manifest: APPLICATION_ID = the test
      app ID, the v2 meta-data, INTERNET, ACCESS_NETWORK_STATE, `gms.permission.AD_ID`, plus the
      SDK's ACCESS_ADSERVICES_{AD_ID,ATTRIBUTION,TOPICS}, WAKE_LOCK, FOREGROUND_SERVICE. The dex
      holds PerilAdsPlugin, MobileAds, InterstitialAd and UserMessagingPlatform. APK 99.2 MB vs
      0.1.10's 82.3 MB: dex 5.1 → 14.4 MB (the SDK, with Kotlin and coroutines), the rest is
      HTP's clips. minSdk stays 29, as before.)*
- [x] 4. `AdsConfig`, `AdPacing`, `AdsBackend`, `AndroidAdsBackend`, `Ads` autoload;
      `tests/recording_ads_backend.gd`, `tests/test_ads.gd`.
- [x] 5. GameRoot: the break on Retry/Menu from the Run over, `Ads.note_run_end` beside
      `Telemetry.run_end`, `Ads.start()`; Settings "Ad privacy" row. Tests in
      `test_ads.gd` (21) and `test_ad_break.gd` (8: Retry and Menu wait for the ad, a double
      tap restarts once, Pause's Restart/Quit are immediate, no ad means no wait, the Settings
      row appears when consent asks and calls the form). The Reset card's button styling moved
      into `TiltMenu._card_button`, shared with Manage.
- [x] 6. Full suite, gdformat, gdlint, headless SCRIPT ERROR count. *(2026-10-13: `OK: 70/70
      scripts collected, all tests passed, nothing leaked` (924 tests, 20,512 asserts; `main` is
      895); gdformat 131 files unchanged; gdlint clean; headless `--quit-after 240` SCRIPT ERROR
      0. Two leaks found on the way, both mine, both fixed: (1) the watchdog bound its
      SceneTreeTimer into the timer's own signal, a RefCounted cycle; it binds a serial number
      now. (2) A static `AndroidAdsBackend.create()` that called `AndroidAdsBackend.new()`, run
      from the autoload, kept every script alive at exit (306 ObjectDB instances, GUT's runner
      included); bisected over worktrees: the autoload with an empty `_ready` was clean, the
      factory call alone leaked. `Ads._ready` builds the backend itself now.)*
- [x] 7. Device. *(2026-10-13: the A55 was locked with a PIN (`deviceLocked=1`), so the
      checks ran on the emulator (Pixel_10, Play Store image, a test device by default) with
      debug APKs. Test build (`every_break`, `debug_geography=1`, uncommitted, restored after the
      export): the UMP form over the first-launch guide; Consent → `can_request_ads=true
      privacy_options_required=true`; Settings showed Ad privacy · Manage; Manage opened the
      privacy options form and Do not consent re-reported `can_request_ads=true`; Retry and Menu
      each showed Google's interstitial test ad (`AdActivity` resumed) and, after ✕, the cold
      open / the menu. Default build, fresh save: no form, `privacy_options_required=false`, and
      a 3 s first run retried with no ad. Then 0.1.14 (code 15, A55 key, 95 MB) was installed on
      the locked A55 over 0.1.13, data kept; not launched. Frame time not measured on a device:
      the game adds no per-frame code; the SDK's own threads are unmeasured (§ADS Part A).)*
- [x] 8. Docs: `HANDOFF.md`, `VERIFY-ME.md` §ADS (Part A: the A55 checks; Part B: the user's
      AdMob and Play Console steps), the roadmap's Week 2 ticks, `tools/README.md`.
- [x] 10. ADS R5: `AdPacing` by games or play time, saved; `Ads.clock` removed (no wall
      clock left). *(Done 2026-10-14: 70/70 scripts, nothing leaked; gdformat, gdlint clean.)*
- [x] 11. Rewarded ad on the Run over: "Watch ad · 3× points" (user, 2026-10-14). Ruling ADS R6.
      *(Done 2026-10-14: plugin AARs rebuilt; 70/70 scripts, nothing leaked; gdformat, gdlint
      clean. Device check pending, VERIFY-ME §ADS Part A.)*
- [x] 12. Raise prices of weapon upgrades, ships, arenas and boosts (user, 2026-10-14). Ruling
      ADS R7. *(Done 2026-10-14: 32 price assertions in four test files now read the table figure
      times `PRICE_SCALE`; parity tests compare the TS figure times it. 70/70 scripts, nothing
      leaked; every Armory layout check passed with the longer prices. The weapon header's
      invested figure sums the scaled prices, default ranks included, as it did before.)*
- [x] 13. ADS R8: `UPGRADE_PRICE_SCALE` = 4 in `get_perk_cost`. *(Done 2026-10-14: the upgrade
      price tests read it; 70/70 scripts, nothing leaked; gdformat, gdlint clean.)*
- [x] 14. Push, PR into `staging`, merge (user, 2026-10-14: "commit push create pr and merge to
      staging for now"). `main` waits for task 9.
- [x] 15. ADS R9: the tap on "Watch ad" resets the pacing (user, 2026-10-14). *(Done
      2026-10-14 on `feat/dash-and-abilities`: three tests in `test_ads.gd` — reset at the tap
      and saved even when the ad fails to show, one gap drawn per choice, nothing when no ad is
      ready.)*
- [x] 16. ADS R10: the offer's new look (user, 2026-10-14). *(Done 2026-10-14: two tests in
      `test_run_over_sheet.gd`; `bench/shot_run_over.gd` takes `REWARD=1` / `REWARD=wait`. Suite
      1017/1017, 75/75 scripts, nothing leaked; gdformat, gdlint clean; 0 SCRIPT ERROR
      headless.)*
- [x] 17. ADS R11-R14 from Copilot's PR #15 review. *(Done 2026-10-14 on
      `review/copilot-pr-12-15`: six tests (`test_ads.gd` 4, `test_ad_break.gd` 2), each failing
      with its fix removed; AARs rebuilt. Suite 1032/1032, 75/75 scripts, nothing leaked;
      gdformat, gdlint clean; 0 SCRIPT ERROR in the suite and a 600-frame headless boot.
      `bench_sim` unchanged within noise (swarm.update 25.5 vs 24.7 µs on `staging`). Not on the
      A55 yet: the next build is code 26; VERIFY-ME §ADS has the R11/R14 rows.)*
- [ ] 9. The user's A55 pass (§ADS Part A) and AdMob setup (Part B); merge. *(User: "rebuild
      it". Rebuilt as 0.1.15 (code 16, same code as 0.1.14), installed on the unlocked A55
      2026-10-13 22:10 with data kept, launched: consent in ~2 s, `can_request_ads=true
      privacy_options_required=false`, no load failure; menu frame time mean 16.66 ms, p95 25.1.
      The rest of Part A is the user's. User: "rebuild it i do not see the consent". Ruling,
      mine: no change to who sees the form. UMP shows it only where GDPR applies (EEA/UK/CH);
      PH gets none, as ADS R3 intends. To show it on the A55, its hash is committed as
      `peril/ads/test_device_hashed_id` and 0.1.16 (code 17) was built with
      `ads/debug_geography=1` uncommitted; the EEA form showed on the A55 2026-10-14 00:07 and a
      choice gave `can_request_ads=true privacy_options_required=true`.)*

## Open

- **Package name.** The preset builds `com.jtg.perilpoint`; the A55's Play Store copy is
  `ph.newzenith.perilpoint`. The AdMob app must be registered under the package that ships.
- **APK size.** 82.3 MB (0.1.10) → 95 MB (0.1.14 and 0.1.15, A55 key): the SDK, Kotlin and coroutines add
  ~9 MB of dex, the rest is HTP's clips. Godot's gradle build does not minify; R8 could shrink
  the dex, but needs keep rules for Godot and the plugin. Not done.
- **Next feature:** the ₱15 Remove ads purchase (Play Billing, roadmap Week 2). It should make
  `Ads.is_break_due()` false for a buyer and skip the load; consent can still run.
- **Pacing numbers** (R5: 20 s, a 5-10-game gap drawn at random, 300 s of play) are my calls
  under MVP R1 and the user's R5; retune from AdMob's
  sessions and the closed test's retention.
- Seen on the emulator: on the first launch, UMP's first log line came ~73 s after Godot's
  (11:22:40 → 11:23:53). Cause not looked into (the emulator runs the arm64 build by
  translation); check the gap in the A55's logcat.
