package com.ambro86.sonarpad

import org.junit.Assert.*
import org.junit.Test
import okhttp3.Cookie
import okhttp3.HttpUrl.Companion.toHttpUrl

class RaiAndroidPlayerTest {
    @Test fun audioDescriptionRecognizesRaiAndStandardMetadata() {
        assertTrue(RaiTrackPolicy.isDescription("des", "", false))
        assertTrue(RaiTrackPolicy.isDescription("it", "Audiodescrizione", false))
        assertTrue(RaiTrackPolicy.isDescription("it", "", true))
        assertFalse(RaiTrackPolicy.isDescription("ita", "Italiano", false))
    }
    @Test fun preferenceKeepsItalianFallbackAndNormalAudioDistinct() {
        assertTrue(RaiTrackPolicy.score("des", true, true) > RaiTrackPolicy.score("ita", false, true))
        assertTrue(RaiTrackPolicy.score("ita", false, false) > RaiTrackPolicy.score("des", true, false))
        assertTrue(RaiTrackPolicy.score("it-IT", false, true) > RaiTrackPolicy.score("en", false, true))
    }
    @Test fun cookiesFollowDomainPathExpiryAndReplacementRules() {
        val jar = RaiCookieJar()
        val origin = "https://cdn.example.org/live/master.m3u8".toHttpUrl()
        jar.saveFromResponse(origin, listOf(Cookie.Builder().name("session").value("first")
            .hostOnlyDomain("cdn.example.org").path("/live").secure().build()))
        assertEquals("first", jar.loadForRequest("https://cdn.example.org/live/segment.ts".toHttpUrl()).single().value)
        assertTrue(jar.loadForRequest("https://other.example.org/live/segment.ts".toHttpUrl()).isEmpty())
        assertTrue(jar.loadForRequest("http://cdn.example.org/live/segment.ts".toHttpUrl()).isEmpty())
        assertTrue(jar.loadForRequest("https://cdn.example.org/private/segment.ts".toHttpUrl()).isEmpty())
        jar.saveFromResponse(origin, listOf(Cookie.Builder().name("session").value("expired")
            .hostOnlyDomain("cdn.example.org").path("/live").expiresAt(1).build()))
        assertTrue(jar.loadForRequest(origin).isEmpty())
    }
}
