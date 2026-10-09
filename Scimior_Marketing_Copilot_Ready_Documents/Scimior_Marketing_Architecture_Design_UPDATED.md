# Scimior Marketing Architecture Design (Remediated)

Status: Canonical remediation architecture
Date: 2026-10-09

## 1. Architecture boundaries

### Frontend boundary
- Marketing frontend is a separate React application.

### API boundary
- Marketing API namespace is /api/marketing/v1 only.
- Existing Scimior APIs remain unchanged.

### Data boundary
- Marketing uses a separate PostgreSQL database connection and migration history.
- Marketing code must not query Scimior tables directly.

### Integration boundary
- Optional integration with Scimior uses explicit provider/adapters (e.g., CustomerProvider).
- No direct repository imports across domains.

## 2. Runtime topology for MVP

- Marketing backend module is hosted within the existing Node.js process deployment.
- Shared runtime means shared CPU/memory/restart domain with Scimior.
- Campaign workers must be bounded and fail-safe.

## 3. Security baseline

- Tenant isolation: organization_id at schema and API authorization layers.
- RLS enabled on tenant-owned Marketing tables.
- Transaction-scoped tenant context for runtime queries.
- Dedicated runtime roles and least privilege (see ADR_001_TENANT_SECURITY_AND_WORKER_HOSTING.md).

## 4. Worker and queue baseline

- Durable DB-backed jobs and recipient states.
- Safe claim-and-lock semantics.
- Explicit retry policy with bounded attempts.
- Graceful shutdown sequence required.

## 5. Canonical route families

Under /api/marketing/v1:
- auth
- me
- organizations
- contacts
- contact-imports
- groups
- tags
- templates
- audiences
- campaigns
- conversations
- reports
- webhooks/whatsapp

Any route examples outside this prefix are non-normative.
