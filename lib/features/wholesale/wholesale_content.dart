/// Presentation placeholders: the mockup does not authorize commercial terms.
library;

import '../../app/shopper_copy.dart';

abstract final class WholesalePresentation {
  static const minimum = 'Mínimo de piezas: pendiente de confirmación.';
  static const pricing = 'Precios de mayoreo: pendientes de confirmación.';
  static const reservation =
      'Anticipo y plazo de liquidación: pendientes de confirmación.';
  static const shipping =
      'Costo, cobertura y plazo de envío: pendientes de confirmación.';
}

/// Reuses the configured channel without pre-accepting any commercial terms.
Uri wholesaleQuoteUri() => Uri.https('wa.me', '/$kWhatsAppE164', {
      'text':
          'Hola Monetta, quisiera información sobre mayoreo y sus condiciones vigentes.',
    });
