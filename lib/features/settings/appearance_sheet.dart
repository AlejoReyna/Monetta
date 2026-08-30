/// Device-wide appearance picker available to every shopper.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/theme_controller.dart';

Future<void> openAppearanceSettings(BuildContext context) {
  final controller = ThemeScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => _AppearanceSheet(controller: controller),
  );
}

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 2,
                color: colors.divider,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'APARIENCIA',
              style: eyebrow(color: colors.contentMuted),
            ),
            const SizedBox(height: 8),
            Text(
              'Elige cómo se ve Monetta',
              style: editorial(24, color: colors.contentPrimary),
            ),
            const SizedBox(height: 18),
            _AppearanceOption(
              mode: ThemeMode.system,
              current: controller.mode,
              icon: Icons.brightness_auto_outlined,
              label: 'Automático',
              description: 'Usa la apariencia configurada en tu dispositivo.',
              onSelected: controller.setMode,
            ),
            _AppearanceOption(
              mode: ThemeMode.light,
              current: controller.mode,
              icon: Icons.light_mode_outlined,
              label: 'Claro',
              description: 'Mantiene fondos claros en todo momento.',
              onSelected: controller.setMode,
            ),
            _AppearanceOption(
              mode: ThemeMode.dark,
              current: controller.mode,
              icon: Icons.dark_mode_outlined,
              label: 'Oscuro',
              description: 'Reduce el brillo con superficies oscuras.',
              onSelected: controller.setMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.mode,
    required this.current,
    required this.icon,
    required this.label,
    required this.description,
    required this.onSelected,
  });

  final ThemeMode mode;
  final ThemeMode current;
  final IconData icon;
  final String label;
  final String description;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final selected = mode == current;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('appearance-${mode.name}'),
        onTap: () => onSelected(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: selected ? colors.accent : colors.contentMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: colors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: sans(size: 11, color: colors.contentMuted),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 18, color: colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}
