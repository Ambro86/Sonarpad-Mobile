package com.ambro86.sonarpad

import android.app.Activity
import com.dropbox.core.DbxRequestConfig
import com.dropbox.core.android.Auth
import com.dropbox.core.android.AuthActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** SDK owns app detection, signature verification, PKCE and browser fallback. */
class SonarpadDropboxAuth(
    private val activity: Activity,
    private val startAuth: (Activity) -> Unit = {
        AuthActivity.result = null
        Auth.startOAuth2PKCE(
            it, "q39vgbb6gks3474",
            DbxRequestConfig.newBuilder("Sonarpad/Android").build()
        )
    },
    private val readCredential: () -> Map<String, String?>? = {
        val credential = Auth.getDbxCredential()
        AuthActivity.result = null
        credential?.let {
            mapOf("access_token" to it.accessToken, "refresh_token" to it.refreshToken)
        }
    }
) {
    private var pending: MethodChannel.Result? = null
    private var leftActivity = false

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "sonarpad/dropbox_auth")
            .setMethodCallHandler { call, result ->
                if (call.method == "authenticate") authenticate(result)
                else result.notImplemented()
            }
    }

    internal fun authenticate(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("auth_in_progress", "Dropbox authorization already in progress", null)
            return
        }
        pending = result
        leftActivity = false
        try {
            startAuth(activity)
        } catch (_: Exception) {
            pending = null
            result.error("auth_unavailable", "Unable to start Dropbox authorization", null)
        }
    }

    fun onPause() {
        if (pending != null) leftActivity = true
    }

    fun onResume() {
        if (!leftActivity) return
        val result = pending ?: return
        pending = null
        leftActivity = false
        try {
            // Null means cancellation; do not reopen a browser after the user cancels.
            result.success(readCredential())
        } catch (_: Exception) {
            result.error("auth_failed", "Unable to complete Dropbox authorization", null)
        }
    }

    fun dispose() {
        pending?.success(null)
        pending = null
        leftActivity = false
    }
}
