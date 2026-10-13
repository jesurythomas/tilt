// PerilAdsPlugin.java
// The game's AdMob plugin (rulings ADS R1, R6, docs/superpowers/plans/2026-10-13-in-game-ads.md):
// UMP consent, one interstitial, one rewarded ad, and the privacy options form. GDScript reaches it as the
// "PerilAds" singleton, only through godot/src/core/android_ads_backend.gd.
//
// Threads: Godot calls the @UsedByGodot methods on its render thread; every SDK call and every
// field below lives on the UI thread (runOnUiThread). emitSignal posts back to the render thread.
package com.jtg.perilpoint.ads;

import android.app.Activity;
import android.os.SystemClock;
import android.util.Log;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.RequestConfiguration;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.ump.ConsentDebugSettings;
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.FormError;
import com.google.android.ump.UserMessagingPlatform;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

public class PerilAdsPlugin extends GodotPlugin {
	private static final String TAG = "PerilAds";

	/** Google: a loaded full-screen ad expires after an hour; drop it a little before. */
	private static final long AD_MAX_AGE_MS = 55L * 60L * 1000L;

	private static final SignalInfo CONSENT_FINISHED =
			new SignalInfo("consent_finished", Boolean.class, Boolean.class, String.class);
	private static final SignalInfo INTERSTITIAL_LOADED = new SignalInfo("interstitial_loaded");
	private static final SignalInfo INTERSTITIAL_FAILED_TO_LOAD =
			new SignalInfo("interstitial_failed_to_load", Integer.class, String.class);
	private static final SignalInfo INTERSTITIAL_OPENED = new SignalInfo("interstitial_opened");
	private static final SignalInfo INTERSTITIAL_CLOSED = new SignalInfo("interstitial_closed");
	private static final SignalInfo INTERSTITIAL_FAILED_TO_SHOW =
			new SignalInfo("interstitial_failed_to_show", Integer.class, String.class);
	private static final SignalInfo REWARDED_LOADED = new SignalInfo("rewarded_loaded");
	private static final SignalInfo REWARDED_FAILED_TO_LOAD =
			new SignalInfo("rewarded_failed_to_load", Integer.class, String.class);
	private static final SignalInfo REWARDED_OPENED = new SignalInfo("rewarded_opened");
	private static final SignalInfo REWARDED_EARNED = new SignalInfo("rewarded_earned");
	private static final SignalInfo REWARDED_CLOSED = new SignalInfo("rewarded_closed");
	private static final SignalInfo REWARDED_FAILED_TO_SHOW =
			new SignalInfo("rewarded_failed_to_show", Integer.class, String.class);

	private ConsentInformation consentInformation;
	private boolean isMobileAdsStarted;
	private InterstitialAd interstitial;
	private long interstitialLoadedAt;
	private boolean isLoading;
	private RewardedAd rewarded;
	private long rewardedLoadedAt;
	private boolean isRewardedLoading;
	private String testDeviceHashedId = "";

	public PerilAdsPlugin(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "PerilAds";
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(CONSENT_FINISHED);
		signals.add(INTERSTITIAL_LOADED);
		signals.add(INTERSTITIAL_FAILED_TO_LOAD);
		signals.add(INTERSTITIAL_OPENED);
		signals.add(INTERSTITIAL_CLOSED);
		signals.add(INTERSTITIAL_FAILED_TO_SHOW);
		signals.add(REWARDED_LOADED);
		signals.add(REWARDED_FAILED_TO_LOAD);
		signals.add(REWARDED_OPENED);
		signals.add(REWARDED_EARNED);
		signals.add(REWARDED_CLOSED);
		signals.add(REWARDED_FAILED_TO_SHOW);
		return signals;
	}

