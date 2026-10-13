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
  rewarded ads (MVP R3 is unapproved), mediation, iOS, Telemetry ad events (AdMob reports
  impressions; the analytics spec §7 keeps ad revenue out).
- The facade follows Telemetry's shape: `Ads` autoload (`src/core/ads.gd`), a null
  `AdsBackend` for desktop, headless and tests, and `AndroidAdsBackend`, the only file that
  names the plugin. No sim class calls `Ads`; GameRoot does.

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
- **Pacing numbers** (20 s, 3 runs, 180 s) are my calls under MVP R1; retune from AdMob's
  sessions and the closed test's retention.
- Seen on the emulator: on the first launch, UMP's first log line came ~73 s after Godot's
  (11:22:40 → 11:23:53). Cause not looked into (the emulator runs the arm64 build by
  translation); check the gap in the A55's logcat.
