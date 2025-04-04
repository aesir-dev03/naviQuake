import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundServiceHelper {
  static const String _lastUpdateKey = 'background_service_last_update';

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Configure the background service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: false, // Run in background mode without notification
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        // Update last run timestamp
        await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
        
        service.invoke(
          'update',
          {
            "timestamp": DateTime.now().toIso8601String(),
            "is_running": true
          },
        );
      }
    });
  }

  // Add method to check service status
  static Future<Map<String, dynamic>> getServiceStatus() async {
    final service = FlutterBackgroundService();
    final prefs = await SharedPreferences.getInstance();
    final isRunning = await service.isRunning();
    final lastUpdate = prefs.getString(_lastUpdateKey);

    return {
      'isRunning': isRunning,
      'lastUpdate': lastUpdate != null ? DateTime.parse(lastUpdate) : null,
    };
  }
}
