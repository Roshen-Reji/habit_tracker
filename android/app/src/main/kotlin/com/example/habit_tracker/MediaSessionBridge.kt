package com.example.habit_tracker

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MediaSessionBridge(private val context: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "MediaSessionBridge"
        private const val METHOD_CHANNEL = "habit/media_control"
        private const val EVENT_CHANNEL = "habit/now_playing"

        var instance: MediaSessionBridge? = null
            private set
    }

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    private var currentController: MediaController? = null
    private var mediaSessionManager: MediaSessionManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val sessionsChangedListener =
        MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
            mainHandler.post {
                updateActiveController(controllers?.firstOrNull())
            }
        }

    private val controllerCallback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) {
            mainHandler.post { emitCurrentPlayback() }
        }

        override fun onMetadataChanged(metadata: MediaMetadata?) {
            mainHandler.post { emitCurrentPlayback() }
        }

        override fun onSessionDestroyed() {
            mainHandler.post {
                currentController = null
                emitCurrentPlayback()
            }
        }
    }

    fun register(messenger: BinaryMessenger) {
        instance = this
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(this@MediaSessionBridge)
        }
        eventChannel = EventChannel(messenger, EVENT_CHANNEL).apply {
            setStreamHandler(this@MediaSessionBridge)
        }
        mediaSessionManager =
            context.getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
        attachSessionListenerIfPossible()
    }

    fun unregister() {
        detachSessionListener()
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        instance = null
    }

    fun onNotificationListenerConnected() {
        mainHandler.post {
            attachSessionListenerIfPossible()
            refreshActiveController()
        }
    }

    fun onNotificationListenerDisconnected() {
        mainHandler.post {
            detachSessionListener()
            currentController = null
            emitCurrentPlayback()
        }
    }

    private fun hasNotificationAccess(): Boolean {
        val flat = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val pkg = context.packageName
        return flat.split(":").any { it.contains(pkg) }
    }

    private fun attachSessionListenerIfPossible() {
        if (!hasNotificationAccess()) return
        try {
            val component = MediaNotificationListenerService.getComponentName(context)
            mediaSessionManager?.addOnActiveSessionsChangedListener(
                sessionsChangedListener,
                component
            )
            refreshActiveController()
        } catch (e: Exception) {
            Log.e(TAG, "Error registering active sessions listener: ${e.message}")
        }
    }

    private fun detachSessionListener() {
        try {
            mediaSessionManager?.removeOnActiveSessionsChangedListener(sessionsChangedListener)
            currentController?.unregisterCallback(controllerCallback)
        } catch (e: Exception) {
            Log.e(TAG, "Error detaching session listener: ${e.message}")
        }
    }

    private fun refreshActiveController() {
        if (!hasNotificationAccess()) {
            updateActiveController(null)
            return
        }
        try {
            val component = MediaNotificationListenerService.getComponentName(context)
            val controllers = mediaSessionManager?.getActiveSessions(component)
            updateActiveController(controllers?.firstOrNull())
        } catch (e: Exception) {
            Log.e(TAG, "Error refreshing active controller: ${e.message}")
            updateActiveController(null)
        }
    }

    private fun updateActiveController(newController: MediaController?) {
        if (currentController?.sessionToken == newController?.sessionToken) {
            if (newController == null) {
                emitCurrentPlayback()
            }
            return
        }
        currentController?.unregisterCallback(controllerCallback)
        currentController = newController
        currentController?.registerCallback(controllerCallback)
        emitCurrentPlayback()
    }

    private fun emitCurrentPlayback() {
        val sink = eventSink ?: return
        val controller = currentController
        if (controller == null) {
            sink.success(null)
            return
        }

        try {
            val metadata = controller.metadata
            val state = controller.playbackState

            val title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
                ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
                ?: ""
            val artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                ?: metadata?.getString(MediaMetadata.METADATA_KEY_AUTHOR)
                ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE)
                ?: ""
            val album = metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""
            val duration = metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L

            val isPlaying = state?.state == PlaybackState.STATE_PLAYING
            val position = state?.position ?: 0L
            val speed = (state?.playbackSpeed ?: 1.0f).toDouble()

            var artworkBytes: ByteArray? = null
            val bitmap = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
            if (bitmap != null) {
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 85, stream)
                artworkBytes = stream.toByteArray()
            }

            val map = hashMapOf<String, Any?>(
                "package" to controller.packageName,
                "title" to title,
                "artist" to artist,
                "album" to album,
                "artwork" to artworkBytes,
                "isPlaying" to isPlaying,
                "positionMs" to position,
                "durationMs" to duration,
                "speed" to speed,
                "updatedAt" to System.currentTimeMillis()
            )

            sink.success(map)
        } catch (e: Exception) {
            Log.e(TAG, "Error emitting playback: ${e.message}")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasAccess" -> {
                result.success(hasNotificationAccess())
            }
            "openAccessSettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            }
            "refresh" -> {
                refreshActiveController()
                result.success(true)
            }
            "play" -> {
                currentController?.transportControls?.play()
                result.success(true)
            }
            "pause" -> {
                currentController?.transportControls?.pause()
                result.success(true)
            }
            "next" -> {
                currentController?.transportControls?.skipToNext()
                result.success(true)
            }
            "previous" -> {
                currentController?.transportControls?.skipToPrevious()
                result.success(true)
            }
            "seekTo" -> {
                val pos = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                currentController?.transportControls?.seekTo(pos)
                result.success(true)
            }
            "stop" -> {
                currentController?.transportControls?.stop()
                result.success(true)
            }
            "playFromSearch" -> {
                val query = call.argument<String>("query") ?: ""
                currentController?.transportControls?.playFromSearch(query, null)
                result.success(true)
            }
            "openApp" -> {
                val pkg = currentController?.packageName
                if (pkg != null) {
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(pkg)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(launchIntent)
                        result.success(true)
                        return
                    }
                }
                result.success(false)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        attachSessionListenerIfPossible()
        refreshActiveController()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
