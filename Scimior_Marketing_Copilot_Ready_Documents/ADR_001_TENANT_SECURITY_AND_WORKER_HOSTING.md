# ADR-001: Tenant Security and Worker Hosting

Status: Accepted for remediation baseline
Date: 2026-10-09

## Context

Marketing MVP runs as a logical module inside the existing Scimior Node.js deployment. Review findings identified tenant isolation and shared-runtime worker risks as blockers.

## Decision

### 1. Tenant security model

- Enable PostgreSQL RLS on tenant-owned Marketing tables.
- Use a transaction-scoped tenant context for app role sessions:
  - SET LOCAL app.current_organization_id = '<uuid>'
  - SET LOCAL app.current_user_id = '<uuid>'
- RLS policies reference current_setting('app.current_organization_id', true).
- Privileged paths that must cross tenant boundaries are limited to service_role routines and audited.

### 2. Database roles

- marketing_owner: schema owner and migration executor (not used by runtime API).
- marketing_app_role: runtime role used by API for tenant-scoped application queries.
- marketing_service_role: restricted privileged role for system jobs, webhook reconciliation, and cross-tenant administrative operations where explicitly required.

### 3. Connection pool behavior

- Separate Marketing pool from Scimior pool.
- Pool budget for shared process MVP:
  - marketing_app_role pool max: NEEDS APPROVAL
  - marketing_service_role pool max: NEEDS APPROVAL
- Every request and worker claim transaction sets tenant context before queries.
- Reset tenant context between pooled connections using transaction scope only (SET LOCAL), never session-global SET.

### 4. Worker hosting strategy

- Worker runs in same Node.js process for MVP.
- Worker must be bounded by:
  - global concurrency cap
  - per-organization concurrency cap
  - DB claim batch size
- Graceful shutdown is mandatory:
  - stop new claims
  - finish/abandon safely with lock expiry
  - flush heartbeat
  - close pool cleanly

## Consequences

Positive:
- Stronger defense-in-depth tenant isolation.
- Lower risk of accidental cross-tenant data exposure.
- Shared-hosting remains feasible within approved MVP constraints.

Trade-offs:
- More SQL and runtime context management complexity.
- Requires disciplined role and migration management.

## Alternatives considered

1. App-layer-only tenant checks without RLS
- Rejected for baseline due to higher blast radius risk.

2. Separate worker service on day one
- Deferred due to current hosting constraint, but remains future extraction path.

## Operational guardrails

- Queue age and claim-latency alerts.
- Pool saturation alerts.
- API p95 latency SLO alerts.
- Worker kill-switch for incident mitigation.

## Open items

- Exact pool sizes: NEEDS APPROVAL
- Exact per-organization concurrency limits: NEEDS APPROVAL
- Render resource envelope confirmation: NEEDS APPROVAL
