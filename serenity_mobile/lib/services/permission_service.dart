import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<Map<Permission, PermissionStatus>>
      requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.contacts,
      Permission.phone,
      Permission.sms,
      Permission.notification,
      Permission.systemAlertWindow,
    ].request();

    return statuses;
  }

  static Future<bool> checkAndRequestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await requestAllPermissions();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    return allGranted;
  }
}
