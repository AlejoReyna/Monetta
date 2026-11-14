/// Account invitation with an injectable, real access flow.
library;

import 'package:flutter/material.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import '../boutique/client_guide_components.dart';

class HomeAccountInvitation extends StatefulWidget {
  const HomeAccountInvitation({
    required this.onRegister,
    this.onEmailRegister,
    this.isSignedIn = false,
    super.key,
  });
  final VoidCallback? onRegister;

  /// Returns an error message on failure. Null means the access flow returned,
  /// including cancellation; it never implies signup. The email remains editable.
  final Future<String?> Function(String email)? onEmailRegister;
  final bool isSignedIn;
  @override
  State<HomeAccountInvitation> createState() => _HomeAccountInvitationState();
}

class _HomeAccountInvitationState extends State<HomeAccountInvitation> {
  final _email = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || widget.onEmailRegister == null) return;
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Introduce un correo válido.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final error = await widget.onEmailRegister!(email);
      if (mounted) setState(() => _error = error);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo continuar. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: buildLightTheme(),
      child: Container(
        key: const ValueKey('home-account-invitation'),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: Column(
          children: [
            Text(
              'Regístrate en MONETTA REWARDS',
              textAlign: TextAlign.center,
              style: clientGuideStyle(context, MonettaTokens.body,
                  color: Colors.black),
            ),
            const SizedBox(height: 8),
            const Text.rich(
              style: TextStyle(
                  fontFamily: 'DM Sans', fontSize: 14, color: Colors.black),
              TextSpan(
                children: [
                  TextSpan(
                    text: 'ENVÍO GRATIS',
                    style: TextStyle(
                      color: MonettaTokens.gold,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' para siempre',
                    style: TextStyle(color: Colors.black),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const Text.rich(
              style: TextStyle(
                  fontFamily: 'DM Sans', fontSize: 14, color: Colors.black),
              TextSpan(
                children: [
                  TextSpan(
                    text: 'GANA CASHBACK',
                    style: TextStyle(
                      color: MonettaTokens.success,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' con cada compra',
                    style: TextStyle(color: Colors.black),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            if (!widget.isSignedIn && widget.onEmailRegister != null) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    errorText: _error,
                  ),
                ),
              ),
            ],
            if (widget.isSignedIn
                ? widget.onRegister != null
                : widget.onEmailRegister != null ||
                    widget.onRegister != null) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClientGuideButton(
                  key: const ValueKey('home-register-button'),
                  onPressed: _busy
                      ? null
                      : (widget.isSignedIn || widget.onEmailRegister == null
                          ? widget.onRegister
                          : _submit),
                  label: widget.isSignedIn ? 'Ver mi cuenta' : 'Registrarme',
                ),
              ),
            ],
          ],
        ),
      ));
}
