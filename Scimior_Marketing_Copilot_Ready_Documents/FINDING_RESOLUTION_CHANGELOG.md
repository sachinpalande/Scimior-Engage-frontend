# Finding Resolution Changelog

Status: Remediation traceability log
Date: 2026-10-09

## Mapping format

- Finding ID
- Original severity
- Resolution summary
- Files changed
- Residual status

## Resolutions

### F-P0-001 (Critical) API route conflicts
- Resolution: Canonical API contract standardized to /api/marketing/v1; legacy route examples marked non-normative.
- Files changed:
  - CANONICAL_API_CONTRACT.md
  - IMPLEMENTATION_GUIDE.md
  - Scimior_Marketing_Architecture_Design_UPDATED.md
  - Scimior_Marketing_User_Registration_WhatsApp_Onboarding_UPDATED.md
  - WhatsApp_Marketing_Application_Detailed_PRD_UPDATED.md
  - whatsappMarketing_UPDATED.md
- Residual: CLOSED

### F-P0-002 (Critical) Tenant model conflict
- Resolution: Canonical model set to organizations / organization_members / organization_id across specs.
- Files changed:
  - CANONICAL_API_CONTRACT.md
  - DATABASE_SCHEMA_DESIGN.md
  - Scimior_Marketing_User_Registration_WhatsApp_Onboarding_UPDATED.md
  - WhatsApp_Marketing_Application_Detailed_PRD_UPDATED.md
- Residual: CLOSED

### F-P0-003 (Critical) WhatsApp asset duplication risk
- Resolution: SQL now enforces global provider identity uniqueness for key WhatsApp assets.
- Files changed:
  - 001_initial_schema.sql
  - DATABASE_SCHEMA_DESIGN.md
- Residual: CLOSED

### F-P0-004 (Critical) Missing DB tenant hardening
- Resolution: RLS-based tenant security model documented and encoded in SQL policies.
- Files changed:
  - 001_initial_schema.sql
  - DATABASE_SCHEMA_DESIGN.md
  - ADR_001_TENANT_SECURITY_AND_WORKER_HOSTING.md
- Residual: CLOSED

### F-P1-001 (High) Missing graceful worker shutdown spec
- Resolution: Worker lifecycle and graceful shutdown spec added.
- Files changed:
  - ADR_001_TENANT_SECURITY_AND_WORKER_HOSTING.md
  - DATABASE_SCHEMA_DESIGN.md
- Residual: CLOSED

### F-P1-002 (High) Shared process contention risk
- Resolution: Concurrency and pool-budget controls documented.
- Files changed:
  - ADR_001_TENANT_SECURITY_AND_WORKER_HOSTING.md
  - DEVELOPMENT_READINESS_CHECKLIST_REMEDIATED.md
- Residual: NEEDS APPROVAL (exact limits)

### F-P1-003 (High) Marketing CORS domain not listed in backend defaults
- Resolution: Documented as implementation prerequisite for launch configuration.
- Files changed:
  - IMPLEMENTATION_GUIDE.md
  - DEVELOPMENT_READINESS_CHECKLIST_REMEDIATED.md
- Residual: NEEDS APPROVAL (final allowed-origin set)

### F-P1-004 (High) No webhook verification pattern
- Resolution: Canonical verification, replay and out-of-order handling requirements formalized.
- Files changed:
  - CANONICAL_API_CONTRACT.md
  - DATABASE_SCHEMA_DESIGN.md
  - 001_initial_schema.sql
- Residual: CLOSED

### F-P1-005 (High) Migration governance risk
- Resolution: Dedicated Marketing migration convention defined.
- Files changed:
  - MARKETING_MIGRATION_CONVENTION.md
  - DATABASE_SCHEMA_DESIGN.md
- Residual: CLOSED

### F-P1-006 (High) Salon-coupled auth reuse risk
- Resolution: Independent Marketing auth/authorization model specified.
- Files changed:
  - CANONICAL_API_CONTRACT.md
  - IMPLEMENTATION_GUIDE.md
  - Scimior_Marketing_User_Registration_WhatsApp_Onboarding_UPDATED.md
- Residual: CLOSED

### F-P2-002 (Medium) Missing terms/privacy acceptance schema
- Resolution: user_terms_acceptance table and related requirements added.
- Files changed:
  - 001_initial_schema.sql
  - DATABASE_SCHEMA_DESIGN.md
  - CANONICAL_API_CONTRACT.md
- Residual: CLOSED

### F-P2-003 (Medium) Event dedup transition ambiguity
- Resolution: dedup and out-of-order constraints and transition guards documented; SQL dedup indexes added.
- Files changed:
  - 001_initial_schema.sql
  - DATABASE_SCHEMA_DESIGN.md
  - CANONICAL_API_CONTRACT.md
- Residual: CLOSED
