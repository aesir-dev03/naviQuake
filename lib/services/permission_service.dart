import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static const _permissionsRequestedKey = 'permissions_requested';
  
  static Future<Map<Permission, bool>> requestAllPermissions() async {
    // Add delay to ensure activity is initialized
    await Future.delayed(const Duration(milliseconds: 500));

    final Map<Permission, bool> results = {};
    
    // Request permissions one by one with delay between each
    for (var permission in [
      Permission.sms,
      Permission.notification,
      Permission.storage,
      Permission.location,
    ]) {
      try {
        final status = await permission.request();
        results[permission] = status.isGranted;
        // Small delay between requests
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        results[permission] = false;
      }
    }
    
    return results;
  }

  static Future<bool> arePermissionsGranted() async {
    return await Permission.sms.isGranted && 
           await Permission.notification.isGranted &&
           await Permission.storage.isGranted &&
           await Permission.location.isGranted;
  }

  static Future<void> markPermissionsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsRequestedKey, true);
  }

  static Future<bool> werePermissionsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionsRequestedKey) ?? false;
  }
}
