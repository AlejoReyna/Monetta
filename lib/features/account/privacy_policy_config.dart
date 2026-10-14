/// Public privacy-policy URL. Override with `--dart-define=PRIVACY_POLICY_URL=`.
/// The default is a placeholder until the published policy URL is set.
library;

class PrivacyPolicyConfig {
  const PrivacyPolicyConfig(this.url);

  final Uri url;

  static const String placeholder = 'https://monetta.mx/politica-de-privacidad';

  factory PrivacyPolicyConfig.fromEnvironment() {
    const raw = String.fromEnvironment(
      'PRIVACY_POLICY_URL',
      defaultValue: placeholder,
    );
    return PrivacyPolicyConfig(parse(raw));
  }

  static Uri parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return Uri.parse(placeholder);
    }
    return uri;
  }
}
