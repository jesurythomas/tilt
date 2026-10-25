// PerilBillingPlugin.java
// The game's Google Play Billing plugin (rulings IAP R1-R4,
// docs/superpowers/plans/2026-10-25-remove-ads-purchase.md): one one-time product, its price,
// the purchase flow, and the player's purchases. GDScript reaches it as the "PerilBilling"
// singleton, only through godot/src/core/android_billing_backend.gd.
//
// Threads: Godot calls the @UsedByGodot methods on its render thread; every BillingClient call and
// every field below lives on the UI thread (runOnUiThread), where the library also calls back.
// emitSignal posts back to the render thread.
package com.jtg.perilpoint.billing;

import android.app.Activity;
import android.util.Log;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class PerilBillingPlugin extends GodotPlugin {
	private static final String TAG = "PerilBilling";

	/** The store answered the connection: ok, the response code and its message. */
	private static final SignalInfo CONNECTED =
			new SignalInfo("connected", Boolean.class, Integer.class, String.class);
	/** A product exists for this app: its id and its price, formatted by Play. */
	private static final SignalInfo PRODUCT_FOUND =
			new SignalInfo("product_found", String.class, String.class);
	/** A product could not be fetched: its id, the response code and its message. */
	private static final SignalInfo PRODUCT_MISSING =
			new SignalInfo("product_missing", String.class, Integer.class, String.class);
	/** One purchase: a product id and Purchase.PurchaseState (1 purchased, 2 pending). */
	private static final SignalInfo PURCHASE_STATE =
			new SignalInfo("purchase_state", String.class, Integer.class);
	/** A purchases query ended; its purchase_state signals came first. ok false: no answer. */
	private static final SignalInfo PURCHASES_QUERIED =
			new SignalInfo("purchases_queried", Boolean.class);
	/** The purchase flow ended without a purchase (cancelled, failed, or would not open). */
	private static final SignalInfo PURCHASE_FAILED =
			new SignalInfo("purchase_failed", Integer.class, String.class);

	private BillingClient client;
	/** Product details by id, kept from queryProduct for the purchase flow. */
	private final Map<String, ProductDetails> details = new HashMap<>();

	public PerilBillingPlugin(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "PerilBilling";
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(CONNECTED);
		signals.add(PRODUCT_FOUND);
		signals.add(PRODUCT_MISSING);
		signals.add(PURCHASE_STATE);
		signals.add(PURCHASES_QUERIED);
		signals.add(PURCHASE_FAILED);
		return signals;
	}

	/** Connects to Play once; emits connected. The client reconnects by itself after that. */
	@UsedByGodot
	public void startConnection() {
		final Activity activity = getActivity();
		if (activity == null) {
			emitSignal(CONNECTED.getName(), false, BillingClient.BillingResponseCode.ERROR, "no activity");
			return;
		}
		activity.runOnUiThread(() -> {
			if (client != null) {
				emitSignal(CONNECTED.getName(), client.isReady(), BillingClient.BillingResponseCode.OK, "");
				return;
			}
			client = BillingClient.newBuilder(activity)
					.setListener(this::onPurchasesUpdated)
					.enablePendingPurchases(
							PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
					.enableAutoServiceReconnection()
					.build();
			client.startConnection(new BillingClientStateListener() {
				@Override
				public void onBillingSetupFinished(BillingResult result) {
					boolean ok = result.getResponseCode() == BillingClient.BillingResponseCode.OK;
					emitSignal(CONNECTED.getName(), ok, result.getResponseCode(), result.getDebugMessage());
				}

				@Override
				public void onBillingServiceDisconnected() {
					// enableAutoServiceReconnection reconnects at the next call.
					Log.i(TAG, "billing service disconnected");
				}
			});
		});
	}

	/** Fetches one one-time product; emits product_found or product_missing. */
	@UsedByGodot
	public void queryProduct(String productId) {
		final Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		activity.runOnUiThread(() -> {
			if (client == null) {
				emitSignal(PRODUCT_MISSING.getName(), productId,
						BillingClient.BillingResponseCode.SERVICE_DISCONNECTED, "not connected");
				return;
			}
			QueryProductDetailsParams params = QueryProductDetailsParams.newBuilder()
					.setProductList(Collections.singletonList(
							QueryProductDetailsParams.Product.newBuilder()
									.setProductId(productId)
									.setProductType(BillingClient.ProductType.INAPP)
									.build()))
					.build();
			client.queryProductDetailsAsync(params, (result, queried) -> {
				for (ProductDetails product : queried.getProductDetailsList()) {
					ProductDetails.OneTimePurchaseOfferDetails offer =
							product.getOneTimePurchaseOfferDetails();
					if (product.getProductId().equals(productId) && offer != null) {
						details.put(productId, product);
						emitSignal(PRODUCT_FOUND.getName(), productId, offer.getFormattedPrice());
						return;
					}
				}
				emitSignal(PRODUCT_MISSING.getName(), productId, result.getResponseCode(),
						result.getDebugMessage());
			});
		});
	}

	/** Opens Play's purchase sheet for a product queryProduct found. */
	@UsedByGodot
	public void purchase(String productId) {
		final Activity activity = getActivity();
		if (activity == null) {
			emitSignal(PURCHASE_FAILED.getName(), BillingClient.BillingResponseCode.ERROR, "no activity");
			return;
		}
		activity.runOnUiThread(() -> {
			ProductDetails product = details.get(productId);
			if (client == null || product == null) {
				emitSignal(PURCHASE_FAILED.getName(), BillingClient.BillingResponseCode.ITEM_UNAVAILABLE,
						"product not fetched");
				return;
			}
			BillingFlowParams params = BillingFlowParams.newBuilder()
					.setProductDetailsParamsList(Collections.singletonList(
							BillingFlowParams.ProductDetailsParams.newBuilder()
									.setProductDetails(product)
									.build()))
					.build();
			BillingResult result = client.launchBillingFlow(activity, params);
			if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) {
				emitSignal(PURCHASE_FAILED.getName(), result.getResponseCode(), result.getDebugMessage());
			}
		});
	}

	/**
	 * Reports every one-time purchase Play holds for this account (purchase_state each), then
	 * purchases_queried. Acknowledges any purchased one not yet acknowledged.
	 */
	@UsedByGodot
	public void queryPurchases() {
		final Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		activity.runOnUiThread(() -> {
			if (client == null) {
				emitSignal(PURCHASES_QUERIED.getName(), false);
				return;
			}
			client.queryPurchasesAsync(
					QueryPurchasesParams.newBuilder()
							.setProductType(BillingClient.ProductType.INAPP)
							.build(),
					(result, purchases) -> {
						boolean ok = result.getResponseCode() == BillingClient.BillingResponseCode.OK;
						if (ok) {
							report(purchases);
						} else {
							Log.i(TAG, "purchases query failed: " + result.getResponseCode() + " "
									+ result.getDebugMessage());
						}
						emitSignal(PURCHASES_QUERIED.getName(), ok);
					});
		});
	}

	/** A purchase finished (or was cancelled, or failed) in Play's sheet. */
	private void onPurchasesUpdated(BillingResult result, List<Purchase> purchases) {
		int code = result.getResponseCode();
		if (code == BillingClient.BillingResponseCode.OK && purchases != null) {
			report(purchases);
		} else if (code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
			// Bought before (another device, a reinstall): the query reports it.
			queryPurchases();
		} else {
			emitSignal(PURCHASE_FAILED.getName(), code, result.getDebugMessage());
		}
	}

	/** Emits purchase_state for each product of each purchase; acknowledges purchased ones. */
	private void report(List<Purchase> purchases) {
		for (Purchase purchase : purchases) {
			int state = purchase.getPurchaseState();
			for (String productId : purchase.getProducts()) {
				emitSignal(PURCHASE_STATE.getName(), productId, state);
			}
			if (state == Purchase.PurchaseState.PURCHASED && !purchase.isAcknowledged()) {
				acknowledge(purchase);
			}
		}
	}

	/**
	 * Play refunds a purchase not acknowledged within three days. A failed acknowledgement is
	 * tried again at the next query (every launch and every resume).
	 */
	private void acknowledge(Purchase purchase) {
		client.acknowledgePurchase(
				AcknowledgePurchaseParams.newBuilder()
						.setPurchaseToken(purchase.getPurchaseToken())
						.build(),
				result -> Log.i(TAG, "acknowledge: " + result.getResponseCode() + " "
						+ result.getDebugMessage()));
	}

	/** A pending purchase may have completed while the game was away (a cash payment). */
	@Override
	public void onMainResume() {
		super.onMainResume();
		if (client != null) {
			queryPurchases();
		}
	}

	@Override
	public void onMainDestroy() {
		final Activity activity = getActivity();
		if (activity != null && client != null) {
			activity.runOnUiThread(() -> {
				client.endConnection();
				client = null;
			});
		}
		super.onMainDestroy();
	}
}
