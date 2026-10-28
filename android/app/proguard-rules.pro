# Release R8 rules for `flutter build appbundle --release`.
# Flutter 3.44 enables minify on the release build type and also appends
# packages/flutter_tools/gradle/flutter_proguard_rules.pro. The copy below
# matches Flutter 3.44.8 so plugin classes stay even if that hook does not
# run under AGP 9. Firebase Android artifacts and Checkout Sheet Kit ship
# their own consumer rules (Checkout Sheet Kit keeps
# com.shopify.checkoutsheetkit.**). Do not blanket-keep those packages here.

# --- Flutter embedding (same rules as Flutter 3.44.8 flutter_proguard_rules.pro)

-dontwarn io.flutter.plugin.**
-dontwarn android.**

# https://github.com/flutter/flutter/issues/154580
-if class * implements io.flutter.embedding.engine.plugins.FlutterPlugin
-keep,allowshrinking,allowobfuscation class <1>

# --- App native code. Checkout behavior is unchanged; R8 must not strip the
# method channel that presents Checkout Sheet Kit.

-keep class mx.monetta.monetta_app.MainActivity { *; }
-keep class mx.monetta.monetta_app.ShopifyCheckoutBridge { *; }

# Customer Account login returns through AppAuth. The redirect activity is
# declared only in the flutter_appauth manifest and is easy for R8 to treat
# as unused.

-keep class net.openid.appauth.RedirectUriReceiverActivity { *; }
-keep class net.openid.appauth.** { *; }

# flutter_local_notifications receivers are named from AndroidManifest.xml.
# Gson models inside that plugin are reflection-loaded.

-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Play Console / Crashlytics stack traces.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
