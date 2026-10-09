# Scimior Marketing Database Schema Design

Status: P0-remediated schema design
Date: 2026-10-09

## 1. Scope

This document defines the Marketing schema and security boundary for foundation work.

This is still pre-implementation and pre-migration-validation documentation.

## 2. Hard boundaries

- Dedicated Marketing PostgreSQL database and connection pool.
- No direct Marketing queries to Scimior tables.
- No Prisma.
- No Flutter-side changes in this remediation phase.

## 3. Role and ownership model

Defined roles:
- marketing_owner: schema owner/migration executor only
- marketing_app_role: tenant-scoped runtime API role
- marketing_service_role: privileged audited workflows
- marketing_bootstrap_role: public/pre-tenant bootstrap workflows

Controls:
- No broad BYPASSRLS grant to application roles.
- FORCE ROW LEVEL SECURITY on marketing tables.
- Policies scoped by role (`TO marketing_app_role`, `TO marketing_service_role`, `TO marketing_bootstrap_role`).

NEEDS APPROVAL: exact GRANT set for marketing_service_role.
- Recommended default: only object-level privileges required by webhook reconciliation and queue worker operations.

## 4. Threat boundary of GUC-based RLS

RLS depends on transaction-scoped tenant context:
- app.current_organization_id
- app.current_user_id

Boundary statement:
- This mechanism enforces query-scoping discipline.
- It does not replace infrastructure identity controls.
- Compromised DB credentials remain high impact and must be mitigated with secret handling, role separation and auditing.

## 5. Bootstrap paths (secure workflow definitions)

Pre-tenant or public workflows use marketing_bootstrap_role only:
- registration
- login session creation
- password reset issue/consume
- first organization creation
- public onboarding callback ingestion
- initial webhook ingress record

Privileged background workflows use marketing_service_role:
- webhook reconciliation
- status fan-in/out updates
- marketing job claim/retry/update
- cross-tenant administrative reconciliation (audited)

Authenticated tenant APIs use marketing_app_role.

## 6. P0 data model corrections

Implemented in 001_initial_schema.sql draft:
- users.full_name added.
- NULL-tenant global rows blocked from marketing_app_role read/write policies.
- Service-only policies for global webhook/audit workflows.
- Composite FK delete conflicts removed by using RESTRICT on problematic relations.
- Idempotency generalized with idempotency_keys table.
- Status-rank non-regression enforced via triggers.

## 7. Migration-safety alignment

SQL includes a defensive DB-name guard, but that guard is not sufficient alone.
The migration runner is mandatory for robust target validation.

## 8. Validation state

- Static structural review: completed.
- PostgreSQL parser/execution validation in disposable DB: NOT RUN in this workspace.

## 9. Open decisions

- Service-role grant minimization details: NEEDS APPROVAL
- Worker concurrency caps and claim batch size: NEEDS APPROVAL
- Idempotency and payload retention TTLs: NEEDS APPROVAL
- Approved DB host/database allowlist pattern: NEEDS APPROVAL
