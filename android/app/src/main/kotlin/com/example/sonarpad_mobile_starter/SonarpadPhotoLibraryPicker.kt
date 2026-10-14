package com.example.sonarpad_mobile_starter

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

/** Copies selected content while its temporary URI permission is still valid. */
class SonarpadPhotoLibraryPicker(private val activity: Activity) {
    companion object {
        internal fun createIntent(multiple: Boolean): Intent =
            if (Build.VERSION.SDK_INT >= 33) {
                Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                    type = "video/*"
                    if (multiple) {
                        putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, MediaStore.getPickImagesMaxLimit())
                    }
                }
            } else {
                Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "video/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                    putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
                }
            }
    }

    private var pending: MethodChannel.Result? = null
    private val requestCode = 7392

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "sonarpad/photo_library_import")
            .setMethodCallHandler { call, result ->
                if (call.method != "pickVideos") {
                    result.notImplemented()
                } else if (pending != null) {
                    result.error("picker_busy", "Video picker already open", null)
                } else {
                    val multiple = call.argument<Boolean>("allowMultiple") ?: true
                    val intent = createIntent(multiple)
                    pending = result
                    try {
                        activity.startActivityForResult(intent, requestCode)
                    } catch (error: Exception) {
                        pending = null
                        result.error("picker_unavailable", error.message, null)
                    }
                }
            }
    }

    fun handleActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
        if (code != requestCode) return false
        val callback = pending ?: return true
        if (resultCode != Activity.RESULT_OK || data == null) {
            pending = null
            callback.success(emptyList<String>())
            return true
        }
        val uris = (data.clipData?.let { clip ->
            (0 until clip.itemCount).map { clip.getItemAt(it).uri }
        } ?: listOfNotNull(data.data)).distinct()
        Thread {
            val directory = File(activity.cacheDir, "photo_import/${UUID.randomUUID()}")
            try {
                check(directory.mkdirs()) { "Cannot create video import directory" }
                val paths = uris.mapIndexed { index, uri ->
                    val name = activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) cursor.getString(0) else null
                    } ?: "video.mp4"
                    val itemDirectory = File(directory, index.toString()).apply { mkdirs() }
                    val target = File(itemDirectory, File(name).name)
                    activity.contentResolver.openInputStream(uri)?.use { input ->
                        target.outputStream().use { output -> input.copyTo(output) }
                    } ?: error("Unable to read selected video")
                    target.absolutePath
                }
                activity.runOnUiThread { pending = null; callback.success(paths) }
            } catch (error: Exception) {
                directory.deleteRecursively()
                activity.runOnUiThread { pending = null; callback.error("photo_import_failed", error.message, null) }
            }
        }.start()
        return true
    }
}
