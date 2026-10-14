import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../data/accounts_orders/accounts_orders_config.dart';
import '../boutique/boutique_tokens.dart';
import '../rewards/rewards_api.dart';
import '../rewards/rewards_error_kind.dart';
import '../rewards/rewards_models.dart';
import '../rewards/rewards_section.dart';

/// Profile presentation; the existing Rewards reader remains authoritative.
class ProfileRewardsCard extends StatefulWidget {
  const ProfileRewardsCard({required this.controller, this.reader, super.key});

  final AccountController controller;
  final RewardsReader? reader;

  @override
  State<ProfileRewardsCard> createState() => _ProfileRewardsCardState();
}

class _ProfileRewardsCardState extends State<ProfileRewardsCard> {
  RewardsApi? _api;
  RewardsReader? _reader;
  Future<RewardsSummary>? _pending;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ProfileRewardsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reader != widget.reader ||
        oldWidget.controller != widget.controller) {
      _resolve();
    }
  }

  void _resolve() {
    _api?.close();
    _api = null;
    _reader = widget.reader;
    if (_reader == null) {
      _api = resolveRewardsApi(
        config: AccountsOrdersConfig.fromEnvironment(),
        tokenProvider: widget.controller.accessTokenForBackend,
      );
      if (_api case final api?) _reader = ApiRewardsReader(api);
    }
    _pending = _reader?.summary();
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  void _openDetails() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.boutique.canvas,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Tu saldo Monetta', style: boutiqueDisplay(26)),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RewardsSection(controller: widget.controller, reader: _reader),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    const muted = Color(0xFFC0C1B8);
    return FutureBuilder<RewardsSummary>(
      future: _pending,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final loading = _pending != null &&
            snapshot.connectionState == ConnectionState.waiting;
        final unavailable = _reader == null ||
            (snapshot.hasError &&
                classifyRewardsError(snapshot.error) ==
                    RewardsErrorKind.unavailable);
        final session = snapshot.hasError &&
            classifyRewardsError(snapshot.error) == RewardsErrorKind.session;
        final title = loading
            ? 'Consultando tu saldo…'
            : unavailable
                ? 'Monetta Rewards aún no está disponible'
                : session
                    ? 'Tu sesión terminó'
                    : 'No pudimos consultar tu saldo';
        final footer = summary != null
            ? summary.redemptionEnabled
                ? 'Para tu próxima pieza favorita'
                : 'El canje aún no está habilitado'
            : loading
                ? 'Un momento, por favor'
                : unavailable
                    ? 'Tus compras se registran con normalidad'
                    : session
                        ? 'Iniciar sesión'
                        : 'Reintentar';
        final VoidCallback? onTap = summary != null
            ? _openDetails
            : loading || unavailable
                ? null
                : session
                    ? widget.controller.canLogin && !widget.controller.isLoading
                        ? () => widget.controller.login()
                        : null
                    : () => setState(() => _pending = _reader?.summary());
        return Material(
          key: const ValueKey('profile-rewards-card'),
          color: const Color(0xFF191A18),
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TU SALDO MONETTA',
                    style: boutiqueEyebrow(
                      size: 11,
                      color: const Color(0xFFD3C5A7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: summary != null
                            ? Wrap(
                                crossAxisAlignment: WrapCrossAlignment.end,
                                spacing: 8,
                                children: [
                                  Text(
                                    '\$${(summary.availableCents / 100).toStringAsFixed(2)}',
                                    key: const ValueKey(
                                      'rewards-balance-available',
                                    ),
                                    style: boutiqueText(
                                      size: 34,
                                      height: 1.15,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'MXN',
                                    style: boutiqueText(size: 11, color: muted),
                                  ),
                                ],
                              )
                            : Text(
                                title,
                                style: boutiqueTitle(
                                  size: 17,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      ExcludeSemantics(
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: palette.gold.withValues(alpha: .6),
                            ),
                          ),
                          child: Text(
                            'M',
                            style: boutiqueDisplay(32, color: palette.gold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0x26FFFFFF), height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          footer,
                          style: boutiqueText(size: 12, color: muted),
                        ),
                      ),
                      if (onTap != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: palette.gold,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
