import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static Future<bool> requestAllPermissions() async {
    // Determine which permissions are required based on Android version
    List<Permission> permissions = [
      Permission.notification,
    ];

    // For Android 13+
    if (await Permission.audio.isRestricted || await Permission.audio.isDenied) {
      permissions.add(Permission.audio);
    } else {
      // For older Android versions
      permissions.add(Permission.storage);
    }
    
    // We can also request scheduling exact alarms (handled differently in Android 14+)
    permissions.add(Permission.scheduleExactAlarm);

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool allGranted = true;
    for (var status in statuses.values) {
      if (!status.isGranted) {
        allGranted = false;
        break;
      }
    }

    return allGranted;
  }

  static Future<void> checkAndRequestPermissions(BuildContext context) async {
    bool granted = await requestAllPermissions();
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Some permissions were denied. App functionality may be limited."),
          backgroundColor: Colors.redAccent,
        )
      );
    }
  }
}
