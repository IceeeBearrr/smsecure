package com.smsecure.app;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.util.Log;

import com.google.firebase.FirebaseApp;
import com.google.firebase.firestore.DocumentReference;
import com.google.firebase.firestore.FirebaseFirestore;

import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

public class SmsService extends Service {

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String senderNumber = intent.getStringExtra("senderNumber");
        String messageBody = intent.getStringExtra("messageBody");

        // Initialize Firebase if not already initialized
        initializeFirebase();

        // Store SMS data in Firestore
        storeSmsInFirestore(senderNumber, messageBody);

        // Stop the service after completing the task
        stopSelf();
        return START_NOT_STICKY;
    }

    private void initializeFirebase() {
        if (FirebaseApp.getApps(this).isEmpty()) {
            FirebaseApp.initializeApp(this);
            Log.d("SmsService", "Firebase initialized in background");
        }
    }

    private void storeSmsInFirestore(String senderNumber, String messageBody) {
        FirebaseFirestore firestore = FirebaseFirestore.getInstance();

        // Generate a unique conversation ID based on the sender's number
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
            if (task.isSuccessful() && !task.getResult().exists()) {
                // Create a new conversation if it doesn't exist
                Map<String, Object> conversationData = new HashMap<>();
                conversationData.put("conversationID", conversationID);

                // Convert participants array to List
                conversationData.put("participants", Arrays.asList(senderNumber, "YourAppUserID"));
                conversationData.put("createdAt", new Date());
                conversationData.put("lastMessageTimeStamp", new Date());

                conversationRef.set(conversationData)
                    .addOnSuccessListener(aVoid -> Log.d("SmsService", "Conversation created with ID: " + conversationID))
                    .addOnFailureListener(e -> Log.w("SmsService", "Error creating conversation", e));
            }

            // Add the message to the sub-collection
            conversationRef.collection("messages").add(messageData)
                .addOnSuccessListener(documentReference -> Log.d("SmsService", "Message stored with ID: " + documentReference.getId()))
                .addOnFailureListener(e -> Log.w("SmsService", "Error storing message", e));

            // Update lastMessageTimeStamp in the conversation document
            conversationRef.update("lastMessageTimeStamp", new Date())
                .addOnSuccessListener(aVoid -> Log.d("SmsService", "Conversation timestamp updated"))
                .addOnFailureListener(e -> Log.w("SmsService", "Error updating conversation timestamp", e));
        });
    }

    private String generateConversationID(String senderNumber) {
        return senderNumber.replaceAll("[^\\w]", "");
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
