/// Eliminación de cuenta iniciada desde Cuenta → Privacidad y datos.
///
/// El servidor decide si hay un pedido abierto, exige un inicio de sesión
/// reciente y pide el borrado. Esta pantalla no habla con Shopify Admin.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/shopper_copy.dart';
import '../../data/accounts_orders/account_deletion_client.dart';
import '../../data/accounts_orders/accounts_orders_config.dart';
import '../../data/customer_auth/customer_auth_error.dart';
import '../boutique/boutique_tokens.dart';
import 'account_boutique.dart';

const String kDeleteAccountSuccess =
    'Tu cuenta fue eliminada. Tus datos de compra se borrarán en un proceso '
    'que puede tardar hasta 6 meses.';

const String kDeleteAccountBlocked =
    'Tienes un pedido en curso. Podrás eliminar tu cuenta cuando se complete.';

const String kDeleteAccountRefundBlocked =
    'Tienes un reembolso en proceso. Podrás eliminar tu cuenta cuando se complete.';

String deleteAccountRefundReviewMessage(String orderNumber) =>
    'Necesitamos revisar un reembolso de tu pedido $orderNumber antes de eliminar tu cuenta.';

const String kDeleteAccountEmailMismatchTitle = 'Entraste con otra cuenta';

String deleteAccountEmailMismatchBody(String maskedEmail) =>
    'Para eliminar tu cuenta, inicia sesión con $maskedEmail. No se eliminó nada.';

const String kDeleteAccountReauthTitle =
    'Vuelve a iniciar sesión para continuar';

const String kDeleteAccountReauthBody =
    'Por seguridad, antes de eliminar tu cuenta necesitamos que entres de nuevo '
    'con tu cuenta de Monetta.';

const String kDeleteAccountOrderCheckTitle = 'No pudimos revisar tus pedidos';

const String kDeleteAccountOrderCheckBody =
    'No se eliminó nada. Inténtalo más tarde.';

const String kDeleteAccountTooManyTitle =
    'Necesitamos ayudarte con esta solicitud';

const String kDeleteAccountTooManyBody =
    'Tu cuenta tiene muchos pedidos y no podemos eliminarla desde la app. '
    'Escríbenos y lo hacemos por ti.';

const String kDeleteAccountError =
    'No pudimos eliminar tu cuenta. Intenta de nuevo o escríbenos.';

const String kDeleteAccountOffline =
    'Necesitas conexión para eliminar tu cuenta.';

const String kDeleteAccountSlow = 'Esto está tardando más de lo normal.';

Future<void> openDeleteAccount(
  BuildContext context, {
  required Future<String?> Function() accessToken,
  required Future<FreshCustomerLogin> Function() reauthenticate,
  required Future<void> Function() signOutToHome,
  required void Function(AccountDeletionOrderRef order) onViewOrder,
  Future<LegacyDeletionSignIn> Function()? signInForDeletion,
  Future<void> Function()? abandonUnmatchedLogin,
  AccountDeletionClient? client,
  Uri? supportUri,
  Duration confirmDelay = const Duration(seconds: 2),
  Duration slowAfter = const Duration(seconds: 10),
  Future<bool> Function(Uri uri)? openUri,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DeleteAccountScreen(
        accessToken: accessToken,
        reauthenticate: reauthenticate,
        signOutToHome: signOutToHome,
        onViewOrder: onViewOrder,
        signInForDeletion: signInForDeletion,
        abandonUnmatchedLogin: abandonUnmatchedLogin,
        client: client,
        supportUri: supportUri ?? accountDeletionSupportUri(),
        confirmDelay: confirmDelay,
        slowAfter: slowAfter,
        openUri: openUri,
      ),
    ),
  );
}

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({
    required this.accessToken,
    required this.reauthenticate,
    required this.signOutToHome,
    required this.onViewOrder,
    this.signInForDeletion,
    this.abandonUnmatchedLogin,
    this.client,
    this.supportUri,
    this.confirmDelay = const Duration(seconds: 2),
    this.slowAfter = const Duration(seconds: 10),
    this.openUri,
    super.key,
  });

  final Future<String?> Function() accessToken;
  final Future<FreshCustomerLogin> Function() reauthenticate;
  final Future<void> Function() signOutToHome;
  final void Function(AccountDeletionOrderRef order) onViewOrder;
  final Future<LegacyDeletionSignIn> Function()? signInForDeletion;
  final Future<void> Function()? abandonUnmatchedLogin;
  final AccountDeletionClient? client;
  final Uri? supportUri;
  final Duration confirmDelay;
  final Duration slowAfter;
  final Future<bool> Function(Uri uri)? openUri;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

