import 'dart:async';

import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/domain/product.dart';

/// A [CatalogStore] whose `addToBag` can be observed, held and made to fail.
///
/// Purchase surfaces (ficha dock, quick view, card "+") are driven through the
/// store, so the tests that pin pending and failure behaviour need a seam that
/// is deterministic: no clock, no timers, only a [Completer] and a flag.
///
/// * [addCalls] counts every call that reaches the store, including the ones
///   that are held or made to fail.
/// * While [hold] is non-null the call waits for its future before going on.
/// * While [failWith] is non-null the call throws it instead of reaching
///   `super.addToBag`, so the bag is untouched.
/// * Otherwise it is the real [CatalogStore.addToBag].
class ScriptedCatalogStore extends CatalogStore {
  ScriptedCatalogStore({required super.database});

  int addCalls = 0;
  Completer<void>? hold;
  Object? failWith;

  @override
  Future<void> addToBag(Product product, {String? variantId}) async {
    addCalls++;
    final gate = hold;
    if (gate != null) await gate.future;
    final error = failWith;
    if (error != null) throw error;
    await super.addToBag(product, variantId: variantId);
  }
}
