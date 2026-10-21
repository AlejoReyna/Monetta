/// Contenido comercial verificado de Mayoreo (paquete F).
///
/// Fuente: reglas ya publicadas en la app (`domain/editorial_content.dart`,
/// `app/shopper_copy.dart`, `features/partner/partner_hub_screen.dart`).
/// Las cantidades/precios de la figura 10 NO autorizan tarifas: aquí no hay
/// tabla de tramos inventada. Los tramos exactos se confirman al cotizar.
library;

import '../../app/shopper_copy.dart';

/// Reglas comerciales reales. Sin importes inventados.
class WholesaleTerms {
  const WholesaleTerms._();

  /// Pedido de mayoreo a partir de esta cantidad de modelos.
  static const int minModels = 3;

  static const String depositWholesale = r'$800 MXN';
  static const String depositRetail = r'$400 MXN';
  static const int payOffDays = 20;

  static const String whatsappDisplay = kWhatsAppNumberDisplay;

  static const List<WholesaleCondition> conditions = [
    WholesaleCondition(
      icon: 'piezas',
      title: 'Desde 3 modelos',
      body: 'El mayoreo comienza desde 3 modelos. Sin monto mínimo publicado.',
    ),
    WholesaleCondition(
      icon: 'anticipo',
      title: r'Anticipo de $800 MXN',
      body: 'Apartado manual por WhatsApp: Monetta confirma disponibilidad, '
          'registra el anticipo y crea el pedido en Shopify.',
    ),
    WholesaleCondition(
      icon: 'plazo',
      title: 'Liquida en 20 días',
      body: 'Tienes hasta 20 días para liquidar tu pedido de mayoreo.',
    ),
    WholesaleCondition(
      icon: 'original',
      title: '100% originales',
      body: 'Boutique verificada como empresa en Estados Unidos: '
          'Monetta Wholesale LLC.',
    ),
  ];

  static const List<WholesaleStep> steps = [
    WholesaleStep(
      number: '01',
      title: 'Elige tus modelos',
      body: 'Explora el catálogo o usa el creador de catálogo para armar '
          'tu selección con precios e imágenes reales.',
    ),
    WholesaleStep(
      number: '02',
      title: 'Cotiza por WhatsApp',
      body: 'Envíanos tus modelos al 826 106 6868. Te confirmamos '
          'disponibilidad y precio de mayoreo por producto.',
    ),
    WholesaleStep(
      number: '03',
      title: 'Aparta y liquida',
      body: r'Aparta con $800 MXN y liquida en hasta 20 días. Abrir el chat '
          'no reserva stock ni crea el pedido automáticamente.',
    ),
  ];

  static const String volumePricingNote =
      'El precio de mayoreo se define por producto al cotizar: a mayor '
      'volumen, mejor precio. Los tramos exactos se confirman por WhatsApp '
      'con tus modelos elegidos; la app no publica tarifas por tramo.';

  static const String rewardsNote =
      'Las compras de mayoreo no generan Monetta Rewards en V1. '
      'El uso de saldo en mayoreo aún no está definido.';

  static const List<String> paymentMethods = [
    'Transferencia y depósito bancario',
    'Tarjetas de crédito o débito',
    'PayPal, Apple Pay y Mercado Pago',
  ];

  static const String shipping =
      'Enviamos a todo México por FedEx, Estafeta y DHL. '
      'La entrega toma entre 2 y 7 días hábiles según tu ubicación.';

  static const String returns =
      'Tienes 48 horas desde la entrega para aclaraciones, cambios o '
      'devoluciones, y 72 horas para modificar apartados o cotizaciones.';
}

class WholesaleCondition {
  const WholesaleCondition({
    required this.icon,
    required this.title,
    required this.body,
  });

  final String icon;
  final String title;
  final String body;
}

class WholesaleStep {
  const WholesaleStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;
}

/// URI de cotización con los términos públicos ya comprendidos.
Uri wholesaleQuoteUri() => partnerQuoteWhatsAppUri();
