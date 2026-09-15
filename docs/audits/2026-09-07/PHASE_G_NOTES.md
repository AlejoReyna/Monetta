# Phase G / WP-07 notes (F27–F30)

## Closed / partial in this commit

| Finding | Status | Notes |
|---|---|---|
| F27 | partial→docs+copy | SOP + UI/FAQ copy honestos; WhatsApp no reserva/cobra/crea pedido/aprueba reseller. |
| F28 | partial | Deep link collection→`collectionHandle`; reject `external:` engagement keys/events; ignore `external:` product routes. Device push (APNs/FCM/App Check/consent on real devices) still owner-gated. |
| F29 | partial→stronger | privacy fulfill/list admin API + redact evidence + ops/backup/rollback docs; `/readyz` already present from Phase E. Full synthetic export package still operator-run. |
| F30 | partial→fixed gates | `integration_test/` harness; narrow CI fixture exception with content validation; home tests drop retired `ExternalCatalogScope`; format paths include integration_test. |

## Device-only / owner follow-ups

1. Provision Firebase per app id, APNs/FCM, App Check, worker secrets; enable `NOTIFICATIONS_ENABLED` only on staging first.
2. Cold-start + foreground push on physical iOS/Android; opt-out suppression; token rotation; cancel/report paths.
3. Isolated test campaign audience only — never production lists.
4. Run backup restore drill on disposable DB and attach evidence.
5. Business owner confirms apartado phone/groups/catalog link validity and whether wholesale links must become private.
6. Prefer FVM-pinned Flutter in CI when ready (`.fvmrc` still `stable`).

## Cart reminders

Local cart reminders cancel when bag quantity hits 0 (post-checkout clear). They are not paid-order confirmations. Do not treat checkout callback as capture.
