/// The behavioural signals the recommender learns from.
///
/// Pure Dart. These events are written to Drift by `data/local` and **never
/// leave the device** in Phase 1 — see `lib/reco/README.md` § Privacy.
library;

/// A thing the user did, and how much it says about their taste.
///
/// Weights are ordinal, not scientific: what matters is the *ratio* between
/// them. A purchase says roughly 100× more than an impression, and a WhatsApp
/// apartado says nearly as much as a purchase because on this store it very
/// often becomes one.
enum EventType {
  /// Product scrolled past in a grid. Deliberately tiny, and capped per session
  /// (see `ProfileBuilder.maxImpressionsPerSession`) — otherwise a single long
  /// scroll would drown out every deliberate action.
  impression(0.1),

  /// Opened the product detail page. Scaled further by dwell time.
  productView(1.0),

  /// Zoomed or swiped the image gallery. In this category people who are
  /// seriously considering a bag look at it closely, so this outranks a plain
  /// view.
  galleryInteraction(1.5),

  /// Ran a search or applied a filter. An explicitly stated preference, which
  /// is worth more than an inferred one.
  searchOrFilter(2.0),

  wishlistAdd(4.0),

  addToCart(6.0),

  /// Started the WhatsApp apartado flow. Weighted just below a purchase because
  /// on this store the layaway *is* the purchase for a large share of orders.
  whatsappApartado(8.0),

  purchase(10.0),

  /// Negative signal: removed from wishlist. Real evidence of a *rejected*
  /// preference, which is rarer and therefore valuable.
  wishlistRemove(-4.0);

  const EventType(this.weight);

  final double weight;

  bool get isNegative => weight < 0;
}

/// One recorded interaction.
class InteractionEvent {
  const InteractionEvent({
    required this.type,
    required this.timestamp,
    this.productId,
    this.dwellMs,
    this.facetHint,
  });

  final EventType type;
  final DateTime timestamp;

  /// Null for events not tied to a product, e.g. a bare search.
  final String? productId;

  /// Time on the product page, for [EventType.productView].
  final int? dwellMs;

  /// For search/filter events, the facet the user explicitly asked for,
  /// e.g. `brand:guess` or `silhouette:crossbody`. Lets a filter teach the
  /// profile even when the user never opens a product.
  final String? facetHint;

  /// Dwell-time multiplier, 0.5×–2.0×, saturating at 60 s.
  ///
  /// A 2-second bounce should count for less than a 45-second read, but the
  /// curve is capped at both ends: below 0.5 a misclick would erase real
  /// signal, and above 2.0 a phone left unlocked on a product page would
  /// dominate the whole profile.
  double get dwellMultiplier {
    if (type != EventType.productView || dwellMs == null) return 1;
    const capMs = 60000;
    final clamped = dwellMs!.clamp(0, capMs);
    return 0.5 + (clamped / capMs) * 1.5;
  }

  /// Final signed weight of this event before time decay.
  double get rawWeight => type.weight * dwellMultiplier;
}
