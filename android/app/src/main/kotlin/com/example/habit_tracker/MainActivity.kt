package com.example.habit_tracker

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var mediaSessionBridge: MediaSessionBridge? = null
    private var samsungHealthBridge: SamsungHealthBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaSessionBridge = MediaSessionBridge(this).apply {
            register(flutterEngine.dartExecutor.binaryMessenger)
        }
        samsungHealthBridge = SamsungHealthBridge(this).apply {
            register(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun onDestroy() {
        mediaSessionBridge?.unregister()
        mediaSessionBridge = null
        samsungHealthBridge?.unregister()
        samsungHealthBridge = null
        super.onDestroy()
    }
}
