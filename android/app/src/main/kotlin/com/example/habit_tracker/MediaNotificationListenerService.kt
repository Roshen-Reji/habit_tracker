package com.example.habit_tracker

import android.content.ComponentName
import android.content.Context
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.os.Build
import android.service.notification.NotificationListenerService
import android.util.Log

class MediaNotificationListenerService : NotificationListenerService() {
    companion object {
        private const val TAG = "MediaNotifListener"
        var instance: MediaNotificationListenerService? = null
            private set

        fun getComponentName(context: Context): ComponentName {
            return ComponentName(context, MediaNotificationListenerService::class.java)
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        Log.d(TAG, "Notification listener connected")
        MediaSessionBridge.instance?.onNotificationListenerConnected()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        instance = null
        Log.d(TAG, "Notification listener disconnected")
        MediaSessionBridge.instance?.onNotificationListenerDisconnected()
    }

    fun getActiveControllers(): List<MediaController> {
        val mm = getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
            ?: return emptyList()
        return try {
            mm.getActiveSessions(getComponentName(this))
        } catch (e: Exception) {
            Log.e(TAG, "Error getting active sessions: ${e.message}")
            emptyList()
        }
    }
}
