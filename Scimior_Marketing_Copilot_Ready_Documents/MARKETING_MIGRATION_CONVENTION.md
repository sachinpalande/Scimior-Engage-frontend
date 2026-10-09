# Marketing Migration Convention

Status: Updated with runner design
Date: 2026-10-09

## 1. Scope

Applies only to Marketing database migrations.

Never run Marketing migrations against Scimior or shared/production DB in this phase.

## 2. Versioning and numbering

- Strict numeric ordering with zero padding.
- Never edit applied migration files.
- Next example versions after 001:
  - 002_add_provider_signature_materialization.sql
  - 003_add_retention_policy_indexes.sql

## 3. Required runner behavior (mandatory)

Runner must read only:
- MARKETING_DATABASE_URL
- SCIMIOR_DATABASE_URL (for anti-target-equality checks)

Runner must fail fast when:
- MARKETING_DATABASE_URL is missing.
- MARKETING_DATABASE_URL equals SCIMIOR_DATABASE_URL.
- Parsed target identity is not in approved allowlist.
- schema_migrations checksum mismatch is detected.
- migration order is non-sequential.

NEEDS APPROVAL: exact approved identity allowlist pattern.
Recommended default: exact host + database name allowlist, no wildcard database names.

## 4. Target identity validation

Before execution, runner must parse and print non-secret identity fields:
- host
- port
- database name
- ssl mode

Then validate against approved allowlist and abort on mismatch.

## 5. Tracking and checksums

Use schema_migrations:
- version (PK)
- checksum
- applied_at
- applied_by

Runner algorithm:
1. Discover migration files in sorted order.
2. Compute checksum for each file.
3. Compare with applied records.
4. Abort on divergence.
5. Apply pending migrations in order inside transactions when safe.
6. Insert schema_migrations row only after success.

## 6. Safe stop behavior

On mismatch or error:
- do not continue to later migrations
- emit clear failure reason
- return non-zero exit code

## 7. Execution modes

- `dry-run`: parse files, evaluate order/checksums/target identity only.
- `apply`: execute pending migrations after successful dry-run checks.

## 8. Validation checklist per migration

- constraints and indexes present
- role/grant and RLS policy checks pass
- FK delete-action checks pass
- relevant smoke verification queries documented

## 9. Validation status in this workspace

Runner implementation: NOT IMPLEMENTED (spec-only).
Disposable PostgreSQL apply test: NOT RUN.
