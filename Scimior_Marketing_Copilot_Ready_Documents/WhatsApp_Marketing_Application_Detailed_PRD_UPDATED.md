# WhatsApp Marketing Application Detailed PRD (Remediated)

Status: MVP-aligned remediated PRD
Date: 2026-10-09

## 1. MVP scope

Included:
- Standalone auth and organizations
- WhatsApp onboarding and secure credential handling
- Contacts, imports, groups, tags, consent and suppression
- Templates sync and eligibility checks
- Campaign lifecycle with durable queue/workers
- Recipient-level status and reports
- Basic inbox

Deferred:
- Scimior SSO and auto-sync
- AI automation, drip builders, advanced CRM/reseller/billing

## 2. Canonical terminology

- Use organization, organization_members, organization_id across all sections.
- Legacy business_id/businesses wording is non-normative.

## 3. Canonical API

All product APIs are under /api/marketing/v1.

Legacy route examples (such as /api/contacts, /api/businesses, /api/auth without prefix) are non-normative.

See CANONICAL_API_CONTRACT.md for normative endpoint behavior.

## 4. Campaign and queue invariants

- Never bulk-send synchronously in request/response flow.
- Persist campaign and recipients before queueing.
- Use idempotency keys for launch/schedule/retry/cancel flows.
- Re-check consent/template/account eligibility immediately before send.
- Derive delivery/read from webhook events, not submit response.

## 5. Compliance and consent

- Phone number alone is not marketing consent.
- Suppression must be enforced both at audience generation and before submission.
- Retain auditable consent and opt-out evidence.

## 6. Reporting rules

- Distinguish selected, eligible, submitted, delivered, read, failed.
- Define denominators explicitly for each percentage metric.

## 7. Non-functional requirements

- Tenant isolation at API + DB layers.
- Replay-safe webhook processing.
- Restart-safe worker recovery.
- Shared-runtime safeguards for API latency.

## 8. Open decisions

- Throughput and per-organization concurrency caps: NEEDS APPROVAL
- Queue depth and API latency SLO thresholds: NEEDS APPROVAL
- Final rate card source for cost estimates: NEEDS APPROVAL
