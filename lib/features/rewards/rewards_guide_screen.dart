/// Account-scoped Rewards entry. Tier and benefit capabilities remain gated
/// until the service provides authoritative rules and eligible-purchase data.
library;

import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../app/monetta_tokens.g.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
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

class RewardsGuideScreen extends StatelessWidget {
  const RewardsGuideScreen({this.controller, this.reader, super.key});

  final AccountController? controller;
  final RewardsReader? reader;

  @override
  Widget build(BuildContext context) => ClientGuideScaffold(
        current: ClientGuideDestination.account,
        accountController: controller,
        body: ListView(
          key: const ValueKey('rewards-guide-scroll'),
          padding: const EdgeInsets.all(24),
          children: [
            Text('MONETTA REWARDS',
                style: clientGuideStyle(context, MonettaTokens.screenTitle)),
            const SizedBox(height: 24),
            if (controller != null)
              AutoRewardsSection(controller: controller!, reader: reader)
            else
              RewardsSection(controller: null, reader: reader),
            const SizedBox(height: 24),
            const Text('Tu nivel y sus beneficios aún no están disponibles.'),
          ],
        ),
      );
}
