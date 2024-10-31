package com.smsecure.app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.provider.Telephony;
import android.telephony.SmsMessage;
import android.util.Log;
import android.widget.Toast;

import com.google.firebase.firestore.DocumentReference;
import com.google.firebase.firestore.FirebaseFirestore;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;


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

                    // Store message in Firestore
                    storeSmsInFirestore(senderNumber, messageBody);
                }
            }
        }
    }

    private void storeSmsInFirestore(String senderNumber, String messageBody) {
        FirebaseFirestore firestore = FirebaseFirestore.getInstance();

        // Generate a unique conversation ID based on sender's number
        String conversationID = generateConversationID(senderNumber);

        // Create a reference to the conversation document
        DocumentReference conversationRef = firestore.collection("conversations").document(conversationID);

        // Prepare message data
        Map<String, Object> messageData = new HashMap<>();
        messageData.put("senderID", senderNumber);
        messageData.put("receiverID", "YourAppUserID"); // Set your app user ID or phone number here
        messageData.put("content", messageBody);
        messageData.put("timestamp", new Date());
        messageData.put("isIncoming", true);

        // Update or create conversation and add message
        conversationRef.get().addOnCompleteListener(task -> {
            if (task.isSuccessful()) {
                if (!task.getResult().exists()) {
                    // Create a new conversation if it doesn't exist
                    Map<String, Object> conversationData = new HashMap<>();
                    conversationData.put("conversationID", conversationID);
                    conversationData.put("participants", new String[]{senderNumber, "YourAppUserID"});
                    conversationData.put("createdAt", new Date());
                    conversationData.put("lastMessageTimeStamp", new Date());

                    conversationRef.set(conversationData)
                        .addOnSuccessListener(aVoid -> Log.d("SmsReceiver", "Conversation created with ID: " + conversationID))
                        .addOnFailureListener(e -> Log.w("SmsReceiver", "Error creating conversation", e));
                }

                // Add the message to the sub-collection
                conversationRef.collection("messages").add(messageData)
                    .addOnSuccessListener(documentReference -> Log.d("SmsReceiver", "Message stored with ID: " + documentReference.getId()))
                    .addOnFailureListener(e -> Log.w("SmsReceiver", "Error storing message", e));

                // Update lastMessageTimeStamp in the conversation document
                conversationRef.update("lastMessageTimeStamp", new Date())
                    .addOnSuccessListener(aVoid -> Log.d("SmsReceiver", "Conversation timestamp updated"))
                    .addOnFailureListener(e -> Log.w("SmsReceiver", "Error updating conversation timestamp", e));
            } else {
                Log.w("SmsReceiver", "Failed to retrieve conversation", task.getException());
            }
        });
    }

    private String generateConversationID(String senderNumber) {
        return senderNumber.replaceAll("[^\\w]", "");
    }
}
