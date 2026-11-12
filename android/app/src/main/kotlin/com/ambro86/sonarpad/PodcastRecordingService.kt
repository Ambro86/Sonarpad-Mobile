package com.ambro86.sonarpad

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** Protects the existing record plugin capture; does not open another microphone. */
class PodcastRecordingService : Service() {
    companion object {
        private const val CHANNEL = "sonarpad_podcast_recording"
        private const val NOTIFICATION = 7242
        private var pending: MethodChannel.Result? = null
        private var instance: PodcastRecordingService? = null

        fun start(context: Context, title: String, result: MethodChannel.Result) {
            if (pending != null || instance != null) {
                result.error("recording_busy", "Recording service already active", null)
                return
            }
            pending = result
            val intent = Intent(context, PodcastRecordingService::class.java).putExtra("title", title)
            try {
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
                else context.startService(intent)
            } catch (error: Exception) {
                pending = null
                result.error("recording_background", error.message, null)
            }
        }

        fun stop(context: Context) {
            val result = pending
            pending = null
            result?.error("recording_cancelled", "Recording service stopped", null)
            context.stopService(Intent(context, PodcastRecordingService::class.java))
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Sonarpad Podcast", NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    @Suppress("DEPRECATION")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val result = pending
        pending = null
        if (result == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            val open = Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val notification = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
                else Notification.Builder(this))
                .setSmallIcon(R.drawable.ic_stat_playback)
                .setContentTitle("Sonarpad Podcast")
                .setContentText(intent?.getStringExtra("title") ?: "Sonarpad")
                .setContentIntent(PendingIntent.getActivity(this, NOTIFICATION, open,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                .setOngoing(true)
                .setCategory(Notification.CATEGORY_SERVICE)
                .build()
            if (Build.VERSION.SDK_INT >= 30) {
                startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else startForeground(NOTIFICATION, notification)
            wakeLock = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Sonarpad:PodcastRecording")
                .apply { setReferenceCounted(false); acquire() }
            result.success(null)
        } catch (error: Exception) {
            result.error("recording_background", error.message, null)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE)
        else stopForeground(true)
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

class PodcastRecordingPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "sonarpad/podcast_recording").also { commands ->
            commands.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> PodcastRecordingService.start(binding.applicationContext,
                        call.argument<String>("title") ?: "Sonarpad", result)
                    "stop" -> {
                        PodcastRecordingService.stop(binding.applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        PodcastRecordingService.stop(binding.applicationContext)
    }
}
