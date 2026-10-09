# Development Readiness Checklist (Remediated)

Status: Must pass before implementation starts
Date: 2026-10-09

## P0 Closure

- [ ] All docs consistently use /api/marketing/v1 only.
- [ ] All docs consistently use organizations, organization_members, organization_id only.
- [ ] Canonical API contract approved.
- [ ] WhatsApp asset uniqueness scope approved and encoded in SQL.
- [ ] Tenant security approach approved (RLS + role model).
- [ ] Terms/privacy acceptance persistence model approved and encoded in SQL.

## P1 Closure

- [ ] Worker lifecycle and graceful shutdown specification approved.
- [ ] Pool budgets approved for shared process operation. NEEDS APPROVAL
- [ ] Per-organization concurrency budgets approved. NEEDS APPROVAL
- [ ] Webhook verification and replay/dedup strategy approved.
- [ ] Migration convention approved and isolated from Scimior DB.

## Operational verification

- [ ] Render CPU/memory/runtime limits verified. NEEDS APPROVAL
- [ ] PostgreSQL version verified. NEEDS APPROVAL
- [ ] pgcrypto extension availability verified. NEEDS APPROVAL
- [ ] PostgreSQL connection limits verified for Marketing + Scimior coexistence. NEEDS APPROVAL

## Security verification

- [ ] Runtime role privileges reviewed (marketing_app_role, marketing_service_role).
- [ ] RLS policy coverage reviewed for all tenant-owned tables.
- [ ] No direct Marketing queries to Scimior tables in design docs.

## Documentation integrity

- [ ] Legacy route examples marked non-normative.
- [ ] Legacy businesses/business_members references removed or superseded.
- [ ] File-extension references corrected (.md where applicable).
- [ ] Changelog maps each finding to resolution and changed files.
