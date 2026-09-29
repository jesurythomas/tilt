# MVP roadmap: from shareable builds to a Play Store closed test

Written 2026-09-29 from the user's planning questions. **Nothing here is built yet.** The
game itself is feature-complete (`godot/HANDOFF.md`). This plan covers what an MVP test
on Google Play still needs, and the rulings the user has made so far.

## Where it stands

- **Builds.** Release 0.1.1 (code 2) is on the user's A55. That copy is signed with Godot's
  debug key so it keeps the save (`PERIL_KEYS=~/.android/peril-a55.env`). A Galaxy Tab
  S9 FE (SM-X510, serial `R52WA05819H`) runs the shared APK, signed with the dev key.
  `tools/release.sh` builds both; the shared APK is `godot/build/peril-point-0.1.1.apk`.
- **Tablet measurements (2026-09-29).**
  - Frame times: p50 16.6 ms, 6.8% of frames > 20 ms, one 199 ms hitch
    (`SERIAL=R52WA05819H tools/frametime.sh`).
  - It logs `_texture_2d_update: p_image is empty` twice: on the menu's first frame and on
    the first frame after Play. The A55 does not, and neither does desktop at 2304×1440, so
    it is mobile- and size-specific. Nothing visible is missing. Suspect a large-glyph text
    upload (the wordmark at ui_scale 3.69), unconfirmed.
- **Player feedback so far:** the touch stick (answered by TOUCH R1, shipped in 0.1.1).

## Rulings (user, 2026-09-29)

- **MVP R1 — Monetization.** Ads, plus a **₱15 one-time purchase that removes ads
  permanently**.
  - Plan: AdMob interstitials on the Run over only, capped (not after very short runs; at
    most one per 2–3 deaths); **no banners during play**.
  - Google Play Billing: one non-consumable product, acknowledged after purchase and
    restored on reinstall.
  - Google's UMP consent message for EEA and UK users.
  - A rewarded ad is optional later (see MVP R3).
  - Check Play Console's minimum price for the Philippines. At ₱15 the net is about ₱11
    after the 15% fee and the 12% PH VAT.
- **MVP R2 — Leaderboards.** Recommended: Google Play Games Services, one board per mode,
  submitted at death, with a button on the menu and the Run over. A custom backend is
  the later option (1.5–2 weeks).
- **MVP R3 — Clickable power-ups (proposed, not yet approved).**
  - One HUD slot, stocked with Nuke, Shield or Freeze.
  - About 300–500 points per charge; 1 use per run; chosen before the run.
  - "Watch an ad for a free charge", at most 1–2 per day.
  - The Touch stick must ignore the button's area.
  - Keep leaderboards fair through the per-run cap.
- **MVP R4 — Identity (recommended, needs the user's names).** Rename the modes: "Code Red"
  is Tilt to Live 2's hard mode, and "Gauntlet" echoes *Gauntlet's Revenge*. Examples:
  Survival, Overdrive, Corridor. The store listing must never mention Tilt to Live. On
  Android, Tilt to Live 2: Redonkulous (One Man Left, 2014) still appears on Google Play
  but looks unmaintained; Gauntlet's Revenge may be delisted.

## Tasks

Estimates are working days. Calendar time is dominated by Play Console review and the
**14-day closed test** that new personal developer accounts must run, with at least 12
opted-in testers, before production.

### Week 1 — make a test worth running
- [ ] **Analytics + crashes** (Firebase Analytics + Crashlytics, or GameAnalytics):
  retention on day 1 and 7, session length, runs per session, death cause and time, mode
  choice, Armory purchases. ~1.5 days. **Ruling MVP R6: Firebase** (assistant's pick; the
  user said "just proceed"). Spec: `docs/superpowers/specs/2026-09-29-analytics-crashes-design.md`.
  - [x] Spec written.
  - [ ] Step 1: `Telemetry` facade, `GameStats.killer`, event wiring, Settings toggle, tests.
  - [ ] Step 2: `VERIFY-ME.md` §MVP R6 (user: Firebase project, SHA-1s, `google-services.json`).
  - [ ] Step 3: plugin + Gradle + symbol upload; check events in DebugView on the A55.
  - [ ] Step 4: forced test crash appears symbolicated; remove the debug row.
- [x] **First run.** *(Code-complete 2026-09-29; A55 pass pending, `VERIFY-ME.md` §MVP R5.)*
  New saves already started on Standard. Added: a one-time hint ("Fly into orbs. They fire
  themselves.") and a gentler first run. Ruling MVP R5 (user approved the design in chat):
  a first run is `first_run_done == false and best_score == 0`; the swarm ramp advances at
  0.5× (`EnemySwarm.GENTLE_RAMP_RATE`, to be tuned on the A55); the hint hides on the first
  orb pickup or after ~8 s; `first_run_done` is set at the first death and saved as
  `firstRunDone`; Settings → Reset clears it, so the hint returns. All tagged
  `DIVERGENCE(MVP R5)`.
- [ ] **Android back button and backgrounding.** Resolve the open question in VERIFY-ME
  (M11a Q3): back = pause in a run, back out of sheets. Pause when focus is lost. ~0.5 day.
- [ ] **Haptics** on a nuke, a death and a close call; add a Settings toggle. ~0.5 day.
- [ ] **AAB export + Play App Signing.** Use a real upload key (not the dev key). The
  preset's `gradle_build/export_format` must become AAB. ~0.5 day.
- [ ] **Mode renames (MVP R4)**, once the user picks names. ~0.5 day.
- [ ] **Tablet:** find the empty-image texture error, using a debug build signed with the
  dev key so it installs over the release. Look into the > 20 ms frames. ~1 day.

### Week 2 — monetization and leaderboards
- [ ] **AdMob interstitial** (Godot 4 Android plugin), with the cap in MVP R1. 2–3 days.
- [ ] **Play Billing** "Remove ads · ₱15" plus "Restore purchase" in Settings. 2–3 days.
- [ ] **UMP consent.** ~1 day.
- [ ] **Play Games leaderboards (MVP R2).** 3–5 days, after the app exists in Play Console
  with its signing key registered.
- [ ] *(if approved)* **Clickable power-ups (MVP R3).** 3–5 days; +0.5–1 day for the
  rewarded ad.

### Week 3 — store and the closed test
- [ ] Privacy policy URL, Data safety form, ads declaration, content rating, target
  audience 13+ (Families rules would restrict ads).
- [ ] Icon, feature graphic, screenshots and a short gameplay video.
- [ ] A feedback link in Settings or the Run over (Google Form, email or Discord).
- [ ] Internal testing on the A55 and the tablet, then start the 14-day closed test.

## Revenue model (for reading test data)

Philippine traffic assumptions: interstitial eCPM about ₱80 (range ₱50–150), about 3 ads
per daily player per day, so about ₱7 per daily player per month.

| Target | Daily players | Monthly installs |
|---|---|---|
| ₱10k/month | ~1,400 (600–6,000) | ~10–11k |
| ₱20k/month | ~2,800 | ~20–22k |

These numbers assume day-7 retention of 8–12%. A rewarded ad could nearly double the
revenue per player, and better retention lowers the installs needed. Redo this table with
the closed test's real eCPM and retention.
