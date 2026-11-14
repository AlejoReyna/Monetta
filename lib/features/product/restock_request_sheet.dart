/// G12 modal — exhausted variant, email, consent and real submit (UI:G12).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/media/monetta_image.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/shopper_copy.dart';
import '../../data/media/media_url.dart';
import '../../domain/product.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import 'purchase_dock.dart';
import 'restock_request.dart';

const _sheetKey = ValueKey<String>('restock-request-sheet');
const _emailKey = ValueKey<String>('restock-request-email');
const _consentKey = ValueKey<String>('restock-request-consent');
const _submitKey = ValueKey<String>('restock-request-submit');
const _closeKey = ValueKey<String>('restock-request-close');

/// Opens the G12 sheet. Returns the submit result, or null when dismissed.
Future<RestockSubmitResult?> showRestockRequestSheet(
  BuildContext context, {
  required Product product,
  required ProductVariant variant,
  required RestockRequestSubmit onSubmit,
  String? initialEmail,
}) {
  return showModalBottomSheet<RestockSubmitResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => RestockRequestSheet(
      product: product,
      variant: variant,
      onSubmit: onSubmit,
      initialEmail: initialEmail,
    ),
  );
}

class RestockRequestSheet extends StatefulWidget {
  const RestockRequestSheet({
    required this.product,
    required this.variant,
    required this.onSubmit,
    this.initialEmail,
    super.key,
  });

  final Product product;
  final ProductVariant variant;
  final RestockRequestSubmit onSubmit;
  final String? initialEmail;

  @override
  State<RestockRequestSheet> createState() => _RestockRequestSheetState();
}

class _RestockRequestSheetState extends State<RestockRequestSheet> {
  late final TextEditingController _email;
  var _consent = false;
  var _submitting = false;
  String? _emailError;
  String? _statusMessage;
  RestockSubmitResult? _terminalResult;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String? _variantSubtitle(ProductVariant variant) {
    if (variant.selectedOptions.isNotEmpty) {
      return variant.selectedOptions.values.join(' · ');
    }
    if (variant.isDefault) return null;
    return variant.title;
  }

  String? _thumbnailUrl(Product product, ProductVariant variant) {
    final urls = imagesForVariant(product, variant);
    if (urls.isEmpty) return product.primaryImage;
    return urls.first;
  }

  bool _validEmail(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Future<void> _submit() async {
    if (_submitting || _terminalResult != null) return;
    final email = _email.text.trim();
    setState(() {
      _emailError = null;
      _statusMessage = null;
    });
    if (!_validEmail(email)) {
      setState(() => _emailError = 'Escribe un correo válido.');
      return;
    }
    if (!_consent) {
      setState(
        () => _statusMessage = 'Acepta el aviso del canal para continuar.',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await widget.onSubmit(
        RestockRequestPayload(
          product: widget.product,
          variant: widget.variant,
          email: email,
          consentAccepted: _consent,
        ),
      );
      if (!mounted) return;
      switch (result) {
        case RestockSubmitResult.created:
          setState(() {
            _terminalResult = result;
            _statusMessage =
                'Listo. Te avisaremos cuando esta variante vuelva.';
          });
        case RestockSubmitResult.alreadyRegistered:
          setState(() {
            _terminalResult = result;
            _statusMessage = 'Ya teníamos tu solicitud para esta variante.';
          });
        case RestockSubmitResult.unavailable:
          setState(() {
            _statusMessage =
                'El aviso de reposición no está disponible en este momento.';
          });
        case RestockSubmitResult.error:
          setState(() {
            _statusMessage =
                'No pudimos registrar tu solicitud. Revisa el correo e inténtalo.';
          });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _close() {
    if (_terminalResult != null) {
      Navigator.of(context).pop(_terminalResult);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final subtitle = _variantSubtitle(widget.variant);
    final thumb = _thumbnailUrl(widget.product, widget.variant);

    return Material(
      key: _sheetKey,
      color: palette.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MonettaTokens.gutterFor(MediaQuery.sizeOf(context).width),
          12,
          MonettaTokens.gutterFor(MediaQuery.sizeOf(context).width),
          bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Avísame cuando vuelva',
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.sectionTitle,
                      ),
                    ),
                  ),
                  IconButton(
                    key: _closeKey,
                    tooltip: 'Cerrar',
                    onPressed: _submitting ? null : _close,
                    icon: Icon(Icons.close, color: palette.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: BoutiqueSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (thumb != null)
                    ClipRRect(
                      borderRadius: BoutiqueRadius.card,
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: MonettaImage(
                          url:
                              MediaUrl.sized(thumb, width: MediaUrl.thumbWidth),
                          fit: BoxFit.contain,
                          cacheWidth: MediaUrl.thumbWidth,
                        ),
                      ),
                    ),
                  if (thumb != null) const SizedBox(width: BoutiqueSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopperProductName(widget.product.title),
                          style: boutiqueText(
                            size: 14,
                            weight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: boutiqueText(
                              size: 13,
                              color: palette.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BoutiqueSpace.lg),
              Text(
                'Correo',
                style: boutiqueText(
                  size: 12,
                  weight: FontWeight.w600,
                  color: palette.inkMuted,
                ),
              ),
              const SizedBox(height: BoutiqueSpace.sm),
              TextField(
                key: _emailKey,
                controller: _email,
                enabled: !_submitting && _terminalResult == null,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'tu@correo.com',
                  errorText: _emailError,
                  border: OutlineInputBorder(
                    borderRadius: BoutiqueRadius.card,
                    borderSide: BorderSide(color: palette.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BoutiqueRadius.card,
                    borderSide: BorderSide(color: palette.hairline),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: BoutiqueSpace.md),
              Semantics(
                checked: _consent,
                child: CheckboxListTile(
                  key: _consentKey,
                  value: _consent,
                  onChanged: _submitting || _terminalResult != null
                      ? null
                      : (value) => setState(() => _consent = value == true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Acepto recibir el aviso por el canal autorizado de Monetta '
                    '(notificación en este dispositivo cuando el servicio '
                    'esté activo).',
                    style: boutiqueText(size: 12, color: palette.inkMuted),
                  ),
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: BoutiqueSpace.sm),
                Text(
                  _statusMessage!,
                  style: boutiqueText(
                    size: 13,
                    color: _terminalResult != null
                        ? MonettaTokens.success
                        : palette.ink,
                  ),
                ),
              ],
              const SizedBox(height: BoutiqueSpace.lg),
              PurchaseDockButton(
                key: _submitKey,
                label: _submitting
                    ? 'Enviando…'
                    : _terminalResult != null
                        ? 'Cerrar'
                        : 'Enviar solicitud',
                pending: _submitting,
                large: true,
                onPressed: _submitting
                    ? null
                    : _terminalResult != null
                        ? _close
                        : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
