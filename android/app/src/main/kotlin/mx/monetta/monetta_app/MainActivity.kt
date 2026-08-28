package mx.monetta.monetta_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var checkoutBridge: ShopifyCheckoutBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        checkoutBridge = ShopifyCheckoutBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        checkoutBridge?.dispose()
        checkoutBridge = null
        super.onDestroy()
    }
}
