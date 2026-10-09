# Finding Resolution Changelog

Status: Updated after P0 remediation patch set
Date: 2026-10-09

## Status legend

- RESOLVED_IN_SPEC: documented and encoded in draft artifacts
- IMPLEMENTATION_PENDING: runtime feature not yet built
- VALIDATION_PENDING: disposable DB/runtime validation not yet executed
- NEEDS_APPROVAL: decision required before relevant gate

## Findings

### F-P0-001 API route conflicts
- Resolution: canonical /api/marketing/v1 retained and reconciled.
- Files: CANONICAL_API_CONTRACT.md, IMPLEMENTATION_GUIDE.md, architecture/onboarding/PRD docs.
- Status: RESOLVED_IN_SPEC

### F-P0-002 Tenant model conflicts
- Resolution: organizations model retained across docs and SQL.
- Files: CANONICAL_API_CONTRACT.md, DATABASE_SCHEMA_DESIGN.md, 001_initial_schema.sql.
- Status: RESOLVED_IN_SPEC

### F-P0-003 WhatsApp identity duplication risk
- Resolution: provider identity uniqueness retained in SQL.
- Files: 001_initial_schema.sql, DATABASE_SCHEMA_DESIGN.md.
- Status: RESOLVED_IN_SPEC, VALIDATION_PENDING

### F-P0-004 Tenant security hardening gap
- Resolution:
  - role model encoded in SQL (owner/app/service/bootstrap)
  - force RLS enabled
  - app role blocked from NULL-tenant global rows
  - service-only global workflow access
- Files: 001_initial_schema.sql, ADR_001_TENANT_SECURITY_AND_WORKER_HOSTING.md, DATABASE_SCHEMA_DESIGN.md.
- Status: RESOLVED_IN_SPEC, VALIDATION_PENDING

### F-P0-005 Missing bootstrap path definitions
- Resolution: bootstrap role workflows defined for register/login/reset/first-org/onboarding callback/webhook ingress.
- Files: 001_initial_schema.sql, CANONICAL_API_CONTRACT.md, DATABASE_SCHEMA_DESIGN.md.
- Status: RESOLVED_IN_SPEC, IMPLEMENTATION_PENDING, VALIDATION_PENDING

### F-P0-006 Migration target safety gap
- Resolution: migration runner design now mandates MARKETING_DATABASE_URL-only execution, URL equality rejection, explicit target identity allowlist and checksum/order checks.
- Files: MARKETING_MIGRATION_CONVENTION.md, 001_initial_schema.sql.
- Status: RESOLVED_IN_SPEC, IMPLEMENTATION_PENDING, NEEDS_APPROVAL (allowlist pattern)

### F-P0-007 Composite FK delete conflicts
- Resolution: conflicting composite `ON DELETE SET NULL` actions replaced with RESTRICT semantics.
- Files: 001_initial_schema.sql.
- Status: RESOLVED_IN_SPEC, VALIDATION_PENDING

### F-P0-008 Contract/schema misalignment
- Resolution: users.full_name, generic idempotency table, status-rank trigger enforcement and migration numbering examples reconciled.
- Files: 001_initial_schema.sql, CANONICAL_API_CONTRACT.md, DATABASE_SCHEMA_DESIGN.md, MARKETING_MIGRATION_CONVENTION.md.
- Status: RESOLVED_IN_SPEC, VALIDATION_PENDING

### F-P1 Shared-process operational decisions
- Resolution: still explicit decisions with defaults; not runtime-implemented.
- Files: ADR_001_TENANT_SECURITY_AND_WORKER_HOSTING.md, DEVELOPMENT_READINESS_CHECKLIST_REMEDIATED.md.
- Status: NEEDS_APPROVAL
