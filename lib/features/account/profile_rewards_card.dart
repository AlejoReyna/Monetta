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
        // Compact entry (style guideline §2, page 13): the balance stays the
        // server's number in MXN; nothing here invents points or tiers.
        return Material(
          key: const ValueKey('profile-rewards-card'),
          color: palette.surfaceDeep,
          borderRadius: BoutiqueRadius.card,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BoutiqueSpace.lg,
                vertical: BoutiqueSpace.md,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.canvas,
                      ),
                      child: Icon(
                        Icons.card_giftcard_outlined,
                        size: 24,
                        color: palette.goldText,
                      ),
                    ),
                  ),
                  const SizedBox(width: BoutiqueSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monetta Rewards',
                          style: boutiqueRowLabel(
                            context: context,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (summary != null)
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: 6,
                            children: [
                              Text(
                                '\$${(summary.availableCents / 100).toStringAsFixed(2)}',
                                key: const ValueKey(
                                  'rewards-balance-available',
                                ),
                                style: boutiqueText(
                                  size: 16,
                                  weight: FontWeight.w600,
                                  color: palette.ink,
                                ),
                              ),
                              Text(
                                'MXN',
                                style: boutiqueText(
                                  size: 12,
                                  color: palette.inkMuted,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            title,
                            style: boutiqueText(
                              size: 14,
                              weight: FontWeight.w500,
                              color: palette.ink,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          footer,
                          style: boutiqueText(
                            size: 12,
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: BoutiqueSpace.sm),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: palette.inkMuted,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
