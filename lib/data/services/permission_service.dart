import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static Future<bool> requestAllPermissions() async {
    // Browser builds cannot read `Platform.environment`, and browser
    // permission requests are not part of the native permission flow.
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }

    // Request all potential permissions
    List<Permission> permissions = [
      Permission.notification,
      Permission.storage,
      Permission.scheduleExactAlarm,
    ];

    await permissions.request();

    // Only strictly require notification permission for the app to function well
    // Storage/Audio are OS-dependent and often return permanentlyDenied on incompatible OS versions.
    if (await Permission.notification.isGranted) {
      return true;
    }

    return false;
  }

  static Future<void> checkAndRequestPermissions(BuildContext context) async {
    bool granted = await requestAllPermissions();
    if (!granted && context.mounted) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1C1C1E),
                title: const Text("Permissions Required",
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold)),
                content: const Text(
                    "Some permissions were denied. App functionality like notifications and music might be limited. Please enable them in Settings.",
                    style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel",
                          style: TextStyle(color: Colors.white54))),
                  TextButton(
                      onPressed: () {
                        openAppSettings();
                        Navigator.pop(context);
                      },
                      child: const Text("Open Settings",
                          style: TextStyle(color: Colors.tealAccent))),
                ],
              ));
    }
  }
}
