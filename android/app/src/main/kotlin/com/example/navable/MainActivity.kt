package com.example.navable

import io.flutter.embedding.android.FlutterActivity
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "navable/maps_config")
            .setMethodCallHandler { call, result ->
                if (call.method == "isConfigured") {
                    val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    val key = info.metaData?.getString("com.google.android.geo.API_KEY").orEmpty()
                    result.success(key.isNotBlank() && key != "YOUR_API_KEY")
                } else {
                    result.notImplemented()
                }
            }
    }
}
