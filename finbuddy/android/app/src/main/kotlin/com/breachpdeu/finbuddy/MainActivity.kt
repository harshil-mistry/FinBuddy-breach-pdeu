package com.breachpdeu.finbuddy

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.breachpdeu.finbuddy/upi"
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startUpiPayment") {
                val uriStr = call.argument<String>("uri")
                if (uriStr != null) {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_VIEW)
                    intent.data = Uri.parse(uriStr)
                    
                    val chooser = Intent.createChooser(intent, "Pay with...")
                    try {
                        startActivityForResult(chooser, 1001)
                    } catch (e: Exception) {
                        result.error("NO_APP_FOUND", "No UPI apps installed.", null)
                        pendingResult = null
                    }
                } else {
                    result.error("INVALID_URI", "URI cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1001) {
            if (data != null) {
                // UPI apps return the data string in 'response' Extra
                val res = data.getStringExtra("response") ?: ""
                pendingResult?.success(res.lowercase())
            } else {
                // Provide a default string when standard UPI app cancel drops data
                pendingResult?.success("canceled")
            }
            pendingResult = null
        }
    }
}
