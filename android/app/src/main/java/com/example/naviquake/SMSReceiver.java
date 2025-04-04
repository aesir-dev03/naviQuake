package com.example.naviquake;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.telephony.SmsMessage;
import android.util.Log;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.view.FlutterMain;
import java.util.HashMap;

public class SMSReceiver extends BroadcastReceiver {
    private static final String TAG = "SMSReceiver";
    private static final String CHANNEL = "com.naviquake/sms";
    private static MethodChannel channel;

    @Override
    public void onReceive(Context context, Intent intent) {
        Log.d(TAG, "SMSReceiver.onReceive");
        if (intent.getAction().equals("android.provider.Telephony.SMS_RECEIVED")) {
            Bundle bundle = intent.getExtras();
            if (bundle != null) {
                try {
                    Object[] pdus = (Object[]) bundle.get("pdus");
                    if (pdus != null) {
                        final SmsMessage[] messages = new SmsMessage[pdus.length];
                        for (int i = 0; i < pdus.length; i++) {
                            messages[i] = SmsMessage.createFromPdu((byte[]) pdus[i]);
                        }
                        if (messages.length > -1) {
                            Log.i(TAG, "Message received: " + messages[0].getMessageBody());
                            String senderNum = messages[0].getOriginatingAddress();
                            String messageBody = messages[0].getMessageBody();

                            // Initialize FlutterMain
                            FlutterMain.startInitialization(context);
                            FlutterMain.ensureInitializationComplete(context, null);

                            // Get FlutterEngine from cache
                            String engineId = "background_engine"; // Replace with your engine ID
                            FlutterEngine flutterEngine = FlutterEngineCache.getInstance().get(engineId);

                            if (flutterEngine == null) {
                                // Create a new FlutterEngine if it doesn't exist
                                flutterEngine = new FlutterEngine(context);
                                flutterEngine.getDartExecutor().executeDartEntrypoint(
                                        DartExecutor.DartEntrypoint.createDefault()
                                );
                                FlutterEngineCache.getInstance().put(engineId, flutterEngine);
                            }

                            // Set up method channel
                            channel = new MethodChannel(flutterEngine.getDartExecutor(), CHANNEL);

                            // Prepare arguments for the method channel
                            HashMap<String, String> smsData = new HashMap<>();
                            smsData.put("sender", senderNum);
                            smsData.put("message", messageBody);

                            // Invoke method on Flutter side with the HashMap
                            channel.invokeMethod("smsReceived", smsData);
                        }
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Exception: " + e);
                }
            }
        }
    }
}
