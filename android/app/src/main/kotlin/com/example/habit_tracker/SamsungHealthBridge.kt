package com.example.habit_tracker

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SamsungHealthBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private val samsungHealthPackage = "com.sec.android.app.shealth"
    private val healthConnectPackage = "com.google.android.apps.healthdata"

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "habit/samsung_health").apply {
            setMethodCallHandler(this@SamsungHealthBridge)
        }
    }

    fun unregister() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isAvailable" -> {
                    val sHealthInstalled = isPackageInstalled(samsungHealthPackage)
                    val hcInstalled = isPackageInstalled(healthConnectPackage)
                    result.success(
                        mapOf(
                            "isAvailable" to (sHealthInstalled || hcInstalled),
                            "samsungHealthInstalled" to sHealthInstalled,
                            "healthConnectInstalled" to hcInstalled,
                            "packageName" to samsungHealthPackage
                        )
                    )
                }

                "checkPermissions" -> {
                    val sHealthInstalled = isPackageInstalled(samsungHealthPackage)
                    // Real check: Permissions must be explicitly granted by user in Samsung Health Data SDK.
                    // Without the SDK AAR paired, default to false so simulated data never masquerades as granted.
                    result.success(
                        mapOf(
                            "activity" to false,
                            "sleep" to false,
                            "exercise" to false,
                            "body_composition" to false,
                            "energy_score" to false,
                            "ages_index" to false
                        )
                    )
                }

                "requestPermissions" -> {
                    val intent = activity.packageManager.getLaunchIntentForPackage(samsungHealthPackage)
                    if (intent != null) {
                        activity.startActivity(intent)
                        result.success(true)
                    } else {
                        try {
                            val marketIntent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$samsungHealthPackage"))
                            activity.startActivity(marketIntent)
                            result.success(false)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }

                "openSamsungHealth" -> {
                    val intent = activity.packageManager.getLaunchIntentForPackage(samsungHealthPackage)
                    if (intent != null) {
                        activity.startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }

                "readDailyActivity",
                "readSleep",
                "readExercises",
                "readBodyComposition",
                "readEnergyScore",
                "readAgesIndex" -> {
                    // Do not fabricate health data. Return typed not_implemented error
                    // until Samsung Health Data SDK AAR is placed in libs/ and paired.
                    result.error(
                        "not_implemented",
                        "Samsung Health Data SDK integration pending AAR library placement. Connect via Health Connect or enable Demo Simulator.",
                        null
                    )
                }

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("SAMSUNG_HEALTH_ERROR", e.message, null)
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            activity.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
}
