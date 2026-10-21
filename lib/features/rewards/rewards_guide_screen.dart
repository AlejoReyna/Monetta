/// Client-guide Rewards summary (page 14).
///
/// Reads the existing balance. Points, levels and earning rules from the guide
/// have no contract in this build, so those spots stay marked as placeholders.
/// This file does not calculate a balance or call a new backend.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../app/monetta_tokens.g.dart';
import '../../data/accounts_orders/accounts_orders_config.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
import 'rewards_api.dart';
import 'rewards_models.dart';
import 'rewards_section.dart';
import 'rewards_share_screen.dart';

Future<void> openRewardsGuide(
  BuildContext context, {
  AccountController? controller,
  RewardsReader? reader,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/rewards'),
      builder: (_) =>
          RewardsGuideScreen(controller: controller, reader: reader),
    ),
  );
}

class RewardsGuideScreen extends StatefulWidget {
  const RewardsGuideScreen({this.controller, this.reader, super.key});

  final AccountController? controller;
  final RewardsReader? reader;

  @override
  State<RewardsGuideScreen> createState() => _RewardsGuideScreenState();
}

class _RewardsGuideScreenState extends State<RewardsGuideScreen> {
  RewardsApi? _api;
  RewardsReader? _reader;
  RewardsSummary? _summary;
  var _loading = true;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant RewardsGuideScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reader != widget.reader ||
        oldWidget.controller != widget.controller) {
      _resolve();
      unawaited(_load());
    }
  }

  void _resolve() {
    _api?.close();
    _api = null;
    final fixed = widget.reader;
    if (fixed != null) {
      _reader = fixed;
      return;
    }
    final controller = widget.controller;
    if (controller == null) {
      _reader = null;
      return;
    }
    _api = resolveRewardsApi(
      config: AccountsOrdersConfig.fromEnvironment(),
      tokenProvider: controller.accessTokenForBackend,
    );
    final api = _api;
    _reader = api == null ? null : ApiRewardsReader(api);
  }

  Future<void> _load() async {
    final reader = _reader;
    if (reader == null) {
      if (!mounted) return;
      setState(() {
        _summary = null;
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final summary = await reader.summary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _summary = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final width = MediaQuery.sizeOf(context).width;
    final summary = _summary;
    return ClientGuideScaffold(
      current: ClientGuideDestination.account,
      accountController: widget.controller,
      body: ListView(
        key: const ValueKey('rewards-guide-scroll'),
        padding: EdgeInsets.fromLTRB(
          MonettaTokens.gutterFor(width),
          MonettaTokens.space[4],
          MonettaTokens.gutterFor(width),
          MonettaTokens.space[6],
        ),
        children: [
          Text(
            'Monetta Rewards',
            style: clientGuideStyle(context, MonettaTokens.screenTitle),
          ),
          SizedBox(height: MonettaTokens.space[1]),
          Text(
            'Tus compras, acumulas puntos.',
            style: clientGuideStyle(
              context,
              MonettaTokens.body,
              color: palette.inkMuted,
            ),
          ),
          SizedBox(height: MonettaTokens.space[2]),
          const _PlaceholderLine(
            text:
                'La guía ilustra puntos y niveles. El saldo mostrado es el contrato en MXN.',
          ),
          SizedBox(height: MonettaTokens.space[4]),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child:
                    CircularProgressIndicator(key: ValueKey('rewards-loading')),
              ),
            )
          else if (_failed)
            _StatusBlock(
              title: 'No se pudo leer el saldo',
              action: 'Reintentar',
              onAction: () => unawaited(_load()),
            )
          else if (summary == null)
            const _StatusBlock(
              title: 'Monetta Rewards aún no está disponible',
              body:
                  'No hay un saldo que mostrar. No se inventa un puntaje ni un nivel.',
            )
          else
            _BalanceRing(
              amount: summary.availableLabel,
              caption: 'Saldo disponible',
            ),
          SizedBox(height: MonettaTokens.space[2]),
          Text(
            'Nivel: $kRewardsContractPlaceholder',
            key: const ValueKey('rewards-level-placeholder'),
            textAlign: TextAlign.center,
            style: clientGuideStyle(
              context,
              MonettaTokens.navLabel,
              color: palette.goldText,
            ),
          ),
          SizedBox(height: MonettaTokens.space[5]),
          Text(
            'Cómo ganar puntos',
            style: clientGuideStyle(context, MonettaTokens.sectionTitle),
          ),
          SizedBox(height: MonettaTokens.space[2]),
          const _GuideRow(
            id: 'rewards-earn-purchase',
            icon: Icons.shopping_bag_outlined,
            title: 'Por cada compra',
          ),
          const _GuideRow(
            id: 'rewards-earn-share',
            icon: Icons.share_outlined,
            title: 'Compartir catálogo en redes',
          ),
          const _GuideRow(
            id: 'rewards-earn-wholesale',
            icon: Icons.storefront_outlined,
            title: 'Comprar a mayoreo',
          ),
          SizedBox(height: MonettaTokens.space[5]),
          Text(
            'Canjear puntos',
            style: clientGuideStyle(context, MonettaTokens.sectionTitle),
          ),
          SizedBox(height: MonettaTokens.space[2]),
          const _RedeemCard(
            id: 'rewards-redeem-discounts',
            icon: Icons.percent_outlined,
            title: 'Descuentos',
            body: 'Usa tus puntos en tus compras',
          ),
          const _RedeemCard(
            id: 'rewards-redeem-shipping',
            icon: Icons.local_shipping_outlined,
            title: 'Envío gratis',
            body: 'Canjea puntos por envíos',
          ),
          const _RedeemCard(
            id: 'rewards-redeem-early',
            icon: Icons.workspace_premium_outlined,
            title: 'Acceso anticipado',
            body: 'Sé la primera en nuevas colecciones',
          ),
          SizedBox(height: MonettaTokens.space[4]),
          FilledButton(
            key: const ValueKey('rewards-open-share'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RewardsShareScreen(
                    accountController: widget.controller,
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: palette.actionDark,
              foregroundColor: palette.onActionDark,
              minimumSize: const Size.fromHeight(MonettaTokens.controlHeight),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Comparte y gana',
              style: clientGuideStyle(
                context,
                MonettaTokens.control,
                color: palette.onActionDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceRing extends StatelessWidget {
  const _BalanceRing({required this.amount, required this.caption});

  final String amount;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Center(
      child: SizedBox(
        key: const ValueKey('rewards-balance'),
        width: 220,
        height: 220,
        child: CustomPaint(
          painter: _RingPainter(
            color: palette.gold,
            track: palette.hairline,
          ),
          child: Padding(
            padding: EdgeInsets.all(MonettaTokens.space[4]),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  amount,
                  textAlign: TextAlign.center,
                  style: clientGuideStyle(context, MonettaTokens.sectionTitle),
                ),
                SizedBox(height: MonettaTokens.space[1]),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.navLabel,
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.color, required this.track});

  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, stroke..color = track);
    canvas.drawCircle(
      center,
      radius - 8,
      stroke..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.track != track;
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.id,
    required this.icon,
    required this.title,
  });

  final String id;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: EdgeInsets.only(bottom: MonettaTokens.space[2]),
      child: DecoratedBox(
        key: ValueKey(id),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BoutiqueRadius.card,
          border: Border.all(color: palette.hairline),
        ),
        child: Padding(
          padding: EdgeInsets.all(MonettaTokens.space[3]),
          child: Row(
            children: [
              Icon(icon, color: palette.goldText),
              SizedBox(width: MonettaTokens.space[2]),
              Expanded(
                child: Text(
                  title,
                  style: clientGuideStyle(context, MonettaTokens.cardLabel),
                ),
              ),
              const Text(kRewardsContractPlaceholder),
            ],
          ),
        ),
      ),
    );
  }
}

class _RedeemCard extends StatelessWidget {
  const _RedeemCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
  });

  final String id;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: EdgeInsets.only(bottom: MonettaTokens.space[2]),
      child: DecoratedBox(
        key: ValueKey(id),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BoutiqueRadius.card,
          border: Border.all(color: palette.hairline),
        ),
        child: Padding(
          padding: EdgeInsets.all(MonettaTokens.space[3]),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: palette.goldText),
              SizedBox(width: MonettaTokens.space[2]),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: clientGuideStyle(context, MonettaTokens.cardLabel),
                    ),
                    Text(
                      body,
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.navLabel,
                        color: palette.inkMuted,
                      ),
                    ),
                    const Text(kRewardsContractPlaceholder),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderLine extends StatelessWidget {
  const _PlaceholderLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: const ValueKey('rewards-contract-note'),
      style: clientGuideStyle(
        context,
        MonettaTokens.navLabel,
        color: context.boutique.goldText,
      ),
    );
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.title,
    this.body,
    this.action,
    this.onAction,
  });

  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: clientGuideStyle(context, MonettaTokens.cardLabel),
        ),
        if (body != null) ...[
          SizedBox(height: MonettaTokens.space[1]),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: clientGuideStyle(
              context,
              MonettaTokens.body,
              color: palette.inkMuted,
            ),
          ),
        ],
        if (action != null && onAction != null) ...[
          SizedBox(height: MonettaTokens.space[2]),
          TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ],
    );
  }
}
