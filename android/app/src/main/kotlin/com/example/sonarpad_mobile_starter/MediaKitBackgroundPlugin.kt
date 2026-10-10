package com.example.sonarpad_mobile_starter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** Engine-scoped: Activity recreation must not stop background playback. */
class MediaKitBackgroundPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val commands = MethodChannel(binding.binaryMessenger, "sonarpad/mediakit_background")
        channel = commands
        MediaKitPlaybackService.onPause = { id -> commands.invokeMethod("pause", id) }
        commands.setMethodCallHandler { call, result ->
            val id = call.argument<String>("id")
            if (id == null) {
                result.error("invalid_session", "Missing playback session", null)
            } else when (call.method) {
                "start" -> MediaKitPlaybackService.start(binding.applicationContext, id,
                    call.argument<String>("title") ?: "Sonarpad",
                    call.argument<String>("pauseLabel") ?: "Pause", result)
                "update" -> {
                    MediaKitPlaybackService.update(id,
                        call.argument<Boolean>("playing") ?: false,
                        call.argument<Boolean>("buffering") ?: false)
                    result.success(null)
                }
                "stop" -> {
                    MediaKitPlaybackService.stop(id)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        MediaKitPlaybackService.detach()
    }
}
