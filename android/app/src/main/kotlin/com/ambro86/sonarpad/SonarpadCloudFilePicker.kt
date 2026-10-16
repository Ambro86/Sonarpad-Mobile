package com.ambro86.sonarpad

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/** ACTION_OPEN_DOCUMENT keeps the provider URI accessible while we stream it to
 * a private cache file. Unlike the standard file_picker path copy, this exposes
 * genuine byte progress and can stop during a cloud download. */
class SonarpadCloudFilePicker(private val activity: AudioServiceActivity) {
    companion object {
        const val REQUEST_CODE = 53941
    }

    private var pendingResult: MethodChannel.Result? = null
    private var events: EventChannel.EventSink? = null
    private var allowMultiple = false
    private var allowedExtensions: Set<String> = emptySet()
    private val cancelled = AtomicBoolean(false)
    private var worker: Thread? = null
    @Volatile private var activeInput: InputStream? = null

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "sonarpad/cloud_file_picker")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "cancel" -> {
                        cancelled.set(true)
                        // Unblock a provider stream that is currently waiting on cloud data.
                        runCatching { activeInput?.close() }
                        result.success(null)
                    }
                    "pickFiles" -> {
                        if (pendingResult != null) {
                            result.error("picker_busy", "Another document picker is active", null)
                            return@setMethodCallHandler
                        }
                        val args = call.arguments as? Map<*, *>
                        allowMultiple = args?.get("allowMultiple") as? Boolean ?: false
                        allowedExtensions = (args?.get("allowedExtensions") as? List<*>)
                            ?.mapNotNull { it as? String }
                            ?.map { it.lowercase().trimStart('.') }
                            ?.toSet() ?: emptySet()
                        cancelled.set(false)
                        pendingResult = result
                        try {
                            val picker = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            activity.startActivityForResult(picker, REQUEST_CODE)
                        } catch (error: Exception) {
                            completeError("picker_unavailable", error.message ?: "Could not open picker")
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(engine.dartExecutor.binaryMessenger, "sonarpad/cloud_file_picker_progress")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                }
                override fun onCancel(arguments: Any?) {
                    events = null
                }
            })
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE || pendingResult == null) return false
        if (resultCode != Activity.RESULT_OK || data == null) {
            complete(null)
            return true
        }
        val uris = mutableListOf<Uri>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
        } else {
            data.data?.let(uris::add)
        }
        if (uris.isEmpty()) {
            complete(null)
            return true
        }
        publish("preparing", 0, -1)
        worker = Thread {
            val tempFiles = mutableListOf<File>()
            val picked = mutableListOf<Map<String, Any>>()
            try {
                val dir = File(activity.cacheDir, "sonarpad_cloud_import")
                if (!dir.exists() && !dir.mkdirs()) throw IllegalStateException("Cannot create import cache")
                for (uri in uris) {
                    if (cancelled.get()) throw InterruptedException("Copy cancelled")
                    val (rawName, expectedSize) = fileDetails(uri)
                    val name = rawName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
                    val ext = name.substringAfterLast('.', "").lowercase()
                    if (allowedExtensions.isNotEmpty() && ext !in allowedExtensions) {
                        throw IllegalArgumentException("Selected file type is not supported")
                    }
                    val target = File(dir, "${UUID.randomUUID()}_$name")
                    tempFiles.add(target)
                    var copied = 0L
                    var lastPercent = -1
                    publish("copying", 0, expectedSize)
                    activity.contentResolver.openInputStream(uri)?.use { input ->
                        activeInput = input
                        target.outputStream().buffered(65536).use { output ->
                            val buffer = ByteArray(65536)
                            while (true) {
                                if (cancelled.get()) throw InterruptedException("Copy cancelled")
                                val count = input.read(buffer)
                                if (count < 0) break
                                if (count == 0) continue
                                output.write(buffer, 0, count)
                                copied += count
                                val percentage = if (expectedSize > 0) (100 * copied / expectedSize).toInt() else -1
                                if (percentage != lastPercent || (expectedSize <= 0 && copied % 1048576L < count)) {
                                    lastPercent = percentage
                                    publish("copying", copied, expectedSize)
                                }
                            }
                        }
                    } ?: throw IllegalStateException("Unable to read selected cloud file")
                    activeInput = null
                    if (expectedSize > 0 && copied != expectedSize) {
                        throw IllegalStateException("Cloud file copy was incomplete")
                    }
                    picked.add(mapOf("name" to rawName, "path" to target.absolutePath, "size" to copied))
                }
                if (cancelled.get()) throw InterruptedException("Copy cancelled")
                activity.runOnUiThread { complete(picked) }
            } catch (error: Exception) {
                activeInput = null
                tempFiles.forEach { it.delete() }
                activity.runOnUiThread {
                    if (cancelled.get()) complete(null)
                    else completeError("cloud_file_error", error.message ?: "Could not copy file")
                }
            }
        }.apply { name = "SonarpadCloudFilePicker"; start() }
        return true
    }

    private fun fileDetails(uri: Uri): Pair<String, Long> {
        var cursor: Cursor? = null
        return try {
            cursor = activity.contentResolver.query(
                uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null
            )
            var name = uri.lastPathSegment ?: "document"
            var size = -1L
            if (cursor?.moveToFirst() == true) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameIndex >= 0 && !cursor.isNull(nameIndex)) name = cursor.getString(nameIndex)
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) size = cursor.getLong(sizeIndex)
            }
            Pair(name, size)
        } finally { cursor?.close() }
    }

    private fun publish(stage: String, copied: Long, total: Long) {
        activity.runOnUiThread {
            events?.success(mapOf("stage" to stage, "copied" to copied, "total" to total))
        }
    }

    private fun complete(value: Any?) {
        val callback = pendingResult
        pendingResult = null
        worker = null
        callback?.success(value)
    }

    private fun completeError(code: String, message: String) {
        val callback = pendingResult
        pendingResult = null
        worker = null
        callback?.error(code, message, null)
    }
}
