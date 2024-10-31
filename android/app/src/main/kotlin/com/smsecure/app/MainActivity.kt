package com.smsecure.app

import android.content.pm.PackageManager
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.net.Uri // ADD THIS IMPORT
import androidx.core.content.ContextCompat
import androidx.core.app.ActivityCompat
import android.widget.Toast

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tarumt.smsecure/sms"
    private val REQUEST_CODE_SMS_DEFAULT = 12345

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkAndSetDefaultSmsApp()  // Call this method as soon as the activity is created
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkDefaultSms" -> {
                    val isDefault = Telephony.Sms.getDefaultSmsPackage(this) == packageName
                    result.success(isDefault)
                }
                "setDefaultSms" -> {
                    setAsDefaultSmsApp()
                    result.success(null)
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Check if the app is the default SMS handler and set it if it's not
    private fun checkAndSetDefaultSmsApp() {
        val isDefault = Telephony.Sms.getDefaultSmsPackage(this) == packageName
        if (!isDefault) {
            setAsDefaultSmsApp()
        }
    }

    // Prompt the user to set the app as the default SMS application
    private fun setAsDefaultSmsApp() {
        val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
        intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
        startActivityForResult(intent, REQUEST_CODE_SMS_DEFAULT)
    }

    // Handle the result of the default SMS app request
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_SMS_DEFAULT) {
            val isDefault = Telephony.Sms.getDefaultSmsPackage(this) == packageName
            if (isDefault) {
                // Now the app is the default SMS handler, proceed with permissions
                checkAndRequestPermissions()
            } else {
                // The user did not set the app as the default SMS handler
                Toast.makeText(this, "Please set the app as the default SMS handler.", Toast.LENGTH_SHORT).show()
            }
        }
    }

    // Opens the app's settings page
    private fun openAppSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            val uri = Uri.fromParts("package", packageName, null)
            intent.data = uri
            startActivity(intent)
        } catch (e: Exception) {
            println("Error opening app settings: ${e.message}")
        }
    }

    private fun checkAndRequestPermissions() {
        val requiredPermissions = arrayOf(
            Manifest.permission.READ_SMS,
            Manifest.permission.SEND_SMS,
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.RECEIVE_WAP_PUSH,
            Manifest.permission.RECEIVE_MMS
        )

        val permissionsToRequest = mutableListOf<String>()

        for (permission in requiredPermissions) {
            if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(permission)
            }
        }

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsToRequest.toTypedArray(), REQUEST_CODE_SMS_DEFAULT)
        } else {
            println("All necessary permissions are already granted.")
        }
    }

    // Handle the result of the permission request
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            REQUEST_CODE_SMS_DEFAULT -> {
                if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    println("All requested permissions granted.")
                } else {
                    Toast.makeText(this, "Permissions denied. Some features might not work.", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
}
