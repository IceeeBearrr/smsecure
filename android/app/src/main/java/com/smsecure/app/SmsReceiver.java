package com.smsecure.app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.provider.Telephony;
import android.telephony.SmsMessage;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.FlutterEngine;
import java.util.HashMap;

public class SmsReceiver extends BroadcastReceiver {
    private static final String CHANNEL = "com.smsecure.app/sms";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION.equals(intent.getAction())) {
            SmsMessage[] messages = Telephony.Sms.Intents.getMessagesFromIntent(intent);
            if (messages != null && messages.length > 0) {
                // Extract SMS content
                StringBuilder messageBody = new StringBuilder();
                String senderNumber = messages[0].getOriginatingAddress();

                for (SmsMessage message : messages) {
                    messageBody.append(message.getMessageBody());
                }

                System.out.println("Received SMS from: " + senderNumber + ", Message: " + messageBody);

                // Check FlutterEngine registration
                FlutterEngine flutterEngine = FlutterEngineCache.getInstance().get("my_engine_id");
                if (flutterEngine == null) {
                    System.err.println("FlutterEngine is null. Ensure it is initialized in MainApplication.");
                    return;
                }

                // Send data to Flutter via MethodChannel
                MethodChannel methodChannel = new MethodChannel(
                        flutterEngine.getDartExecutor(),
                        CHANNEL
                );

                HashMap<String, String> smsData = new HashMap<>();
                smsData.put("senderNumber", senderNumber != null ? senderNumber : "Unknown Sender");
                smsData.put("messageBody", messageBody.toString());

                try {
                    methodChannel.invokeMethod("onSmsReceived", smsData);
                } catch (Exception e) {
                    System.err.println("Error invoking Flutter method: " + e.getMessage());
                }
            } else {
                System.out.println("No SMS messages received or messages array is null.");
            }
        } else {
            System.out.println("Unexpected action received: " + intent.getAction());
        }
    }
}