enum _Phase {
  info,
  loading,
  blocked,
  error,
  offline,
  success,
  reauth,
  orderCheck,
  tooManyOrders,
  emailMismatch,
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  AccountDeletionClient? _ownedClient;
  _Phase _phase = _Phase.info;
  bool _slow = false;
  AccountDeletionOrderRef? _blockedOrder;
  Timer? _slowTimer;
  FreshCustomerLogin? _freshLogin;
  String? _legacySessionToken;
  String? _maskedEmail;

  AccountDeletionClient get _deletionClient {
    final injected = widget.client;
    if (injected != null) return injected;
    return _ownedClient ??= HttpAccountDeletionClient(
      baseUrl: AccountsOrdersConfig.fromEnvironment().baseUrl,
    );
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    if (widget.client == null) _ownedClient?.close();
    if (_phase == _Phase.emailMismatch) {
      final abandon = widget.abandonUnmatchedLogin;
      if (abandon != null) unawaited(abandon());
    }
    super.dispose();
  }

  void _setLoading(bool loading) {
    _slowTimer?.cancel();
    _slow = false;
    if (!loading) return;
    _slowTimer = Timer(widget.slowAfter, () {
      if (!mounted) return;
      setState(() => _slow = true);
    });
  }

  Future<void> _continue() async {
    setState(() => _phase = _Phase.loading);
    _setLoading(true);
    final freshToken = _freshLogin?.accessToken.trim();
    final token = freshToken != null && freshToken.isNotEmpty
        ? freshToken
        : await widget.accessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      _setLoading(false);
      setState(() => _phase = _Phase.error);
      return;
    }
    final outcome = await _deletionClient.precheck(token);
    if (!mounted) return;
    _setLoading(false);
    _showOutcome(
      outcome,
      onClear: _freshLogin == null ? _reauthenticate : _showConfirmSheet,
    );
  }

  void _showOutcome(
    AccountDeletionOutcome outcome, {
    required Future<void> Function() onClear,
  }) {
    switch (outcome) {
      case AccountDeletionClear():
        unawaited(onClear());
      case AccountDeletionBlocked(:final order):
        setState(() {
          _blockedOrder = order;
          _phase = _Phase.blocked;
        });
      case AccountDeletionDeleted():
        setState(() => _phase = _Phase.success);
      case AccountDeletionOffline():
        setState(() => _phase = _Phase.offline);
      case AccountDeletionOrderCheckUnavailable():
        setState(() => _phase = _Phase.orderCheck);
      case AccountDeletionReauthRequired():
        setState(() => _phase = _Phase.reauth);
      case AccountDeletionTooManyOrders():
        setState(() => _phase = _Phase.tooManyOrders);
      case AccountDeletionEmailMismatch(:final maskedEmail):
        _maskedEmail = maskedEmail;
        setState(() => _phase = _Phase.emailMismatch);
      case AccountDeletionEmailMatch():
      case AccountDeletionFailed():
      case AccountDeletionStale():
        setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _loginAndReturnToDelete() async {
    final signIn = widget.signInForDeletion;
    if (signIn == null) {
      try {
        final fresh = await widget.reauthenticate();
        if (!mounted) return;
        _freshLogin = fresh;
        setState(() => _phase = _Phase.info);
      } on CustomerAuthException catch (error) {
        if (!mounted) return;
        if (error.kind == CustomerAuthErrorKind.cancelled) return;
        setState(() {
          _phase = error.kind == CustomerAuthErrorKind.offline
              ? _Phase.offline
              : _Phase.error;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _phase = _Phase.error);
      }
      return;
    }
    try {
      final result = await signIn();
      if (!mounted) return;
      switch (result) {
        case LegacyDeletionMatched(:final login, :final legacySessionToken):
          _freshLogin = login;
          _legacySessionToken = legacySessionToken;
          setState(() => _phase = _Phase.info);
        case LegacyDeletionMismatch(:final maskedEmail):
          _maskedEmail = maskedEmail;
          setState(() => _phase = _Phase.emailMismatch);
      }
    } on CustomerAuthException catch (error) {
      if (!mounted) return;
      if (error.kind == CustomerAuthErrorKind.cancelled) return;
      setState(() {
        _phase = error.kind == CustomerAuthErrorKind.offline
            ? _Phase.offline
            : _Phase.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _signInWithAnotherAccount() async {
    await widget.abandonUnmatchedLogin?.call();
    await _loginAndReturnToDelete();
  }

  Future<void> _cancelMismatch() async {
    await widget.abandonUnmatchedLogin?.call();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  String _orderLabel(AccountDeletionOrderRef? order) {
    final name = order?.orderName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final shopifyId = order?.shopifyOrderId?.trim();
    if (shopifyId != null && shopifyId.isNotEmpty) return shopifyId;
    return order?.id ?? '';
  }

  String _blockedMessage() {
    final order = _blockedOrder;
    if (order?.reason == 'refund_review') {
      return deleteAccountRefundReviewMessage(_orderLabel(order));
    }
    if (order?.reason == 'refund_in_progress')
      return kDeleteAccountRefundBlocked;
    return kDeleteAccountBlocked;
  }

  Future<void> _reauthenticate() async {
    try {
      final fresh = await widget.reauthenticate();
      if (!mounted) return;
      _freshLogin = fresh;
      await _showConfirmSheet();
    } on CustomerAuthException catch (error) {
      if (!mounted) return;
      if (error.kind == CustomerAuthErrorKind.cancelled) {
        setState(() => _phase = _Phase.info);
        return;
      }
      setState(() {
        _phase = error.kind == CustomerAuthErrorKind.offline
            ? _Phase.offline
            : _Phase.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _showConfirmSheet() async {
    setState(() => _phase = _Phase.info);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isDismissible: true,
      builder: (context) => _ConfirmDeletionSheet(delay: widget.confirmDelay),
    );
    if (!mounted || confirmed != true) return;
    await _delete();
  }

  Future<void> _delete() async {
    final fresh = _freshLogin;
    if (fresh == null) {
      setState(() => _phase = _Phase.error);
      return;
    }
    setState(() => _phase = _Phase.loading);
    _setLoading(true);
    final outcome = await _deletionClient.delete(
      accessToken: fresh.accessToken,
      idToken: fresh.idToken,
      legacySessionToken: _legacySessionToken,
    );
    if (!mounted) return;
    _setLoading(false);
    _showOutcome(outcome, onClear: () async {
      if (!mounted) return;
      setState(() => _phase = _Phase.error);
    });
  }

  Future<void> _finish() async {
    await widget.signOutToHome();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openSupport() =>
      _openUri(widget.supportUri ?? accountDeletionSupportUri());

  Future<void> _openUri(Uri uri) async {
    final open = widget.openUri ??
        ((target) => launchUrl(target, mode: LaunchMode.externalApplication));
    final ok = await open(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.bar,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Eliminar cuenta',
          style: boutiqueTitle(size: 15, color: palette.ink),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(.5),
          child: Container(height: .5, color: palette.hairline),
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => _Loading(slow: _slow),
          _Phase.blocked => _MessageState(
              message: _blockedMessage(),
              primaryLabel: 'Ver pedido',
              primaryKey: const ValueKey('delete-account-view-order'),
              onPrimary: () {
                final order = _blockedOrder;
                if (order != null) widget.onViewOrder(order);
              },
              secondaryLabel: 'Escríbenos por WhatsApp',
              secondaryKey: const ValueKey('delete-account-whatsapp'),
              onSecondary: () => unawaited(
                _openUri(
                  _blockedOrder?.reason == 'refund_review'
                      ? accountDeletionRefundReviewUri(
                          orderNumber: _orderLabel(_blockedOrder),
                        )
                      : (widget.supportUri ?? accountDeletionSupportUri()),
                ),
              ),
            ),
          _Phase.error => _MessageState(
              message: kDeleteAccountError,
              primaryLabel: 'Reintentar',
              primaryKey: const ValueKey('delete-account-retry'),
              onPrimary: _continue,
              secondaryLabel: 'Escríbenos por WhatsApp',
              secondaryKey: const ValueKey('delete-account-whatsapp'),
              onSecondary: _openSupport,
            ),
          _Phase.offline => _MessageState(
              message: kDeleteAccountOffline,
              primaryLabel: 'Reintentar',
              primaryKey: const ValueKey('delete-account-retry'),
              onPrimary: _continue,
              secondaryLabel: 'Cancelar',
              secondaryKey: const ValueKey('delete-account-cancel'),
              onSecondary: () => Navigator.of(context).maybePop(),
            ),
          _Phase.success => _MessageState(
              message: kDeleteAccountSuccess,
              primaryLabel: 'Ir al inicio',
              primaryKey: const ValueKey('delete-account-done'),
              onPrimary: _finish,
            ),
          _Phase.reauth => _PromptState(
              title: kDeleteAccountReauthTitle,
              body: kDeleteAccountReauthBody,
              primaryLabel: 'Iniciar sesión',
              primaryKey: const ValueKey('delete-account-reauth'),
              onPrimary: () => unawaited(_loginAndReturnToDelete()),
              secondaryLabel: 'Ahora no',
              secondaryKey: const ValueKey('delete-account-reauth-dismiss'),
              onSecondary: () => Navigator.of(context).maybePop(),
            ),
          _Phase.orderCheck => _PromptState(
              title: kDeleteAccountOrderCheckTitle,
              body: kDeleteAccountOrderCheckBody,
              primaryLabel: 'Reintentar',
              primaryKey: const ValueKey('delete-account-order-check-retry'),
              onPrimary: _continue,
            ),
          _Phase.emailMismatch => _PromptState(
              title: kDeleteAccountEmailMismatchTitle,
              body: deleteAccountEmailMismatchBody(_maskedEmail ?? ''),
              primaryLabel: 'Iniciar sesión con otra cuenta',
              primaryKey: const ValueKey('delete-account-other-account'),
              onPrimary: () => unawaited(_signInWithAnotherAccount()),
              secondaryLabel: 'Cancelar',
              secondaryKey: const ValueKey('delete-account-email-cancel'),
              onSecondary: () => unawaited(_cancelMismatch()),
            ),
          _Phase.tooManyOrders => _PromptState(
              title: kDeleteAccountTooManyTitle,
              body: kDeleteAccountTooManyBody,
              primaryLabel: 'Escríbenos por WhatsApp',
              primaryKey: const ValueKey('delete-account-too-many-whatsapp'),
              onPrimary: () => unawaited(
                _openUri(accountDeletionManualRequestUri()),
              ),
            ),
          _Phase.info => _Info(
              onContinue: _continue,
              onCancel: () => Navigator.of(context).maybePop(),
            ),
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.onContinue, required this.onCancel});

  final VoidCallback onContinue;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const AccountPageHeader(
          kicker: 'Privacidad',
          title: '¿Eliminar tu cuenta?',
          subtitle:
              'Se cierra tu acceso y se borran tu perfil, tus favoritos y tus '
              'recomendaciones guardadas. Pedimos a Shopify que elimine tus '
              'datos de compra. Si tienes un pedido en curso, podrás eliminar '
              'la cuenta cuando se complete.',
        ),
        const SizedBox(height: BoutiqueSpace.xl),
        BoutiqueButton(
          key: const ValueKey('delete-account-continue'),
          label: 'Continuar',
          onPressed: onContinue,
        ),
        const SizedBox(height: BoutiqueSpace.sm),
        Center(
          child: TextButton(
            key: const ValueKey('delete-account-cancel'),
            onPressed: onCancel,
            child: Text(
              'Cancelar',
              style: boutiqueText(size: 14, color: palette.ink),
            ),
          ),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.slow});

  final bool slow;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: const ValueKey('delete-account-progress'),
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.ink,
              ),
            ),
            if (slow) ...[
              const SizedBox(height: BoutiqueSpace.lg),
              Text(
                kDeleteAccountSlow,
                key: const ValueKey('delete-account-slow'),
                textAlign: TextAlign.center,
                style: boutiqueText(size: 14, color: palette.ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PromptState extends StatelessWidget {
  const _PromptState({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryKey,
    required this.onPrimary,
    this.secondaryLabel,
    this.secondaryKey,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final Key primaryKey;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final Key? secondaryKey;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        AccountPageHeader(kicker: 'Privacidad', title: title, subtitle: body),
        const SizedBox(height: BoutiqueSpace.xl),
        BoutiqueButton(
          key: primaryKey,
          label: primaryLabel,
          onPressed: onPrimary,
        ),
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(height: BoutiqueSpace.sm),
          Center(
            child: TextButton(
              key: secondaryKey,
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: boutiqueText(size: 14, color: palette.ink),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    required this.primaryLabel,
    required this.primaryKey,
    required this.onPrimary,
    this.secondaryLabel,
    this.secondaryKey,
    this.onSecondary,
  });

  final String message;
  final String primaryLabel;
  final Key primaryKey;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final Key? secondaryKey;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        ECard(
          children: [
            Text(
              message,
              style: boutiqueText(size: 14, color: palette.ink),
            ),
          ],
        ),
        const SizedBox(height: BoutiqueSpace.xl),
        BoutiqueButton(
          key: primaryKey,
          label: primaryLabel,
          onPressed: onPrimary,
        ),
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(height: BoutiqueSpace.sm),
          Center(
            child: TextButton(
              key: secondaryKey,
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: boutiqueText(size: 14, color: palette.ink),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConfirmDeletionSheet extends StatefulWidget {
  const _ConfirmDeletionSheet({required this.delay});

  final Duration delay;

  @override
  State<_ConfirmDeletionSheet> createState() => _ConfirmDeletionSheetState();
}

class _ConfirmDeletionSheetState extends State<_ConfirmDeletionSheet> {
  bool _enabled = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Esta acción no se puede deshacer. Eliminar cuenta se habilita en unos segundos.',
          Directionality.of(context),
        ),
      );
    });
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() => _enabled = true);
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Eliminar cuenta ya está disponible.',
          Directionality.of(context),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final label = _enabled
        ? 'Eliminar cuenta'
        : 'Eliminar cuenta. Se habilita en unos segundos.';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Esta acción no se puede deshacer.',
            style: boutiqueTitle(size: 18, color: palette.ink),
          ),
          const SizedBox(height: BoutiqueSpace.lg),
          Semantics(
            button: true,
            enabled: _enabled,
            label: label,
            child: ExcludeSemantics(
              child: BoutiqueButton(
                key: const ValueKey('delete-account-confirm'),
                label: 'Eliminar cuenta',
                onPressed:
                    _enabled ? () => Navigator.of(context).pop(true) : null,
              ),
            ),
          ),
          const SizedBox(height: BoutiqueSpace.sm),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: boutiqueText(size: 14, color: palette.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