	/**
	 * Asks UMP for this launch's consent state and shows the consent form when it is required,
	 * then starts the Mobile Ads SDK if ads may be requested. Emits consent_finished(can_request_ads,
	 * privacy_options_required, error). A blank id and geography 0 leave UMP's debug settings off.
	 */
	@UsedByGodot
	public void gatherConsent(String testDeviceHashedId, int debugGeography) {
		final Activity activity = getActivity();
		if (activity == null) {
			emitSignal(CONSENT_FINISHED.getName(), false, false, "no activity");
			return;
		}
		activity.runOnUiThread(() -> {
			this.testDeviceHashedId = testDeviceHashedId;
			ConsentRequestParameters.Builder params = new ConsentRequestParameters.Builder();
			if (!testDeviceHashedId.isEmpty() || debugGeography != 0) {
				ConsentDebugSettings.Builder debug = new ConsentDebugSettings.Builder(activity);
				if (!testDeviceHashedId.isEmpty()) {
					debug.addTestDeviceHashedId(testDeviceHashedId);
				}
				if (debugGeography != 0) {
					debug.setDebugGeography(debugGeography);
				}
				params.setConsentDebugSettings(debug.build());
			}
			consentInformation = UserMessagingPlatform.getConsentInformation(activity);
			consentInformation.requestConsentInfoUpdate(
					activity,
					params.build(),
					() -> UserMessagingPlatform.loadAndShowConsentFormIfRequired(
							activity, formError -> finishConsent(activity, describe(formError))),
					requestError -> finishConsent(activity, describe(requestError)));
		});
	}

	/** Shows UMP's privacy options form (Settings → Ad privacy), then re-reports consent. */
	@UsedByGodot
	public void showPrivacyOptions() {
		final Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		activity.runOnUiThread(() -> {
			if (consentInformation == null) {
				return;
			}
			UserMessagingPlatform.showPrivacyOptionsForm(
					activity, formError -> finishConsent(activity, describe(formError)));
		});
	}

	/** Loads one interstitial unless one is loading or a fresh one is already held. */
	@UsedByGodot
	public void loadInterstitial(String adUnitId) {
		final Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		activity.runOnUiThread(() -> {
			if (isLoading) {
				return;
			}
			if (interstitial != null && !isStale(interstitialLoadedAt)) {
				emitSignal(INTERSTITIAL_LOADED.getName());
				return;
			}
			interstitial = null;
			isLoading = true;
			InterstitialAd.load(activity, adUnitId, new AdRequest.Builder().build(),
					new InterstitialAdLoadCallback() {
						@Override
						public void onAdLoaded(InterstitialAd ad) {
							isLoading = false;
							interstitial = ad;
							interstitialLoadedAt = SystemClock.elapsedRealtime();
							emitSignal(INTERSTITIAL_LOADED.getName());
						}

						@Override
						public void onAdFailedToLoad(LoadAdError error) {
							isLoading = false;
							interstitial = null;
							Log.w(TAG, "interstitial failed to load: " + error);
							emitSignal(INTERSTITIAL_FAILED_TO_LOAD.getName(), error.getCode(),
									error.getMessage());
						}
					});
		});
	}

	/**
	 * Shows the held interstitial. Emits interstitial_opened then interstitial_closed, or
	 * interstitial_failed_to_show (also when none is held or it went stale).
	 */
	@UsedByGodot
	public void showInterstitial() {
		final Activity activity = getActivity();
		if (activity == null) {
			emitSignal(INTERSTITIAL_FAILED_TO_SHOW.getName(), -1, "no activity");
			return;
		}
		activity.runOnUiThread(() -> {
			InterstitialAd ad = interstitial;
			boolean isUsable = ad != null && !isStale(interstitialLoadedAt);
			interstitial = null;
			if (!isUsable) {
				emitSignal(INTERSTITIAL_FAILED_TO_SHOW.getName(), -1,
						ad == null ? "no ad loaded" : "ad expired");
				return;
			}
			ad.setFullScreenContentCallback(new FullScreenContentCallback() {
				@Override
				public void onAdShowedFullScreenContent() {
					emitSignal(INTERSTITIAL_OPENED.getName());
				}

				@Override
				public void onAdDismissedFullScreenContent() {
					emitSignal(INTERSTITIAL_CLOSED.getName());
				}

				@Override
				public void onAdFailedToShowFullScreenContent(AdError error) {
					Log.w(TAG, "interstitial failed to show: " + error);
					emitSignal(INTERSTITIAL_FAILED_TO_SHOW.getName(), error.getCode(),
							error.getMessage());
				}
			});
			ad.show(activity);
		});
	}

