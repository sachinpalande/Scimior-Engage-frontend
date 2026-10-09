# ADR-001: Tenant Security and Worker Hosting

Status: Updated after P0 remediation
Date: 2026-10-09

## Context

Marketing remains a logically decoupled module in the existing Render-hosted Node.js process.
Initial readiness review identified security and migration-risk P0 blockers.

## Decision

### 1. Tenant security

Adopt a role-scoped, force-RLS model:
- marketing_app_role is tenant-scoped only
- marketing_service_role handles audited privileged workflows
- marketing_bootstrap_role handles public/pre-tenant workflows

App role must never read/create global NULL-tenant webhook or audit rows.

### 2. GUC boundary

Use transaction-scoped context (`SET LOCAL`) for tenant and user IDs.
This is a query-scope control, not infrastructure identity proof.

### 3. Ownership and grants

- marketing_owner owns schema objects and executes migrations.
- runtime roles do not own tables.
- no broad BYPASSRLS for runtime roles.

NEEDS APPROVAL: exact marketing_service_role object-level grants.
Recommended default: grant only required objects and operations for webhook/worker paths.

### 4. Worker hosting in shared process

Worker remains in same process for MVP with safeguards:
- bounded global concurrency
- bounded per-organization concurrency
- bounded claim batch size
- graceful shutdown sequence required

NEEDS APPROVAL: exact numeric limits.
Recommended default: conservative caps with feature flag disabled until measured.

## Consequences

Positive:
- Explicit role boundary with reduced accidental cross-tenant access risk.
- Bootstrap/public flows defined without leaking tenant-global data to app role.

Trade-off:
- More operational complexity (roles, grants, auditing).

## Open items

- Pool sizes per role: NEEDS APPROVAL
- Worker concurrency and claim batch values: NEEDS APPROVAL
- Render resource envelope confirmation: NEEDS APPROVAL
