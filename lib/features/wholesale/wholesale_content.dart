/// Wholesale copy, taken as it is from the owner's guide («MAYOREO»).
library;

import '../../app/shopper_copy.dart';

abstract final class WholesalePresentation {
  /// Step 2 of «¿Cómo comprar?». The title is «Agrega mínimo 3 piezas».
  static const minimum =
      'Obtén 10% de descuento en cualquier producto al elegir 3 o más piezas. '
      'Todas las colecciones están incluidas.';

  /// Step 3 of «¿Cómo comprar?». The title is «Liquida o aparta».
  static const reservation =
      'Aparta por 20 días con \$800 MXN de anticipo por todo el pedido en '
      'mayoreo (3+ piezas) o \$400 MXN en menudeo (1–2 piezas).';

  /// Shipping line. Free with Monetta Rewards account, $199 MXN as guest.
  static const shipping =
      'Envío gratis con tu cuenta Monetta Rewards (\$199 MXN como invitado a todo México).';
}

/// Reuses the configured channel without pre-accepting any commercial terms.
Uri wholesaleQuoteUri() => Uri.https('wa.me', '/$kWhatsAppE164');
