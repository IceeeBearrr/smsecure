package com.smsecure.app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.provider.Telephony;
import android.telephony.SmsMessage;
import android.util.Log;
import android.widget.Toast;

public class SmsReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION.equals(intent.getAction())) {
            for (SmsMessage smsMessage : Telephony.Sms.Intents.getMessagesFromIntent(intent)) {
                if (smsMessage != null) {
                    String messageBody = smsMessage.getMessageBody();
                    String senderNumber = smsMessage.getDisplayOriginatingAddress();

                    Log.d("SmsReceiver", "Received SMS from: " + senderNumber + ", Message: " + messageBody);
                    Toast.makeText(context, "Received SMS: " + messageBody + " from " + senderNumber, Toast.LENGTH_LONG).show();

                    // Start a Service to handle the Firestore logic
                    Intent serviceIntent = new Intent(context, SmsService.class);
                    serviceIntent.putExtra("senderNumber", senderNumber);
                    serviceIntent.putExtra("messageBody", messageBody);
                    context.startService(serviceIntent);
                }
            }
        }
    }
}
