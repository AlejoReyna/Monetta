/// Wholesale copy, taken as it is from the owner's guide («MAYOREO»).
library;

import '../../app/shopper_copy.dart';

abstract final class WholesalePresentation {
  /// Step 2 of «¿Cómo comprar?». The title is «Agrega mínimo 3 piezas».
  static const minimum =
      'a tu carrito o mándanos captura de los modelos de tu interés por '
      'WhatsApp.';

  /// Step 3 of «¿Cómo comprar?». The title is «Liquida o aparta».
  static const reservation = 'Aparta por 20 días con \$800 pesos por pedido.';

  /// Shipping line. The services row repeats it as «Envío gratis».
  static const shipping = 'Envío gratis en compras mayores a \$1,999 MXN.';
}

/// Reuses the configured channel without pre-accepting any commercial terms.
Uri wholesaleQuoteUri() => Uri.https('wa.me', '/$kWhatsAppE164', {
      'text':
          'Hola Monetta, quisiera información sobre mayoreo y sus condiciones vigentes.',
    });
