/// Pantalla MONETTA REWARDS (`UI:G19` + `UI:G20` + `UI:G21`).
///
/// Muestra el arco de 270°, nivel actual y progreso, saldo disponible en verde,
/// acceso a `Ver movimientos` y al modal `Beneficios del nivel` cuando el
/// servidor entrega datos autoritativos de nivel. Mantiene fallback al estado
/// condicionado para fixtures antiguos sin objeto `tier`.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import '../../data/accounts_orders/accounts_orders_config.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
import 'rewards_api.dart';
import 'rewards_models.dart';
import 'rewards_movements_screen.dart';
import 'rewards_progress.dart';
import 'rewards_section.dart';

Future<void> openRewardsGuide(
  BuildContext context, {
  AccountController? controller,
  RewardsReader? reader,
}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/rewards'),
        builder: (_) =>
            RewardsGuideScreen(controller: controller, reader: reader),
      ),
    );

class RewardsGuideScreen extends StatefulWidget {
  const RewardsGuideScreen({this.controller, this.reader, super.key});

  final AccountController? controller;
  final RewardsReader? reader;

  @override
  State<RewardsGuideScreen> createState() => _RewardsGuideScreenState();
}

class _RewardsGuideScreenState extends State<RewardsGuideScreen> {
  RewardsApi? _api;
  RewardsReader? _effective;
  Future<RewardsSummary>? _pending;
  String? _owner;

  @override
  void initState() {
    super.initState();
    _owner = widget.controller?.account?.localAccountId;
    widget.controller?.addListener(_onAccountChanged);
    _resolve();
  }

  @override
  void didUpdateWidget(covariant RewardsGuideScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onAccountChanged);
      widget.controller?.addListener(_onAccountChanged);
      _owner = widget.controller?.account?.localAccountId;
    }
    if (oldWidget.reader != widget.reader ||
        oldWidget.controller != widget.controller) {
      _resolve();
    }
  }

  void _onAccountChanged() {
    final current = widget.controller?.account?.localAccountId;
    if (current == _owner || !mounted) return;
    _owner = current;
    setState(_resolve);
  }

  void _resolve() {
    _api?.close();
    _api = null;
    final fixed = widget.reader;
    if (fixed != null) {
      _effective = fixed;
      _pending = fixed.summary();
      return;
    }
    final controller = widget.controller;
    if (controller == null || !controller.isSignedIn) {
      _effective = null;
      _pending = null;
      return;
    }
    _api = resolveRewardsApi(
      config: AccountsOrdersConfig.fromEnvironment(),
      tokenProvider: controller.accessTokenForBackend,
    );
    final api = _api;
    _effective = api == null ? null : ApiRewardsReader(api);
    _pending = _effective?.summary();
  }

  void _reload() {
    final reader = _effective;
    if (reader == null) return;
    setState(() {
      _pending = reader.summary();
    });
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onAccountChanged);
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final reader = _effective;
    final pending = _pending;

    return ClientGuideScaffold(
      current: ClientGuideDestination.account,
      accountController: widget.controller,
      body: reader == null || pending == null
          ? ListView(
              key: const ValueKey('rewards-guide-scroll'),
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'MONETTA REWARDS',
                  style: clientGuideStyle(context, MonettaTokens.screenTitle),
                ),
                const SizedBox(height: 24),
                if (widget.controller != null)
                  AutoRewardsSection(
                    controller: widget.controller!,
                    reader: widget.reader,
                  )
                else
                  RewardsSection(controller: null, reader: widget.reader),
              ],
            )
          : FutureBuilder<RewardsSummary>(
              future: pending,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView(
                    key: const ValueKey('rewards-guide-scroll'),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const _RewardsHeader(),
                      const SizedBox(height: 48),
                      Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.ink,
                        ),
                      ),
                    ],
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return ListView(
                    key: const ValueKey('rewards-guide-scroll'),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const _RewardsHeader(),
                      const SizedBox(height: 24),
                      Text(
                        'No pudimos consultar tus Rewards.',
                        style: sans(size: 14, color: palette.inkMuted),
                      ),
                      const SizedBox(height: 12),
                      ClientGuideButton(
                        label: 'Reintentar',
                        outlined: true,
                        onPressed: _reload,
                      ),
                    ],
                  );
                }

                final summary = snapshot.data!;
                final tier = summary.tier;
                if (tier == null) {
                  return ListView(
                    key: const ValueKey('rewards-guide-scroll'),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        'MONETTA REWARDS',
                        style: clientGuideStyle(
                          context,
                          MonettaTokens.screenTitle,
                        ),
                      ),
                      const SizedBox(height: 24),
                      RewardsSection(
                        controller: widget.controller,
                        reader: reader,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Tu nivel y sus beneficios aún no están disponibles.',
                      ),
                    ],
                  );
                }

                return ListView(
                  key: const ValueKey('rewards-guide-scroll'),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
                  children: [
                    const _RewardsHeader(),
                    const SizedBox(height: 16),
                    Center(
                      child: RewardsProgress(
                        level: tier.level,
                        fraction: tier.progressFraction,
                        purchaseCountLabel: tier.purchaseCountLabel,
                        nextLevel: tier.nextLevel,
                        isFinalLevel: tier.isFinalLevel,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Divider(height: 1, color: palette.hairline),
                    const SizedBox(height: 18),
                    Text(
                      'Saldo disponible',
                      style: sans(size: 13.5, color: palette.inkMuted),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          summary.availableMxnAmount,
                          key: const ValueKey('rewards-balance-available'),
                          style: boutiqueScreenTitle(
                            context: context,
                            color: palette.gold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'mxn',
                          style: sans(size: 13, color: palette.inkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClientGuideButton(
                      key: const ValueKey('rewards-open-movements'),
                      label: 'Ver movimientos',
                      outlined: true,
                      onPressed: () => unawaited(
                        openRewardsMovements(
                          context,
                          reader: reader,
                          initialSummary: summary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      key: const ValueKey('rewards-open-benefits'),
                      borderRadius: BoutiqueRadius.control,
                      onTap: () => unawaited(
                        showRewardsBenefits(
                          context,
                          level: tier.level,
                          introduction: tier.introduction,
                          structuredBenefits: tier.benefits,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Beneficios del nivel',
                          style: sans(
                            size: 14,
                            weight: FontWeight.w500,
                            color: palette.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _RewardsHeader extends StatelessWidget {
  const _RewardsHeader();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'Tu nivel',
          textAlign: TextAlign.center,
          style: clientGuideStyle(context, MonettaTokens.screenTitle),
        ),
      );
}
