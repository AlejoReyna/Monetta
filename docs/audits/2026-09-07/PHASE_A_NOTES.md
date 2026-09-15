# Phase A / WP-01 notes — 2026-09-07

Findings: F01, F02, F19 (accounts/admin identity hardening).

## What changed

- F01: Removed runtime owner bootstrap from Monetta self-declared emails. ServerAdminAuthorizer only auto-bootstraps from OWNER_SHOPIFY_CUSTOMER_IDS. App-account owners require explicit admin_principals rows (see SQL below).
- F02: /accounts/register creates new accounts only; known deviceId returns 409 registration_conflict without altering the existing account.
- F19: Validation + rate limits on register/login; LEGACY_ACCOUNT_REGISTRATION_ENABLED closes new signups; generic conflict errors; reviewable principal SQL.

## Reviewable principal migration (dry-run first)

List candidates matching OWNER_ADMIN_EMAILS (informational only):

```sql
SELECT a.id, a.email, a.email_verified, p.id AS principal_id, p.active
FROM app_accounts a
LEFT JOIN admin_principals p ON p.subject_type = 'app_account' AND p.subject_id = a.id::text AND p.role = 'owner'
WHERE lower(a.email) = ANY(ARRAY[/* emails */]::text[]);
```

Provision one app account (replace UUID):

```sql
INSERT INTO admin_principals (id, subject_type, subject_id, role, active, created_by)
VALUES (gen_random_uuid(), 'app_account', '<account-uuid>', 'owner', TRUE, 'manual:phase-a')
ON CONFLICT (subject_type, subject_id, role) DO NOTHING;
```

Rollback / revoke:

```sql
UPDATE admin_principals SET active = FALSE, revoked_at = now() WHERE id = <principal-uuid>;
```

Do not mass-promote from email allowlists. Prefer OWNER_SHOPIFY_CUSTOMER_IDS or explicit UUID provision.

## Tests

- test/wp01Security.test.ts
- test/wp01Security.pg.test.ts
- test/adminApi.test.ts updated
