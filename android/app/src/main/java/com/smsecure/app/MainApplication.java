package com.smsecure.app;

import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;
import com.google.firebase.FirebaseApp;

public class MainApplication extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        FirebaseApp.initializeApp(this);
    }
}
