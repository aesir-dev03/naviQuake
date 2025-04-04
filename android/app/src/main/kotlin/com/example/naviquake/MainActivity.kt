package com.example.naviquake

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.util.Log // Import Log
import android.os.Bundle
import androidx.annotation.NonNull
import java.lang.ref.WeakReference

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.naviquake/permissions"
    private val PERMISSION_REQUEST_CODE = 123

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestStoragePermission" -> {
                    checkAndRequestPermission(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkAndRequestPermission(result: MethodChannel.Result) {
        try {
            if (isFinishing || isDestroyed) {
                    result.error("INVALID_CONTEXT", "Activity not available", null)
                    return
                }
                if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                result.success(true)
            } else {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    PERMISSION_REQUEST_CODE
                )
                permissionResult = result
            }
        } catch (e: Exception) {
            result.error("PERMISSION_ERROR", "Permission check failed: ${e.message}", null)
        }
    }

    private var permissionResult: MethodChannel.Result? = null

    override fun onDestroy() {
        super.onDestroy()
        permissionResult = null
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && 
                         grantResults[0] == PackageManager.PERMISSION_GRANTED
            
            // Use the stored result
            if (!isFinishing && !isDestroyed) {
                permissionResult?.success(granted)
            } else {
                permissionResult?.error("INVALID_CONTEXT", "Activity not available", null)
            }
            permissionResult = null // Clear the stored result
        }
    }


}
