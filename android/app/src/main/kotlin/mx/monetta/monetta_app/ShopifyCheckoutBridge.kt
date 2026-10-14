package mx.monetta.monetta_app

import android.net.Uri
import android.webkit.GeolocationPermissions
import android.webkit.PermissionRequest
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView
import com.shopify.checkoutsheetkit.CheckoutException
import com.shopify.checkoutsheetkit.CheckoutExpiredException
import com.shopify.checkoutsheetkit.CheckoutSheetKitDialog
import com.shopify.checkoutsheetkit.ConfigurationException
import com.shopify.checkoutsheetkit.DefaultCheckoutEventProcessor
import com.shopify.checkoutsheetkit.ErrorRecovery
import com.shopify.checkoutsheetkit.LogLevel
import com.shopify.checkoutsheetkit.ShopifyCheckoutSheetKit
import com.shopify.checkoutsheetkit.lifecycleevents.CheckoutCompletedEvent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class ShopifyCheckoutBridge(
    private val activity: MainActivity,
    messenger: BinaryMessenger,
) : DefaultCheckoutEventProcessor(activity), MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var pendingResult: MethodChannel.Result? = null
    private var checkoutDialog: CheckoutSheetKitDialog? = null

    // Offsite-payment return link (Fase 5). The OS may deliver the App Link
    // intent before Dart is listening (cold start), so the link stays pending
    // until the push or the `drainReturnLink` pull delivers it.
    private var pendingReturnLink: String? = null

    init {
        ShopifyCheckoutSheetKit.configure {
            it.logLevel = LogLevel.ERROR
            it.errorRecovery = object : ErrorRecovery {
                override fun shouldRecoverFromError(checkoutException: CheckoutException): Boolean = false
            }
        }
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "preload" -> {
                val checkoutUrl = checkoutUrl(call)
                if (checkoutUrl == null) {
                    result.error("invalid_checkout", null, null)
                    return
                }
                try {
                    ShopifyCheckoutSheetKit.preload(checkoutUrl, activity)
                } catch (_: Exception) {
                    result.error("unavailable", null, null)
                    return
                }
                result.success(null)
            }
            "present" -> present(call, result)
            "invalidate" -> {
                try {
                    ShopifyCheckoutSheetKit.invalidate()
                } catch (_: Exception) {
                    result.error("unavailable", null, null)
                    return
                }
                result.success(null)
            }
            "drainReturnLink" -> {
                val pending = pendingReturnLink
                pendingReturnLink = null
                if (pending == null) result.success(null)
                else result.success(mapOf("url" to pending))
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Forwards an OS-delivered App Link intent to Flutter for policy routing.
     * Validation lives in Dart ([CheckoutReturnPolicy]); anything unexpected
     * is rejected there. Overlong values are dropped before crossing.
     */
    fun handleReturnLink(uri: Uri?) {
        val raw = uri?.toString() ?: return
        if (raw.isEmpty() || raw.length > 4096) return
        pendingReturnLink = raw
        channel.invokeMethod(
            "onReturnLink",
            mapOf("url" to raw),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (pendingReturnLink == raw) pendingReturnLink = null
                }

                override fun error(code: String, message: String?, details: Any?) {
                    // Keep pending: Dart was not listening (cold start) and
                    // will pull it through `drainReturnLink`.
                }

                override fun notImplemented() {
                    // Same as error: keep pending for the drain pull.
                }
            },
        )
    }

    private fun present(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.success(failed("unavailable"))
            return
        }
        val checkoutUrl = checkoutUrl(call)
        if (checkoutUrl == null || activity.isFinishing || activity.isDestroyed) {
            result.success(failed("configuration"))
            return
        }
        pendingResult = result
        try {
            checkoutDialog = ShopifyCheckoutSheetKit.present(checkoutUrl, activity, this)
            if (checkoutDialog == null) finish(failed("unavailable"))
        } catch (_: Exception) {
            finish(failed("unavailable"))
        }
    }

    private fun checkoutUrl(call: MethodCall): String? {
        val raw = call.argument<String>("url") ?: return null
        if (raw.length > 4096 || raw.any { it == '\\' || it == '\n' || it == '\r' || it == '\u0000' || it.isWhitespace() }) return null
        if (hasAuthorityUserInfoMarker(raw)) return null
        val uri = runCatching { Uri.parse(raw) }.getOrNull() ?: return null
        if (
            uri.scheme != "https" ||
            uri.host.isNullOrBlank() ||
            uri.userInfo != null ||
            uri.fragment != null ||
            uri.port != -1 ||
            uri.path.isNullOrBlank() ||
            uri.path == "/"
        ) return null
        return raw
    }

    private fun hasAuthorityUserInfoMarker(raw: String): Boolean {
        val schemeEnd = raw.indexOf("://")
        if (schemeEnd < 0) return false
        val authorityStart = schemeEnd + 3
        val authorityEnd = raw.indexOfAny(charArrayOf('/', '?', '#', '\\'), authorityStart)
        val authority = raw.substring(
            authorityStart,
            if (authorityEnd < 0) raw.length else authorityEnd,
        )
        return authority.contains('@')
    }

    override fun onCheckoutCompleted(checkoutCompletedEvent: CheckoutCompletedEvent) {
        finish(mapOf("status" to "completed"))
    }

    override fun onCheckoutCanceled() {
        finish(mapOf("status" to "cancelled"))
    }

    override fun onCheckoutFailed(error: CheckoutException) {
        val code = when (error) {
            is CheckoutExpiredException -> when (error.errorCode) {
                "cart_expired" -> "cart_expired"
                "cart_completed" -> "cart_completed"
                "invalid_cart" -> "invalid_cart"
                else -> "unknown"
            }
            is ConfigurationException -> "configuration"
            else -> "unavailable"
        }
        finish(failed(code))
    }

    override fun onCheckoutLinkClicked(uri: Uri) {
        // External links remain denied until the audited return-link phase.
    }

    override fun onPermissionRequest(permissionRequest: PermissionRequest) {
        permissionRequest.deny()
    }

    override fun onShowFileChooser(
        webView: WebView,
        filePathCallback: ValueCallback<Array<Uri>>,
        fileChooserParams: WebChromeClient.FileChooserParams,
    ): Boolean {
        filePathCallback.onReceiveValue(null)
        return true
    }

    override fun onGeolocationPermissionsShowPrompt(
        origin: String,
        callback: GeolocationPermissions.Callback,
    ) {
        callback.invoke(origin, false, false)
    }

    private fun failed(code: String): Map<String, String> =
        mapOf("status" to "failed", "code" to code)

    private fun finish(value: Map<String, String>) {
        val result = pendingResult ?: return
        pendingResult = null
        checkoutDialog = null
        result.success(value)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        checkoutDialog?.dismiss()
        checkoutDialog = null
        finish(failed("unavailable"))
    }

    private companion object {
        const val CHANNEL_NAME = "mx.monetta.checkout_kit"
    }
}
