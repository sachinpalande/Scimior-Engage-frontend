# Scimior Marketing Implementation Checklist (Remediated)

Status: Canonical checklist
Date: 2026-10-09

## 1. Read order

1. IMPLEMENTATION_GUIDE.md
2. CANONICAL_API_CONTRACT.md
3. DATABASE_SCHEMA_DESIGN.md
4. 001_initial_schema.sql
5. ADR_001_TENANT_SECURITY_AND_WORKER_HOSTING.md
6. MARKETING_MIGRATION_CONVENTION.md
7. DEVELOPMENT_READINESS_CHECKLIST_REMEDIATED.md
8. FINDING_RESOLUTION_CHANGELOG.md

## 2. Non-negotiable constraints

- /api/marketing/v1 only
- organizations model only
- independent Marketing auth and tenant authorization
- no Prisma
- no direct Scimior DB queries
- separate Marketing DB credentials, pool, and migration history
- no unrelated Flutter changes

## 3. Operational prerequisites

- Render limits verified
- PostgreSQL version/extensions verified
- connection budgets approved

## 4. Decision gates

Any unresolved item marked NEEDS APPROVAL blocks implementation start.
