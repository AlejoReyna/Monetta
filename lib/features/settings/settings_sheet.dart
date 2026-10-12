/// App settings opened from the drawer's "Ajustes" gear row.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import 'appearance_sheet.dart';

Future<void> openAppSettings(BuildContext context) {
  final controller = ThemeScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: false,
    builder: (sheetContext) => _AppSettingsSheet(
      controller: controller,
      parentContext: context,
    ),
  );
}

class _AppSettingsSheet extends StatelessWidget {
  const _AppSettingsSheet({
    required this.controller,
    required this.parentContext,
  });

  final ThemeController controller;

  /// The context that opened this sheet. Used to close it before routing to
  /// a nested settings page, since the sheet's own context is deactivated by
  /// the pop.
  final BuildContext parentContext;

  String _modeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Oscuro',
        ThemeMode.system => 'Automático',
      };

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
              'AJUSTES',
              style: eyebrow(color: colors.contentMuted),
            ),
            const SizedBox(height: 8),
            Text(
              'Preferencias de la app',
              style: editorial(24, color: colors.contentPrimary),
            ),
            const SizedBox(height: 10),
            InkWell(
              key: const ValueKey('settings-appearance'),
              onTap: () {
                Navigator.of(parentContext).pop();
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => openAppearanceSettings(parentContext),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 21,
                      color: colors.contentPrimary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Apariencia',
                        style: sans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: colors.contentPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _modeLabel(controller.mode),
                      style: sans(size: 12, color: colors.contentMuted),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: colors.contentMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