	/** Loads one rewarded ad unless one is loading or a fresh one is already held. */
	@UsedByGodot
	public void loadRewarded(String adUnitId) {
		final Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		activity.runOnUiThread(() -> {
			if (isRewardedLoading) {
				return;
			}
			if (rewarded != null && !isStale(rewardedLoadedAt)) {
				emitSignal(REWARDED_LOADED.getName());
				return;
			}
			rewarded = null;
			isRewardedLoading = true;
			RewardedAd.load(activity, adUnitId, new AdRequest.Builder().build(),
					new RewardedAdLoadCallback() {
						@Override
						public void onAdLoaded(RewardedAd ad) {
							isRewardedLoading = false;
							rewarded = ad;
							rewardedLoadedAt = SystemClock.elapsedRealtime();
							emitSignal(REWARDED_LOADED.getName());
						}

						@Override
						public void onAdFailedToLoad(LoadAdError error) {
							isRewardedLoading = false;
							rewarded = null;
							Log.w(TAG, "rewarded failed to load: " + error);
							emitSignal(REWARDED_FAILED_TO_LOAD.getName(), error.getCode(),
									error.getMessage());
						}
					});
		});
	}

	/**
	 * Shows the held rewarded ad. Emits rewarded_opened, rewarded_earned when the player earns
	 * the reward (Google sends it before the close), then rewarded_closed; or
	 * rewarded_failed_to_show (also when none is held or it went stale).
	 */
	@UsedByGodot
	public void showRewarded() {
		final Activity activity = getActivity();
		if (activity == null) {
			emitSignal(REWARDED_FAILED_TO_SHOW.getName(), -1, "no activity");
			return;
		}
		activity.runOnUiThread(() -> {
			RewardedAd ad = rewarded;
			boolean isUsable = ad != null && !isStale(rewardedLoadedAt);
			rewarded = null;
			if (!isUsable) {
				emitSignal(REWARDED_FAILED_TO_SHOW.getName(), -1,
						ad == null ? "no ad loaded" : "ad expired");
				return;
			}
			ad.setFullScreenContentCallback(new FullScreenContentCallback() {
				@Override
				public void onAdShowedFullScreenContent() {
					emitSignal(REWARDED_OPENED.getName());
				}

				@Override
				public void onAdDismissedFullScreenContent() {
					emitSignal(REWARDED_CLOSED.getName());
				}

				@Override
				public void onAdFailedToShowFullScreenContent(AdError error) {
					Log.w(TAG, "rewarded failed to show: " + error);
					emitSignal(REWARDED_FAILED_TO_SHOW.getName(), error.getCode(),
							error.getMessage());
				}
			});
			// The game grants its own reward (3x the run's coins), so the item's amount and type,
			// set on the AdMob unit, are not passed on.
			ad.show(activity, rewardItem -> emitSignal(REWARDED_EARNED.getName()));
		});
	}

	private void finishConsent(Activity activity, String error) {
		boolean canRequestAds = consentInformation.canRequestAds();
		boolean isPrivacyRequired = consentInformation.getPrivacyOptionsRequirementStatus()
				== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED;
		if (!error.isEmpty()) {
			Log.w(TAG, "consent: " + error);
		}
		if (!canRequestAds || isMobileAdsStarted) {
			emitSignal(CONSENT_FINISHED.getName(), canRequestAds, isPrivacyRequired, error);
			return;
		}
		isMobileAdsStarted = true;
		RequestConfiguration.Builder config = new RequestConfiguration.Builder()
				.setMaxAdContentRating(RequestConfiguration.MAX_AD_CONTENT_RATING_T);
		if (!testDeviceHashedId.isEmpty()) {
			config.setTestDeviceIds(Collections.singletonList(testDeviceHashedId));
		}
		MobileAds.setRequestConfiguration(config.build());
		// Google's sample initializes off the UI thread; the callback comes back on the UI thread.
		new Thread(() -> MobileAds.initialize(activity, status -> emitSignal(
				CONSENT_FINISHED.getName(), true, isPrivacyRequired, error))).start();
	}

	private static boolean isStale(long loadedAt) {
		return SystemClock.elapsedRealtime() - loadedAt > AD_MAX_AGE_MS;
	}

	private static String describe(FormError error) {
		return error == null ? "" : error.getErrorCode() + " " + error.getMessage();
	}
}
