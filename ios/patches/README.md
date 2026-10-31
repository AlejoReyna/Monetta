# Shopify numeric customer subjects

The iPhone staging login returned a three-part RS256 ID token with an integer
`sub` on 2026-10-13. AppAuth 2.0.0 maps `sub` only to NSString, rejects that
required field, and returns error -14 (`ID Token parsing failed`).

`appauth_numeric_subject.rb` runs from the Podfile's `post_install`. It adds a
conversion for positive integer subjects to AppAuth's parsed subject mapping.
It leaves the original JWT, original claims, and AppAuth's issuer, audience,
expiry, issued-at and nonce validation unchanged. Boolean and floating-point
subjects are rejected. Existing string subjects keep their original behavior.
The patch is idempotent and fails the build if the pinned AppAuth version or
source changes, so upgrades require reviewing this compatibility fix.

The Dart identity fallback also accepts a positive integer subject. Customer
Account API identity remains the primary source.

After `cd ios && pod install`, run the native regression test from the repo root:

```sh
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror \
  -I ios/Pods/AppAuth/Sources/AppAuthCore -framework Foundation \
  ios/patches/appauth_numeric_subject_test.m \
  ios/Pods/AppAuth/Sources/AppAuthCore/OIDIDToken.m \
  ios/Pods/AppAuth/Sources/AppAuthCore/OIDFieldMapping.m \
  -o /tmp/monetta_appauth_numeric_subject_test
/tmp/monetta_appauth_numeric_subject_test
flutter test test/data/customer_auth
```
