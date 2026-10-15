/// Device flag that banner 3 is active.
///
/// DUP-03 stores only a boolean and the UTC timestamp of the uncertain
/// return. The cart token is never written. The warning lasts 24 hours, and
/// DUP-04 clears it only when the bag is emptied, checkout completes, a
/// matching order is found, or that window ends. Editing quantities or
/// replacing the Shopify cart does not clear it.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/catalog_store.dart';

const Duration kCheckoutReviewingWarningLifetime = Duration(hours: 24);

const String kCheckoutReviewingWarningFlagKey =
    'monetta.checkout_reviewing_warning';

const String kCheckoutReviewingWarningAtKey =
    'monetta.checkout_reviewing_warning_at_ms';

/// The moment banner 3 became active. There is no cart token on this record.
final class ReviewingWarningRecord {
  const ReviewingWarningRecord({required this.markedAt});

  final DateTime markedAt;
}

abstract interface class ReviewingWarningStore {
  Future<ReviewingWarningRecord?> read();

  /// Pass null to remove the flag and the timestamp.
  Future<void> write(ReviewingWarningRecord? record);
}

final class SharedPreferencesReviewingWarningStore
    implements ReviewingWarningStore {
  SharedPreferencesReviewingWarningStore(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesReviewingWarningStore> open() async {
    return SharedPreferencesReviewingWarningStore(
      await SharedPreferences.getInstance(),
    );
  }

  @override
  Future<ReviewingWarningRecord?> read() async {
    final active =
        _preferences.getBool(kCheckoutReviewingWarningFlagKey) ?? false;
    final millis = _preferences.getInt(kCheckoutReviewingWarningAtKey);
    if (!active || millis == null) return null;
    return ReviewingWarningRecord(
      markedAt: DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
    );
  }

  @override
  Future<void> write(ReviewingWarningRecord? record) async {
    if (record == null) {
      await _preferences.remove(kCheckoutReviewingWarningFlagKey);
      await _preferences.remove(kCheckoutReviewingWarningAtKey);
      return;
    }
    await _preferences.setBool(kCheckoutReviewingWarningFlagKey, true);
    await _preferences.setInt(
      kCheckoutReviewingWarningAtKey,
      record.markedAt.toUtc().millisecondsSinceEpoch,
    );
  }
}

final class ReviewingCheckoutCart extends ChangeNotifier {
  ReviewingCheckoutCart({
    ReviewingWarningStore? store,
    Future<ReviewingWarningStore>? storeLoader,
    DateTime Function()? clock,
  })  : _store = store,
        _storeLoader = storeLoader,
        _clock = clock ?? DateTime.now;

  ReviewingWarningStore? _store;
  final Future<ReviewingWarningStore>? _storeLoader;
  final DateTime Function() _clock;

  bool _flag = false;
  DateTime? _markedAt;
  bool _loaded = false;
  int _generation = 0;
  Future<void>? _loading;
  Future<void> _pending = Future<void>.value();

  bool get isActive {
    final markedAt = _markedAt;
    if (!_flag || markedAt == null) return false;
    return _clock().difference(markedAt) < kCheckoutReviewingWarningLifetime;
  }

  /// Waits until the latest flag write has finished.
  Future<void> flush() => _pending;

  /// Reads the on-device flag once. Later [markActive] and [clear] calls win
  /// over an in-flight read.
  Future<void> ensureLoaded() {
    if (_loaded) return _pending;
    return _loading ??= _load();
  }

  /// Starts a fresh 24-hour window for the current uncertain return.
  void markActive() {
    _generation += 1;
    _loaded = true;
    _flag = true;
    _markedAt = _clock().toUtc();
    notifyListeners();
    _scheduleWrite();
  }

  void clear() {
    if (!_flag && _markedAt == null) return;
    _generation += 1;
    _loaded = true;
    _flag = false;
    _markedAt = null;
    notifyListeners();
    _scheduleWrite();
  }

  /// Clears only when the shopper's bag itself is empty.
  void noteBag({required bool emptied}) {
    if (emptied) clear();
  }

  /// Drops a warning whose 24-hour window has already ended.
  void expireIfDue() {
    if (isActive || !_flag) return;
    clear();
  }

  /// True when checkout must show the double-charge sheet.
  bool blocksCheckout({required bool bagEmpty}) {
    expireIfDue();
    return isActive && !bagEmpty;
  }

  Future<void> _load() async {
    final generation = _generation;
    final store = await _resolveStore();
    if (generation != _generation) {
      _loaded = true;
      return;
    }
    final record = store == null ? null : await store.read();
    if (generation != _generation) {
      _loaded = true;
      return;
    }
    _flag = record != null;
    _markedAt = record?.markedAt.toUtc();
    _loaded = true;
    if (_flag && !isActive) {
      _flag = false;
      _markedAt = null;
      _scheduleWrite();
    }
    notifyListeners();
  }

  Future<ReviewingWarningStore?> _resolveStore() async {
    final existing = _store;
    if (existing != null) return existing;
    final loader = _storeLoader;
    if (loader == null) return null;
    final loaded = await loader;
    return _store ??= loaded;
  }

  void _scheduleWrite() {
    _pending = _pending.then((_) async {
      final store = await _resolveStore();
      if (store == null) return;
      final markedAt = _markedAt;
      if (!_flag || markedAt == null) {
        await store.write(null);
        return;
      }
      await store.write(ReviewingWarningRecord(markedAt: markedAt));
    });
  }

  @override
  String toString() => 'ReviewingCheckoutCart(active: $isActive)';
}

class ReviewingCheckoutScope extends InheritedNotifier<ReviewingCheckoutCart> {
  const ReviewingCheckoutScope({
    required ReviewingCheckoutCart super.notifier,
    required super.child,
    super.key,
  });

  static ReviewingCheckoutCart? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ReviewingCheckoutScope>()
        ?.notifier;
  }
}

