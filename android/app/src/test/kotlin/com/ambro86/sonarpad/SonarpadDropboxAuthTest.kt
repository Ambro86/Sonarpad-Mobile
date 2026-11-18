package com.ambro86.sonarpad

import android.app.Activity
import android.app.Application
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 35], application = Application::class)
class SonarpadDropboxAuthTest {
    private class Result : MethodChannel.Result {
        var calls = 0
        var value: Any? = null
        var errorCode: String? = null
        override fun success(result: Any?) { calls++; value = result }
        override fun error(code: String, message: String?, details: Any?) { calls++; errorCode = code }
        override fun notImplemented() { fail("Unexpected method") }
    }

    @Test fun resumeBeforeLeavingDoesNotCancelAndReturnCompletesOnlyOnce() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val credential = mapOf("access_token" to "test", "refresh_token" to "refresh")
        val auth = SonarpadDropboxAuth(activity, {}, { credential })
        val result = Result()
        auth.authenticate(result)
        auth.onResume()
        assertEquals(0, result.calls)
        auth.onPause()
        auth.onResume()
        auth.onResume()
        assertEquals(1, result.calls)
        assertEquals(credential, result.value)
    }

    @Test fun cancellationAllowsRetryAndDoesNotLaunchAgain() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        var starts = 0
        val auth = SonarpadDropboxAuth(activity, { starts++ }, { null })
        repeat(2) {
            val result = Result()
            auth.authenticate(result)
            auth.onPause()
            auth.onResume()
            assertEquals(1, result.calls)
            assertNull(result.value)
        }
        assertEquals(2, starts)
    }

    @Test fun concurrentLoginIsRejectedAndDisposeCompletesOriginal() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val auth = SonarpadDropboxAuth(activity, {}, { null })
        val first = Result()
        val second = Result()
        auth.authenticate(first)
        auth.authenticate(second)
        assertEquals("auth_in_progress", second.errorCode)
        auth.dispose()
        auth.onPause()
        auth.onResume()
        assertEquals(1, first.calls)
        assertNull(first.value)
    }

    @Test fun launchFailureDoesNotLeavePendingRequest() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val auth = SonarpadDropboxAuth(activity, { throw IllegalStateException() }, { null })
        repeat(2) {
            val result = Result()
            auth.authenticate(result)
            assertEquals("auth_unavailable", result.errorCode)
            assertEquals(1, result.calls)
        }
    }
}
