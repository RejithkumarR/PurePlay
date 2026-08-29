package com.pureplay.localplayer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var mediaScannerPlugin: MediaScannerPlugin? = null

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        mediaScannerPlugin = MediaScannerPlugin(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger
        )
    }

    override fun onDestroy() {
        mediaScannerPlugin = null
        super.onDestroy()
    }
}