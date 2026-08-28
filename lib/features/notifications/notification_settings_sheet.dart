/// Shopper-facing consent controls. The OS prompt only appears after Save.
library;

import 'package:flutter/material.dart';

import '../../app/notification_controller.dart';
import '../../app/theme.dart';
import '../../data/notifications/notification_models.dart';

Future<void> openNotificationSettings(
  BuildContext context, {
  required NotificationController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (_) => _NotificationSettingsSheet(controller: controller),
  );
}

class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet({required this.controller});

  final NotificationController controller;

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  late NotificationPreferences _value;

  @override
  void initState() {
    super.initState();
    _value = widget.controller.preferences;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 14, 24, bottom + 28),
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kLine,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Tus notificaciones', style: display(27)),
              const SizedBox(height: 8),
              Text(
                'Tú eliges qué recibir. Tu navegación detallada se queda en '
                'este dispositivo; sólo sincronizamos intereses resumidos '
                'cuando activas ofertas personalizadas.',
                style: sans(size: 12, color: kInkMuted, height: 1.5),
              ),
              const SizedBox(height: 20),
              _PreferenceSwitch(
                key: const ValueKey('notification-product-alerts'),
                title: 'Avisos que solicitaste',
                description: 'Regreso de piezas agotadas y bajas de precio.',
                value: _value.productAlerts,
                onChanged: (value) => setState(
                  () => _value = _value.copyWith(productAlerts: value),
                ),
              ),
              _PreferenceSwitch(
                key: const ValueKey('notification-personalized-offers'),
                title: 'Ofertas para ti',
                description:
                    'Novedades según tus marcas y categorías favoritas.',
                value: _value.personalizedOffers,
                onChanged: (value) => setState(
                  () => _value = _value.copyWith(personalizedOffers: value),
                ),
              ),
              _PreferenceSwitch(
                key: const ValueKey('notification-announcements'),
                title: 'Anuncios de Monetta',
                description: 'Campañas generales y noticias de la tienda.',
                value: _value.announcements,
                onChanged: (value) => setState(
                  () => _value = _value.copyWith(announcements: value),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Horario silencioso: 9:00 p.m. a 9:00 a.m.',
                style: sans(size: 11, color: kInkMuted),
              ),
              if (!widget.controller.available) ...[
                const SizedBox(height: 12),
                Text(
                  'Las notificaciones aún no están configuradas en esta versión.',
                  style: sans(size: 11, color: kInkMuted),
                ),
              ],
              if (widget.controller.lastError != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.controller.lastError!,
                  style: sans(size: 11, color: Colors.red.shade700),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                key: const ValueKey('save-notification-preferences'),
                onPressed:
                    !widget.controller.available || widget.controller.saving
                        ? null
                        : _save,
                child: widget.controller.saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('GUARDAR PREFERENCIAS'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final ok = await widget.controller.savePreferences(_value);
    if (!mounted || !ok) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Preferencias de notificaciones guardadas.'),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: sans(size: 13, weight: FontWeight.w600)),
      subtitle: Text(
        description,
        style: sans(size: 11, color: kInkMuted, height: 1.35),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
