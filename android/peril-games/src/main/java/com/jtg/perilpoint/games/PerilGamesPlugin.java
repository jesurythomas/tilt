// PerilGamesPlugin.java
// The game's Play Games Services plugin (rulings PGS R1-R7,
// docs/superpowers/plans/2026-10-14-play-games-leaderboards.md): sign-in, scores and the
// leaderboard screens. GDScript reaches it as the "PerilGames" singleton, only through
// godot/src/core/android_games_backend.gd.
//
// Threads: Godot calls the @UsedByGodot methods on its render thread; every SDK call runs on the
// UI thread (runOnUiThread), where its Task listeners also land. emitSignal posts back to the
// render thread.
package com.jtg.perilpoint.games;

import android.app.Activity;
import android.content.Intent;
import android.util.Log;
import android.view.View;

import com.google.android.gms.games.AuthenticationResult;
import com.google.android.gms.games.GamesActivityResultCodes;
import com.google.android.gms.games.PlayGames;
import com.google.android.gms.games.PlayGamesSdk;
import com.google.android.gms.tasks.Task;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

public class PerilGamesPlugin extends GodotPlugin {
	private static final String TAG = "PerilGames";

	/** The board screens' request code; their result matters only for PGS R7. */
	private static final int RC_LEADERBOARD = 9004;

	private static final SignalInfo SIGN_IN_CHECKED =
			new SignalInfo("sign_in_checked", Boolean.class, String.class);
	private static final SignalInfo SIGNED_OUT = new SignalInfo("signed_out");
	private static final SignalInfo LEADERBOARD_FAILED =
			new SignalInfo("leaderboard_failed", String.class);

	public PerilGamesPlugin(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "PerilGames";
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(SIGN_IN_CHECKED);
		signals.add(SIGNED_OUT);
		signals.add(LEADERBOARD_FAILED);
		return signals;
	}

	/**
	 * Google initializes the SDK in Application.onCreate; a plugin has no Application, and this
	 * is its earliest hook (PGS R3).
	 */
	@Override
	public View onMainCreate(Activity activity) {
		PlayGamesSdk.initialize(activity.getApplicationContext());
		return null;
	}

	/** Reads the launch's automatic sign-in. Emits sign_in_checked(is_signed_in, error). */
	@UsedByGodot
	public void checkSignIn() {
		final Activity activity = getActivity();
		if (activity == null) {
			emitSignal(SIGN_IN_CHECKED.getName(), false, "no activity");
			return;
		}
		activity.runOnUiThread(() -> PlayGames.getGamesSignInClient(activity).isAuthenticated()
				.addOnCompleteListener(this::finishSignIn));
	}

	/** Shows Play Games' sign-in, at the player's tap. Emits sign_in_checked. */
	@UsedByGodot
	public void signIn() {
		final Activity activity = getActivity();
		if (activity == null) {
			emitSignal(SIGN_IN_CHECKED.getName(), false, "no activity");
			return;
		}
		activity.runOnUiThread(() -> PlayGames.getGamesSignInClient(activity).signIn()
				.addOnCompleteListener(this::finishSignIn));
	}

	/** Posts a score to a board, which keeps the player's best (PGS R4). */
	@UsedByGodot
	public void submitScore(String leaderboardId, long score) {
		final Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		activity.runOnUiThread(
				() -> PlayGames.getLeaderboardsClient(activity).submitScore(leaderboardId, score));
	}

	/** Opens one board, or every board when the id is blank (PGS R5). */
	@UsedByGodot
	public void showLeaderboard(String leaderboardId) {
		final Activity activity = getActivity();
		if (activity == null) {
			emitSignal(LEADERBOARD_FAILED.getName(), "no activity");
			return;
		}
		activity.runOnUiThread(() -> {
			Task<Intent> intent = leaderboardId.isEmpty()
					? PlayGames.getLeaderboardsClient(activity).getAllLeaderboardsIntent()
					: PlayGames.getLeaderboardsClient(activity).getLeaderboardIntent(leaderboardId);
			intent.addOnSuccessListener(
					screen -> activity.startActivityForResult(screen, RC_LEADERBOARD))
					.addOnFailureListener(error -> {
						Log.w(TAG, "leaderboard: " + error);
						emitSignal(LEADERBOARD_FAILED.getName(), String.valueOf(error));
					});
		});
	}

	/** PGS R7: the player signed out from Play Games' own screens. */
	@Override
	public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
		if (requestCode == RC_LEADERBOARD
				&& resultCode == GamesActivityResultCodes.RESULT_RECONNECT_REQUIRED) {
			emitSignal(SIGNED_OUT.getName());
		}
	}

	private void finishSignIn(Task<AuthenticationResult> task) {
		boolean isSignedIn = task.isSuccessful() && task.getResult().isAuthenticated();
		String error = task.isSuccessful() ? "" : String.valueOf(task.getException());
		if (!error.isEmpty()) {
			Log.w(TAG, "sign-in: " + error);
		}
		emitSignal(SIGN_IN_CHECKED.getName(), isSignedIn, error);
	}
}
