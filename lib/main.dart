import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'pages/homepage.dart';
import 'pages/alarm-page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/sms_service.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'services/background_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> initializeNotifications() async {
  await _configureLocalTimeZone();
  
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (context) => const AlarmPage()),
      );
    },
  );

  // Create notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'earthquake_alerts',
    'Earthquake Alerts',
    description: 'Channel for earthquake alerts',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> _configureLocalTimeZone() async {
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));
}

Future<void> showNotification({
  String title = 'Earthquake Alert',
  String body = 'Tap to view emergency information'
}) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'earthquake_alerts',
    'Earthquake Alerts',
    channelDescription: 'Channel for earthquake alerts',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true,
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    details,
  );
}

final smsService = SmsService();

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize background service
    await BackgroundServiceHelper.initializeService();
    
    await initializeNotifications();
    final bool smsInitialized = await smsService.initialize();
    
    if (smsInitialized) {
      // Add the specific phone number you want to monitor
      smsService.addNumberToMonitor('+639310236050'); // Replace with your number
      
      smsService.onSmsReceived.listen(
        (message) async {
          try {
            // Show notification when message is received from monitored number
            await showNotification(
              title: 'Earthquake Alert!',
              body: 'Received Earthquake Alert From Arduino Mobile Phone Number: ${message.address}',
            );
          } catch (e) {
            debugPrint('Failed to show notification: $e');
          }
        },
        onError: (error) {
          debugPrint('SMS listener error: $error');
        },
      );
    }

    runApp(const MyApp());
  } catch (e) {
    debugPrint('Error: $e');
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
    );
  }
}
