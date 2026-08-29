/// Build-time configuration for the owner-only control panel.
///
/// The email allow-list only decides whether the entry point is rendered. It
/// is not an authorization boundary: the admin service must validate the
/// Shopify Customer access token and enforce the same owner role server-side.
library;

class AdminConfig {
  const AdminConfig({
    required this.baseUrl,
    required this.ownerEmails,
    this.previewEnabled = false,
  });

  factory AdminConfig.fromEnvironment() {
    const rawBaseUrl = String.fromEnvironment('ADMIN_API_BASE_URL');
    const rawEmails = String.fromEnvironment('OWNER_ADMIN_EMAILS');
    const preview = bool.fromEnvironment('ENABLE_OWNER_ADMIN_PREVIEW');

    return AdminConfig(
      baseUrl: rawBaseUrl.trim().isEmpty ? null : Uri.tryParse(rawBaseUrl),
      ownerEmails: rawEmails
          .split(',')
          .map((email) => email.trim().toLowerCase())
          .where((email) => email.isNotEmpty)
          .toSet(),
      previewEnabled: preview,
    );
  }

  const AdminConfig.disabled()
      : baseUrl = null,
        ownerEmails = const {},
        previewEnabled = false;

  final Uri? baseUrl;
  final Set<String> ownerEmails;

  /// Enables the owner UI without a writable backend for design review.
  /// Mutations remain local to the in-memory admin view in this mode.
  final bool previewEnabled;

  bool get hasLiveApi => baseUrl != null;
  bool get hasConfiguredOwners => ownerEmails.isNotEmpty;

  bool allowsEmail(String? email) {
    final normalized = email?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return false;
    return ownerEmails.contains(normalized);
  }
}
