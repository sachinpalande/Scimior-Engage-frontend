# Scimior Marketing Copilot-ready document set

Updated on 9 October 2026.

## Canonical document order

1. IMPLEMENTATION_GUIDE.md
2. CANONICAL_API_CONTRACT.md
3. DATABASE_SCHEMA_DESIGN.md
4. 001_initial_schema.sql
5. ADR_001_TENANT_SECURITY_AND_WORKER_HOSTING.md
6. MARKETING_MIGRATION_CONVENTION.md
7. DEVELOPMENT_READINESS_CHECKLIST_REMEDIATED.md
8. FINDING_RESOLUTION_CHANGELOG.md

## Canonical baseline

- API prefix: /api/marketing/v1
- Tenant model: organizations, organization_members, organization_id
- Independent Marketing authentication and authorization
- Separate Marketing PostgreSQL database, credentials, pool and migration history
- No Prisma
- No direct queries against Scimior DB tables
- Optional Scimior integration only through explicit provider/API adapters
- Marketing backend module hosted in existing Node.js deployment for MVP

## Notes

- Legacy route examples outside /api/marketing/v1 are non-normative.
- Legacy references to businesses/business_members are non-normative.
- The dashboard image remains a visual reference only.
- SQL remains draft and must be validated in a disposable development environment before any deployment.
