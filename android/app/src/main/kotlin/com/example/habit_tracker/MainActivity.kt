package com.example.habit_tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var mediaSessionBridge: MediaSessionBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaSessionBridge = MediaSessionBridge(this).apply {
            register(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun onDestroy() {
        mediaSessionBridge?.unregister()
        mediaSessionBridge = null
        super.onDestroy()
    }
}
