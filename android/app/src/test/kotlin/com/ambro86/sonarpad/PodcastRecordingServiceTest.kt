package com.ambro86.sonarpad

import android.app.Application
import android.app.Service
import android.os.PowerManager
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Assert.*
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
class PodcastRecordingServiceTest {
    private var controller: ServiceController<PodcastRecordingService>? = null
    private val app get() = RuntimeEnvironment.getApplication()

    private class Result : MethodChannel.Result {
        var succeeded = false
        var error: String? = null
        override fun success(result: Any?) { succeeded = true }
        override fun error(code: String, message: String?, details: Any?) { error = code }
        override fun notImplemented() { fail("Unexpected method") }
    }

    @After fun tearDown() {
        PodcastRecordingService.stop(app)
        controller?.destroy()
    }

    @Test fun holdsCpuWithScreenOffAndReleasesOnShutdown() {
        shadowOf(app.getSystemService(PowerManager::class.java)).setIsInteractive(false)
        val result = Result()
        PodcastRecordingService.start(app, "Test podcast", result)
        assertFalse(result.succeeded)
        val intent = shadowOf(app).nextStartedService
        controller = Robolectric.buildService(PodcastRecordingService::class.java).create()
        val service = controller!!.get()
        assertEquals(Service.START_NOT_STICKY, service.onStartCommand(intent, 0, 1))
        assertTrue(result.succeeded)
        val lock = ShadowPowerManager.getLatestWakeLock()
        assertTrue(lock.isHeld)
        assertEquals("Test podcast", shadowOf(service).lastForegroundNotification.extras
            .getCharSequence(android.app.Notification.EXTRA_TEXT).toString())
        val duplicate = Result()
        PodcastRecordingService.start(app, "Duplicate", duplicate)
        assertEquals("recording_busy", duplicate.error)
        PodcastRecordingService.stop(app)
        controller!!.destroy()
        controller = null
        assertFalse(lock.isHeld)
    }

    @Test fun systemRestartDoesNotRestartMicrophone() {
        controller = Robolectric.buildService(PodcastRecordingService::class.java).create()
        val service = controller!!.get()
        assertEquals(Service.START_NOT_STICKY, service.onStartCommand(null, 0, 1))
        assertTrue(shadowOf(service).isStoppedBySelf)
        assertNull(shadowOf(service).lastForegroundNotification)
    }

    @Test fun cancellingPendingStartupCompletesCaller() {
        val result = Result()
        PodcastRecordingService.start(app, "Test", result)
        PodcastRecordingService.stop(app)
        assertEquals("recording_cancelled", result.error)
        assertFalse(result.succeeded)
    }
}
