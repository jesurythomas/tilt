# Remove ads purchase — the Support the dev banner (IAP R1-R5)

User 2026-10-25: "Does the current game already have support the dev banner? We should add it in
the game over screen. This should allow players to purchase something that removes ads for the
users. Let's have it at 25php." Answer: no — the roadmap's "Play Billing · Remove ads ₱15" item
(MVP R1) was never built. Branch `feat/remove-ads` from `chore/bundle-0.1.26` at `a7db0d9`
(PR #19 with `staging` merged in, so PR #20's gamepad work is included).

## Rulings

- **IAP R1 — the banner (user).** The Run over carries a **Support the dev** banner: a plasma
  heart, "Support the dev" / "REMOVE ADS FOR GOOD", and Play's price in a plasma chip. It sells
  one Google Play **one-time product**, id `remove_ads`, priced **₱25** in Play Console (the
  price lives there, not in code; the chip shows Play's formatted price, so no figure in the
  game can disagree with the store). It shows only on the Run over, only while Play has priced
  the product (a sideloaded `com.jtg.perilpoint` build, no connection, or no product yet: no
  banner). Placement, my call: the foot of the left column, in the achievements' scroll under
  the list. Measured headless at scale 1: the right column has 2 px spare, the left 53 px (new
  best shown) to 103 px under the stats, so a 48 px banner fits there and, inside the scroll,
  never grows the 346 px sheet (the screen is 390 at the reference size). States: OFFERED;
  WAITING ("Opening Google Play…", dimmed, from the tap until Play's sheet answers); PENDING
  (R4); THANKS ("Thank you!" / "ADS REMOVED" with the check, on the sheet the purchase was
  made from only); HIDDEN otherwise. A tap while an ad is on its way buys nothing (as the
  Armory, ADS R14). The roadmap's ₱15 is superseded by the user's ₱25.
- **IAP R2 — what it removes (mine).** Every interstitial: `Ads.is_break_due()` is false for an
  owner and no interstitial loads. The Run over's "Watch ad · 3× points" rewarded ad stays — the
  player chooses it and is paid for it. Consent (UMP) still runs, as the rewarded ad needs it.
- **IAP R3 — ownership (mine).** Play is the truth: the plugin queries purchases at launch and at
  every resume (`onMainResume`; a pending payment can finish while the game is away). An
  answered query that no longer lists `remove_ads` (a refund) gives the ads back; an unanswered
  one (offline) changes nothing. The last answer is saved (`user://peril_point_billing.json`), so
  an offline launch stays ad-free. The plugin acknowledges each purchased, unacknowledged
  purchase (Play refunds after 3 days otherwise) and retries at the next query. No server-side
  verification: there is no game server, and at ₱25 a tampered client only removes its own ads.
- **IAP R4 — pending payments (mine).** Pending purchases are enabled (Billing Library 8+
  requires it; in the Philippines Play offers cash and e-wallet methods that settle later). A
  pending purchase dims the banner to "PAYMENT PENDING" and keeps the ads until Play reports it
  purchased.
- **IAP R5 — no Restore button (mine).** The roadmap listed "Restore purchase" in Settings. Play
  restores a one-time product to the same Google account by itself, and R3 asks at every launch,
  so a reinstall is ad-free on its first launch with a connection. No Settings row.

## Build

- `android/peril-billing/` — Java Godot v2 plugin `PerilBilling` on Play Billing Library
  **9.1.0** (latest on Google Maven, 2026-10-25; Play requires 8+ for updates from 2026-08-31).
  `tools/build_billing_plugin.sh` builds it into `godot/addons/peril_billing/bin/*.aar`
  (committed). The export plugin `godot/addons/peril_billing/` adds the AAR and the library; the
  library's manifest adds `com.android.vending.BILLING`.
- `src/core/billing.gd` (autoload `Billing`), `billing_backend.gd` (null),
  `android_billing_backend.gd` (the only file naming the plugin) — Ads' facade shape.
- `RunOverSheet` (banner, `SupportState`), `HudController.set_support_offer`,
  `GameRoot.support_state / buy_remove_ads`, `Ads` gate, `UiTheme` `SupportButton` + `ICON_HEART`.

## Tasks

- [x] Plugin, export plugin, AARs (built 2026-10-25, compiles against 9.1.0).
- [x] `Billing` autoload, backends, Ads gate (R2, R3, R4).
- [x] Banner on the Run over, wired through HUD and GameRoot (R1).
- [x] Tests: `test_billing.gd` (12), `test_support_banner.gd` (11), recording backend;
      mutation-checked (with the Ads gate removed, one test in each file fails).
- [x] gdformat / gdlint clean; suite 1092/1092, 79/79 scripts, nothing leaked.
- [x] Debug export: BILLING permission and plugin in the manifest; emulator launch: plugin up,
      `connected=false` (Play Store signed out), no banner, no crash.
- [ ] **User:** Play Console product and license testers (VERIFY-ME §IAP Part A). Play shows
      the one-time products page only once a bundle with the BILLING permission is uploaded, so
      the first step is the next `.aab` (code 28) to internal testing.
- [ ] Device pass from the internal-testing install (VERIFY-ME §IAP Part B), with frame time.

## Not built

A Settings row (R5); a purchase on the menu or the Pause sheet; server verification (R3);
other products. Frame cost: no `_process` or `_draw` added — the banner repaints only when
the store's state changes; no device was connected on 2026-10-25 for an A55 check.
