package com.example.sonarpad_mobile_starter

import android.app.Application
import android.content.Intent
import android.media.AudioManager
import android.os.PowerManager
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.android.controller.ServiceController
import org.robolectric.shadows.ShadowPowerManager

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], application = Application::class)
class MediaKitPlaybackServiceTest {
    private lateinit var controller: ServiceController<MediaKitPlaybackService>
    private lateinit var service: MediaKitPlaybackService
    private val pauses = mutableListOf<String>()
    private val app get() = RuntimeEnvironment.getApplication()

    private class Result : MethodChannel.Result {
        var succeeded = false
        var error: String? = null
        override fun success(result: Any?) { succeeded = true }
        override fun error(code: String, message: String?, details: Any?) { error = code }
        override fun notImplemented() { fail("Unexpected method") }
    }

    @Before fun setUp() {
        MediaKitPlaybackService.onPause = { pauses.add(it) }
        controller = Robolectric.buildService(MediaKitPlaybackService::class.java).create()
        service = controller.get()
    }

    @After fun tearDown() {
        MediaKitPlaybackService.detach()
        controller.destroy()
    }

    private fun start(id: String = "current", title: String = "La7"): Result {
        val result = Result()
        MediaKitPlaybackService.start(app, id, title, "Pausa", result)
        service.onStartCommand(shadowOf(app).nextStartedService, 0, 1)
        return result
    }

    @Test fun holdsCpuWithScreenOffAndWhileBuffering() {
        shadowOf(app.getSystemService(PowerManager::class.java)).setIsInteractive(false)
        assertTrue(start().succeeded)
        val lock = ShadowPowerManager.getLatestWakeLock()
        assertTrue(lock.isHeld)
        assertNotNull(shadowOf(service).lastForegroundNotification)
        MediaKitPlaybackService.update("current", false, true)
        assertTrue(lock.isHeld)
        MediaKitPlaybackService.stop("current")
        assertFalse(lock.isHeld)
        assertTrue(shadowOf(service).isStoppedBySelf)
    }

    @Test fun staleScreenCannotReleaseCurrentPlayback() {
        start("old")
        val lock = ShadowPowerManager.getLatestWakeLock()
        start("new")
        assertEquals(listOf("old"), pauses)
        MediaKitPlaybackService.stop("old")
        assertTrue(lock.isHeld)
        MediaKitPlaybackService.stop("new")
        assertFalse(lock.isHeld)
    }

    @Test fun autoplayUpdatesTitleWithoutReleasingWakeLock() {
        start(title = "Episode 1")
        val lock = ShadowPowerManager.getLatestWakeLock()
        assertTrue(start(title = "Episode 2").succeeded)
        assertSame(lock, ShadowPowerManager.getLatestWakeLock())
        assertTrue(lock.isHeld)
        assertTrue(pauses.isEmpty())
        assertEquals("Episode 2", shadowOf(service).lastForegroundNotification.extras
            .getCharSequence(android.app.Notification.EXTRA_TITLE).toString())
    }

    @Test fun deniedAudioFocusFailsStartupAndStopsForegroundService() {
        shadowOf(app.getSystemService(AudioManager::class.java))
            .setNextFocusRequestResponse(AudioManager.AUDIOFOCUS_REQUEST_FAILED)
        val result = start()
        assertFalse(result.succeeded)
        assertEquals("background_start", result.error)
        assertTrue(shadowOf(service).isStoppedBySelf)
        assertFalse(ShadowPowerManager.getLatestWakeLock()?.isHeld ?: false)
    }

    @Test fun notificationPauseReleasesLockAndNotifiesOwningPlayer() {
        start()
        val lock = ShadowPowerManager.getLatestWakeLock()
        shadowOf(service).lastForegroundNotification.actions[0].actionIntent.send()
        service.onStartCommand(shadowOf(app).nextStartedService, 0, 2)
        assertEquals(listOf("current"), pauses)
        assertFalse(lock.isHeld)
    }

    @Test fun removingTaskReleasesLockAndPausesPlayer() {
        start()
        val lock = ShadowPowerManager.getLatestWakeLock()
        service.onTaskRemoved(Intent())
        assertFalse(lock.isHeld)
        assertEquals(listOf("current"), pauses)
    }

    @Test fun engineDetachReleasesResources() {
        start()
        val lock = ShadowPowerManager.getLatestWakeLock()
        MediaKitPlaybackService.detach()
        assertFalse(lock.isHeld)
        assertTrue(shadowOf(service).isStoppedBySelf)
    }
}
