# Marketing Migration Convention

Status: Canonical process for Marketing DB migrations
Date: 2026-10-09

## 1. Scope

This convention applies only to the Marketing database.

- Never run Marketing migrations against Scimior production database.
- Marketing migration history is independent from Scimior migration history.

## 2. Naming and ordering

- Deterministic numeric ordering with zero padding:
  - 001_initial_schema.sql
  - 002_add_terms_acceptance.sql
  - 003_add_campaign_retry_controls.sql
- Do not reuse or duplicate migration numbers.
- Never edit an applied migration; add a new migration.

## 3. Tracking table

Maintain a migration tracking table in Marketing DB:

- schema_migrations
  - version (text primary key)
  - checksum (text)
  - applied_at (timestamptz)
  - applied_by (text)

Migration runner must verify checksum before marking applied.

## 4. Environment promotion

Order:
1. local dev
2. shared dev
3. staging
4. production

Promotion requirements:
- SQL review complete
- rollback/recovery documented
- dry-run/static validation completed
- compatibility notes reviewed

## 5. Rollback and recovery guidance

- Prefer forward-fix migrations over destructive rollbacks.
- For destructive changes, include explicit backup and restore notes.
- If partial apply occurs, halt promotion and create a recovery migration.

## 6. Safety controls

- Migration scripts require MARKETING_DATABASE_URL.
- Runner must reject SCIMIOR_DATABASE_URL targets by name/allowlist checks.
- Runner prints target DB identity and requires explicit confirmation in non-CI interactive mode.

NEEDS APPROVAL: exact allowlist pattern for production database hostnames.

## 7. Required migration header template

Each migration must begin with:

- purpose
- risk classification (low/medium/high)
- backward compatibility note
- rollback/recovery plan
- verification queries

## 8. Verification checklist per migration

- constraints validated
- required indexes present
- RLS/policies validated for new tenant tables
- query plans checked for critical paths
- schema_migrations updated
