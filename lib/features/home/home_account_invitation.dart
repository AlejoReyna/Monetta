/// Account invitation with an injectable, real access flow.
library;

import 'package:flutter/material.dart';

class HomeAccountInvitation extends StatefulWidget {
  const HomeAccountInvitation({
    required this.onRegister,
    this.onEmailRegister,
    this.isSignedIn = false,
    super.key,
  });
  final VoidCallback? onRegister;

  /// Returns an error message when access cannot continue; never implies signup.
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
  Widget build(BuildContext context) => Container(
        key: const ValueKey('home-account-invitation'),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        color: const Color(0xfffaf9f6),
        child: Column(
          children: [
            Text(
              'Regístrate en MONETTA REWARDS',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.black),
            ),
            const SizedBox(height: 8),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'ENVÍO GRATIS',
                    style: TextStyle(
                      color: Color(0xffa47b34),
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
              TextSpan(
                children: [
                  TextSpan(
                    text: 'GANA CASHBACK',
                    style: TextStyle(
                      color: Color(0xff398157),
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
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    errorText: _error,
                  ),
                ),
              ),
            ],
            if (widget.onEmailRegister != null ||
                widget.onRegister != null) ...[
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffc8a653).withValues(alpha: .4),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: FilledButton(
                  key: const ValueKey('home-register-button'),
                  onPressed: _busy
                      ? null
                      : (widget.isSignedIn || widget.onEmailRegister == null
                          ? widget.onRegister
                          : _submit),
                  child:
                      Text(widget.isSignedIn ? 'Ver mi cuenta' : 'Registrarme'),
                ),
              ),
            ],
          ],
        ),
      );
}
