package mx.monetta.monetta_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var checkoutBridge: ShopifyCheckoutBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        checkoutBridge = ShopifyCheckoutBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Cold-start return from an offsite payment: Dart pulls it through
        // `drainReturnLink` once listening; the push below is a no-op then.
        checkoutBridge?.handleReturnLink(intent?.data)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Warm return while the app lives: forwarded for policy routing.
        // The URL alone never proves payment; Dart re-presents checkout.
        checkoutBridge?.handleReturnLink(intent.data)
    }

    override fun onDestroy() {
        checkoutBridge?.dispose()
        checkoutBridge = null
        super.onDestroy()
    }
}
