package com.example.example


import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.content.pm.PackageManager
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.geo/navigation"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getApiKey") {
                try {
                    val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    val apiKey = appInfo.metaData.getString("com.google.android.geo.API_KEY")
                    result.success(apiKey)
                } catch (e: PackageManager.NameNotFoundException) {
                    Log.e("MainActivity", "Error retrieving API key", e)
                    result.error("UNAVAILABLE", "API Key not found", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

