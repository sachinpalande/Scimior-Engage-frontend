# Development Readiness Checklist (P0 Remediated)

Status: Gate checklist
Date: 2026-10-09

## Foundation gate (must pass before development)

- [ ] Canonical API/tenant contract approved.
- [ ] Role model and threat boundary approved (owner/app/service/bootstrap).
- [ ] RLS policy boundary approved (app role blocked from NULL-tenant globals).
- [ ] Bootstrap workflows approved (register/login/reset/first-org/onboarding-callback/webhook-ingress/worker).
- [ ] Migration runner specification approved (URL equality guard + target identity allowlist + checksums/order).
- [ ] Composite FK delete-action corrections accepted.
- [ ] users.full_name and idempotency schema alignment accepted.
- [ ] Status-rank enforcement approach accepted.

## Feature gate (must pass before affected feature)

- [ ] Primary auth transport approved. NEEDS APPROVAL
- [ ] marketing_service_role exact grants approved. NEEDS APPROVAL
- [ ] Worker global and per-org concurrency caps approved. NEEDS APPROVAL
- [ ] Worker claim batch size approved. NEEDS APPROVAL
- [ ] Payload and idempotency retention TTL approved. NEEDS APPROVAL
- [ ] Multiple WABA/number policy approved. NEEDS APPROVAL
- [ ] CORS origin set approved for Marketing hosts. NEEDS APPROVAL

## Pre-production gate

- [ ] Render CPU/memory/runtime limits verified. NEEDS APPROVAL
- [ ] PostgreSQL version and extension availability verified. NEEDS APPROVAL
- [ ] PostgreSQL connection limits verified for shared-process coexistence. NEEDS APPROVAL
- [ ] Disposable DB migration execution test passed with role/grant/RLS verification.
- [ ] Cross-tenant isolation test passed in disposable DB.

## Evidence integrity

- [ ] Changelog reflects specification updates vs implemented runtime behavior.
- [ ] Final readiness report does not claim unperformed tests.
