# SCIMIOR MARKETING

## Implementation Guide (Remediated)

Status: Authoritative for pre-development remediation
Date: 2026-10-09

## 1. Scope

This guide defines the implementation baseline after pre-development remediation.

This phase does not implement product features. It aligns documentation and schema only.

## 2. Canonical decisions

- API prefix: /api/marketing/v1
- Tenant model: organizations, organization_members, organization_id
- Independent Marketing authentication/sessions/authorization
- Marketing DB isolated from Scimior DB with separate credentials and pool
- No Prisma
- Marketing repositories must not query Scimior tables directly
- Optional Scimior integration only through provider/API adapter interfaces
- Marketing module runs inside the existing Node.js deployment for MVP

## 3. Authoritative documents

- CANONICAL_API_CONTRACT.md
- DATABASE_SCHEMA_DESIGN.md
- 001_initial_schema.sql
- ADR_001_TENANT_SECURITY_AND_WORKER_HOSTING.md
- MARKETING_MIGRATION_CONVENTION.md
- DEVELOPMENT_READINESS_CHECKLIST_REMEDIATED.md

If older content conflicts with these documents, the above list wins.

## 4. Non-negotiable engineering boundaries

- No direct Marketing SQL against Scimior DB objects.
- No reuse of salon-coupled Scimior middleware for Marketing auth/tenant checks.
- No in-memory-only campaign queue or timer-only scheduling.
- Webhook processing must be signature-verified, replay-safe, and out-of-order tolerant.

## 5. Operational assumptions requiring verification

- Render CPU/memory and process behavior under worker load.
- PostgreSQL version and extension support (pgcrypto).
- Total connection budget for coexistence of Scimior + Marketing pools.

All such items are tracked in DEVELOPMENT_READINESS_CHECKLIST_REMEDIATED.md.
