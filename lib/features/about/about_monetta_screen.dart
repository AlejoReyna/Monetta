/// Monetta's story and trust proposition, translated into the app's quieter
/// editorial language.
library;

import 'package:flutter/material.dart';

import '../navigation/monetta_page_header.dart';

import '../../app/theme.dart';
import '../../domain/editorial_content.dart';

class AboutMonettaScreen extends StatelessWidget {
  const AboutMonettaScreen({
    required this.content,
    required this.onOpenCatalog,
    required this.onOpenPartner,
    super.key,
  });

  final AboutMonettaContent content;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenPartner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildMonettaPageAppBar(
        context,
        title: 'Nuestra historia',
      ),
      body: ListView(
        key: const ValueKey('about-monetta-scroll'),
        padding: EdgeInsets.zero,
        children: [
          _StoryHero(content: content),
          const SizedBox(height: 64),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'NUESTRA HISTORIA',
              style: eyebrow(color: context.monettaColors.accent),
            ),
          ),
          const SizedBox(height: 26),
          _Timeline(milestones: content.milestones),
          const SizedBox(height: 64),
          Container(
            color: context.monettaColors.surfaceMuted,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LO QUE PUEDES ESPERAR', style: eyebrow()),
                const SizedBox(height: 22),
                _TrustGrid(facts: content.trustFacts),
              ],
            ),
          ),
          Container(
            color: kInk,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MONETTA TAMBIÉN ES PARA EMPRENDER',
                  style: eyebrow(color: context.monettaColors.accent),
                ),
                const SizedBox(height: 14),
                Text(
                  'Comparte nuestros catálogos y vende con Monetta.',
                  style: display(27, color: Colors.white, height: 1.25),
                ),
                const SizedBox(height: 26),
                FilledButton(
                  key: const ValueKey('about-open-partner'),
                  onPressed: onOpenPartner,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kInk,
                  ),
                  child: const Text('CONOCER EL PROGRAMA'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const ValueKey('about-open-catalog'),
                  onPressed: onOpenCatalog,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('EXPLORAR CATÁLOGO'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryHero extends StatelessWidget {
  const _StoryHero({required this.content});

  final AboutMonettaContent content;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final image = Image.asset(
          content.heroAsset,
          width: double.infinity,
          height: wide ? 640 : 390,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
        );
        final copy = Container(
          color: context.monettaColors.surfaceRaised,
          padding: EdgeInsets.fromLTRB(
            wide ? 48 : 20,
            wide ? 48 : 38,
            wide ? 48 : 20,
            wide ? 48 : 42,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.eyebrow,
                style: eyebrow(color: context.monettaColors.accent),
              ),
              const SizedBox(height: 16),
              Text(content.headline, style: display(wide ? 42 : 31)),
              const SizedBox(height: 20),
              Text(
                content.body,
                style: sans(
                  size: 14,
                  color: context.monettaColors.contentMuted,
                  height: 1.65,
                ),
              ),
            ],
          ),
        );
        if (!wide) return Column(children: [image, copy]);
        return SizedBox(
          height: 640,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: image),
              Expanded(child: copy),
            ],
          ),
        );
      },
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.milestones});

  final List<StoryMilestone> milestones;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < milestones.length; i++)
            _TimelineRow(
              milestone: milestones[i],
              isLast: i == milestones.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.milestone, required this.isLast});

  final StoryMilestone milestone;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              milestone.year,
              style: eyebrow(size: 9, color: context.monettaColors.accent),
            ),
          ),
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: context.monettaColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  const Expanded(
                    child: VerticalDivider(width: 1, thickness: 0.5),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(milestone.title, style: display(20)),
                  const SizedBox(height: 8),
                  Text(
                    milestone.body,
                    style: sans(
                      size: 13,
                      color: context.monettaColors.contentMuted,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustGrid extends StatelessWidget {
  const _TrustGrid({required this.facts});

  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: facts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: columns == 4 ? 2.1 : 1.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) => Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: context.monettaColors.divider),
            ),
            child: Text(facts[index], style: sans(size: 12, height: 1.4)),
          ),
        );
      },
    );
  }
}
