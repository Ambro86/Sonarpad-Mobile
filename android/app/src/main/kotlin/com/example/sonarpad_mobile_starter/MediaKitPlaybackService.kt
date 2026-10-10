package com.example.sonarpad_mobile_starter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/** Foreground lifetime and CPU wake lock for the existing Dart MediaKit player. */
class MediaKitPlaybackService : Service() {
    companion object {
        private const val TAG = "MediaKitPlayback"
        private const val CHANNEL = "sonarpad_live_playback"
        private const val NOTIFICATION = 7241
        private const val PAUSE = "sonarpad.mediakit.PAUSE"
        private var instance: MediaKitPlaybackService? = null
        private val pendingStarts = mutableMapOf<String, MethodChannel.Result>()
        var onPause: ((String) -> Unit)? = null

        fun start(context: Context, id: String, title: String, pauseLabel: String,
                  result: MethodChannel.Result) {
            pendingStarts[id] = result
            val intent = Intent(context, MediaKitPlaybackService::class.java)
                .putExtra("id", id).putExtra("title", title)
                .putExtra("pauseLabel", pauseLabel)
            try {
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
                else context.startService(intent)
            } catch (error: Exception) {
                pendingStarts.remove(id)?.error("background_start", error.message, null)
            }
        }

        fun update(id: String, playing: Boolean, buffering: Boolean) {
            instance?.takeIf { it.owner == id }?.updateState(playing, buffering)
        }

        fun stop(id: String) {
            instance?.takeIf { it.owner == id }?.finishPlayback()
        }

        fun detach() {
            onPause = null
            instance?.finishPlayback()
            pendingStarts.values.toList().forEach {
                it.error("background_detached", "Flutter engine detached", null)
            }
            pendingStarts.clear()
        }
    }

    private var owner: String? = null
    private lateinit var session: MediaSession
    private lateinit var audioManager: AudioManager
    private var focusRequest: AudioFocusRequest? = null
    private var hasFocus = false
    private var wakeLock: PowerManager.WakeLock? = null
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        // Pause on interruptions instead of competing with calls or other apps.
        if (change == AudioManager.AUDIOFOCUS_LOSS ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK) pausePlayback()
    }
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) pausePlayback()
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        audioManager = getSystemService(AudioManager::class.java)
        session = MediaSession(this, TAG).apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPause() = pausePlayback()
                override fun onStop() = pausePlayback()
            }, Handler(Looper.getMainLooper()))
        }
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(noisyReceiver, filter, RECEIVER_NOT_EXPORTED)
        else registerReceiver(noisyReceiver, filter)
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Sonarpad", NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == PAUSE) {
            if (intent.getStringExtra("id") == owner) pausePlayback()
            else if (owner == null) finishPlayback()
            return START_NOT_STICKY
        }
        val id = intent?.getStringExtra("id")
        if (id == null || onPause == null) {
            if (id != null) pendingStarts.remove(id)?.error("background_detached", "No player", null)
            stopSelf()
            return START_NOT_STICKY
        }
        val previousOwner = owner
        if (previousOwner != null && previousOwner != id) onPause?.invoke(previousOwner)
        owner = id
        try {
            session.setMetadata(MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, intent.getStringExtra("title"))
                .putString(MediaMetadata.METADATA_KEY_ARTIST, "Sonarpad").build())
            session.isActive = true
            updateState(false, true)
            val notification = notification(intent.getStringExtra("title") ?: "Sonarpad",
                intent.getStringExtra("pauseLabel") ?: "Pause", id)
            // Promote before asking for focus: Android 15 requires foreground
            // visibility or an active foreground service for audio focus.
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else startForeground(NOTIFICATION, notification)
            if (!requestFocus()) throw IllegalStateException("Audio focus denied")
            if (wakeLock == null) {
                wakeLock = getSystemService(PowerManager::class.java)
                    .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Sonarpad:MediaKitPlayback")
                    .apply { setReferenceCounted(false); acquire() }
            }
            Log.i(TAG, "Foreground playback started; CPU wake lock held")
            pendingStarts.remove(id)?.success(null)
        } catch (error: Exception) {
            Log.e(TAG, "Unable to protect background playback", error)
            pendingStarts.remove(id)?.error("background_start", error.message, null)
            finishPlayback()
        }
        // A killed Dart player cannot be restored by restarting an empty service.
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun requestFocus(): Boolean {
        if (hasFocus) return true
        val result = if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                .setOnAudioFocusChangeListener(focusListener, Handler(Looper.getMainLooper()))
                .build()
            focusRequest = request
            audioManager.requestAudioFocus(request)
        } else audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN)
        hasFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return hasFocus
    }

    private fun notification(title: String, pauseLabel: String, id: String): Notification {
        val pause = PendingIntent.getService(this, NOTIFICATION,
            Intent(this, MediaKitPlaybackService::class.java).setAction(PAUSE).putExtra("id", id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
            else Notification.Builder(this)
        return builder.setSmallIcon(R.drawable.ic_stat_playback)
            .setContentTitle(title).setContentText("Sonarpad").setContentIntent(open)
            .setCategory(Notification.CATEGORY_TRANSPORT).setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true).setShowWhen(false)
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_pause, pauseLabel, pause).build())
            .setStyle(Notification.MediaStyle().setMediaSession(session.sessionToken).setShowActionsInCompactView(0))
            .build()
    }

    private fun updateState(playing: Boolean, buffering: Boolean) {
        val state = if (buffering) PlaybackState.STATE_BUFFERING
            else if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED
        session.setPlaybackState(PlaybackState.Builder()
            .setActions(PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_STOP)
            .setState(state, PlaybackState.PLAYBACK_POSITION_UNKNOWN, if (playing) 1f else 0f).build())
    }

    private fun pausePlayback() {
        val id = owner ?: return
        onPause?.invoke(id)
        finishPlayback()
    }

    @Suppress("DEPRECATION")
    private fun releaseResources() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        if (hasFocus) {
            if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            else audioManager.abandonAudioFocus(focusListener)
        }
        hasFocus = false
        focusRequest = null
        session.isActive = false
    }

    private fun finishPlayback() {
        owner = null
        releaseResources()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.i(TAG, "Foreground playback stopped; CPU wake lock released")
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        pausePlayback()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        val id = owner
        owner = null
        if (id != null) onPause?.invoke(id)
        releaseResources()
        unregisterReceiver(noisyReceiver)
        session.release()
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
