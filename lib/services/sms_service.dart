import 'dart:async';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  final SmsQuery _query = SmsQuery();
  final _smsController = StreamController<SmsMessage>.broadcast();
  final Set<String> _numbersToMonitor = {};
  Timer? _pollingTimer;

  Stream<SmsMessage> get onSmsReceived => _smsController.stream;
  DateTime? _lastCheckTime;

  Future<bool> initialize() async {
    try {
      final permission = await Permission.sms.request();
      if (!permission.isGranted) {
        final status = await Permission.sms.status;
        if (status.isPermanentlyDenied) {
          return false;
        }
        return false;
      }
      _startPolling();
      return true;
    } catch (e) {
      print('SMS initialization error: $e');
      return false;
    }
  }

  void addNumberToMonitor(String phoneNumber) {
    _numbersToMonitor.add(phoneNumber);
  }

  void _startPolling() {
    _lastCheckTime = DateTime.now();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkNewMessages());
  }

  Future<void> _checkNewMessages() async {
    if (!await Permission.sms.isGranted) {
      return;
    }
    
    try {
      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 10,
      );

      if (_lastCheckTime != null && messages.isNotEmpty) {
        for (var message in messages) {
          // Only process messages from monitored numbers
          if (message.date != null && 
              message.date!.isAfter(_lastCheckTime!) &&
              _numbersToMonitor.contains(message.address?.replaceAll(RegExp(r'[^\d+]'), ''))) {
            print('Received message from monitored number: ${message.address}');
            _smsController.add(message);
          }
        }
      }
      
      _lastCheckTime = DateTime.now();
    } catch (e) {
      print('Error checking SMS: $e');
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
    _smsController.close();
  }
}
