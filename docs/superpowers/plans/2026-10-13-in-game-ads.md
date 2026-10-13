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
- [ ] 2. `android/peril-ads/` Java plugin + `tools/build_ads_plugin.sh`; both AARs built and
      committed under `godot/addons/peril_ads/bin/`.
- [ ] 3. Export plugin (`godot/addons/peril_ads/`), enabled in `project.godot`; preset
      internet + network state. Check an exported APK's manifest: APPLICATION_ID, the
      `org.godotengine.plugin.v2.PerilAds` meta-data, INTERNET, and the SDK classes in the dex.
- [ ] 4. `AdsConfig`, `AdPacing`, `AdsBackend`, `AndroidAdsBackend`, `Ads` autoload;
      `tests/recording_ads_backend.gd`, `tests/test_ads.gd`.
- [ ] 5. GameRoot: the break on Retry/Menu from the Run over, `Ads.note_run_end` beside
      `Telemetry.run_end`, `Ads.start()`; Settings "Ad privacy" row. Tests in
      `test_ads.gd` / `test_main_scene.gd` / `test_tilt_menu.gd`.
- [ ] 6. Full suite, gdformat, gdlint, headless SCRIPT ERROR count.
- [ ] 7. A55: 0.1.14 (code 15) with the A55 key; a temporary test build (every_break, debug
      EEA) shows the consent form and a test interstitial at Menu/Retry, the action runs after
      the close, sound returns; logcat clean. Frame time in a run (`tools/frametime.sh`).
- [ ] 8. Docs: `HANDOFF.md`, `VERIFY-ME.md` §ADS (the user's AdMob/Play Console steps), the
      roadmap's Week 2 ticks. Commit.

## Open

- (filled in as the work goes)
