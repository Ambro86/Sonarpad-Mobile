package com.example.sonarpad_mobile_starter

import android.content.Intent
import android.provider.MediaStore
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
class SonarpadPhotoLibraryPickerTest {
    @Test
    @Config(sdk = [33])
    fun audioDescriptionSelectsOneVideoWithSystemPhotoPicker() {
        val intent = SonarpadPhotoLibraryPicker.createIntent(false)
        assertEquals(MediaStore.ACTION_PICK_IMAGES, intent.action)
        assertEquals("video/*", intent.type)
        assertFalse(intent.hasExtra(MediaStore.EXTRA_PICK_IMAGES_MAX))
    }

    @Test
    @Config(sdk = [33])
    fun libraryAllowsMultipleVideosWithinSystemLimit() {
        val intent = SonarpadPhotoLibraryPicker.createIntent(true)
        assertEquals("video/*", intent.type)
        assertEquals(MediaStore.getPickImagesMaxLimit(), intent.getIntExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, 0))
    }

    @Test
    @Config(sdk = [28])
    fun olderAndroidUsesVideoContentPickerWithoutBroadStoragePermission() {
        val single = SonarpadPhotoLibraryPicker.createIntent(false)
        assertEquals(Intent.ACTION_GET_CONTENT, single.action)
        assertEquals("video/*", single.type)
        assertTrue(single.hasCategory(Intent.CATEGORY_OPENABLE))
        assertFalse(single.getBooleanExtra(Intent.EXTRA_ALLOW_MULTIPLE, true))
        assertTrue(SonarpadPhotoLibraryPicker.createIntent(true).getBooleanExtra(Intent.EXTRA_ALLOW_MULTIPLE, false))
    }
}
