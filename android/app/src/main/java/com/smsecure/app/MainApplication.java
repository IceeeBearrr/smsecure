package com.smsecure.app;

import android.app.Application;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.FlutterEngineCache;

public class MainApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();

        // Initialize the Flutter engine
        FlutterEngine flutterEngine = new FlutterEngine(this);

        // Start executing Dart code
        flutterEngine.getDartExecutor().executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
        );

        // Cache the Flutter engine for use in the SmsReceiver
        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine);
    }
}
