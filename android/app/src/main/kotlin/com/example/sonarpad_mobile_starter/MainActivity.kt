package com.example.sonarpad_mobile_starter

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val methodChannelName = "sonarpad/shared_media"
    private val eventChannelName = "sonarpad/shared_media_events"
    private var eventSink: EventChannel.EventSink? = null
    private var pendingSharedPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName
        ).setMethodCallHandler { call, result ->
            if (call.method == "getInitialSharedFile") {
                val path = pendingSharedPath
                pendingSharedPath = null
                result.success(path)
            } else {
                result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                pendingSharedPath?.let {
                    events?.success(it)
                    pendingSharedPath = null
                }
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        handleSharedIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleSharedIntent(intent)
    }

    private fun handleSharedIntent(intent: Intent?) {
        val uri = sharedUriFrom(intent) ?: return
        Thread {
            val path = copySharedUri(uri) ?: return@Thread
            runOnUiThread {
                val sink = eventSink
                if (sink != null) {
                    sink.success(path)
                } else {
                    pendingSharedPath = path
                }
            }
        }.start()
    }

    private fun sharedUriFrom(intent: Intent?): Uri? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            Intent.ACTION_VIEW -> intent.data
            else -> null
        }
    }

    private fun copySharedUri(uri: Uri): String? {
        return try {
            if (uri.scheme == "file") {
                uri.path
            } else {
                val name = safeFileName(displayName(uri) ?: "shared_media")
                val targetDir = File(cacheDir, "shared_media")
                if (!targetDir.exists()) targetDir.mkdirs()
                val target = File(targetDir, name)
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output ->
                        input.copyTo(output)
                    }
                } ?: return null
                target.absolutePath
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun displayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(uri, null, null, null, null)
            val nameIndex = cursor?.getColumnIndex(OpenableColumns.DISPLAY_NAME) ?: -1
            if (cursor != null && cursor.moveToFirst() && nameIndex >= 0) {
                cursor.getString(nameIndex)
            } else {
                uri.lastPathSegment
            }
        } finally {
            cursor?.close()
        }
    }

    private fun safeFileName(name: String): String {
        return name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .ifBlank { "shared_media" }
    }
}