/// Restores the on-device warning above the navigator and clears it when the
/// local bag becomes empty. Cart-token changes are ignored.
class ReviewingCheckoutHost extends StatefulWidget {
  const ReviewingCheckoutHost({
    required this.child,
    this.bag,
    this.reviewing,
    this.store,
    this.clock,
    super.key,
  });

  final CatalogStore? bag;

  /// When null, this host creates one and restores it from [store] or from
  /// shared preferences.
  final ReviewingCheckoutCart? reviewing;
  final ReviewingWarningStore? store;
  final DateTime Function()? clock;
  final Widget child;

  @override
  State<ReviewingCheckoutHost> createState() => _ReviewingCheckoutHostState();
}

class _ReviewingCheckoutHostState extends State<ReviewingCheckoutHost> {
  ReviewingCheckoutCart? _owned;
  CatalogStore? _bag;

  ReviewingCheckoutCart get _reviewing => widget.reviewing ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.reviewing == null) {
      _owned = ReviewingCheckoutCart(
        store: widget.store,
        storeLoader: widget.store == null
            ? SharedPreferencesReviewingWarningStore.open()
            : null,
        clock: widget.clock,
      );
      unawaited(
        _owned!.ensureLoaded().then((_) {
          if (mounted) _onBag();
        }),
      );
    }
    _bag = widget.bag;
    _bag?.addListener(_onBag);
    if (widget.reviewing != null) _onBag();
  }

  @override
  void didUpdateWidget(ReviewingCheckoutHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bag == widget.bag) return;
    _bag?.removeListener(_onBag);
    _bag = widget.bag;
    _bag?.addListener(_onBag);
  }

  @override
  void dispose() {
    _bag?.removeListener(_onBag);
    _owned?.dispose();
    super.dispose();
  }

  void _onBag() {
    final bag = _bag;
    if (bag == null) return;
    _reviewing.noteBag(emptied: bag.bagQuantity == 0);
  }

  @override
  Widget build(BuildContext context) {
    return ReviewingCheckoutScope(
      notifier: _reviewing,
      child: widget.child,
    );
  }
}
