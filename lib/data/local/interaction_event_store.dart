/// Persists the behavioural event log `reco/` learns from
/// (`reco/events.dart#InteractionEvent`). Device-scoped only, permanently —
/// see `tables.dart`'s `InteractionEvents` doc comment for why this table
/// never gains an `accountId` column.
library;

import 'package:drift/drift.dart';

import '../../reco/events.dart';
// Drift generates a row data class named `InteractionEvent` for the
// `InteractionEvents` table — hidden here so the name unambiguously means
// `reco/events.dart`'s `InteractionEvent` throughout this file. Row values
// are consumed via inferred typing below, so the generated class is never
// needed by name.
import 'database.dart' hide InteractionEvent;

class InteractionEventStore {
  InteractionEventStore(this._db);

  final AppDatabase _db;

  Future<void> record(InteractionEvent event) {
    return _db.into(_db.interactionEvents).insert(
          InteractionEventsCompanion.insert(
            type: event.type.name,
            timestamp: event.timestamp,
            productId: Value(event.productId),
            dwellMs: Value(event.dwellMs),
            facetHint: Value(event.facetHint),
          ),
        );
  }

  /// Oldest first, matching the order `ProfileBuilder.build` expects.
  Future<List<InteractionEvent>> all() async {
    final rows = await (_db.select(_db.interactionEvents)
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
    return [
      for (final row in rows)
        InteractionEvent(
          type: EventType.values.byName(row.type),
          timestamp: row.timestamp.toUtc(),
          productId: row.productId,
          dwellMs: row.dwellMs,
          facetHint: row.facetHint,
        ),
    ];
  }
}
