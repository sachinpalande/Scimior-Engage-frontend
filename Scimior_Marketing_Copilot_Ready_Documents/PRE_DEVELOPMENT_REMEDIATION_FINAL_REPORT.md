# Scimior Marketing Pre-Development Remediation Final Report

Status: Updated after P0 remediation
Date: 2026-10-09

## 1. Scope

This phase remains documentation-and-schema remediation only.
No Scimior runtime behavior was modified and no migrations were applied.

## 2. What changed in this P0 remediation

- SQL updated to include role model, grants, force-RLS, bootstrap/service policy boundaries.
- SQL updated to block app-role access to NULL-tenant global rows.
- SQL updated to resolve composite FK delete conflicts.
- SQL updated with users.full_name, generalized idempotency table and status-rank non-regression triggers.
- Migration convention updated with mandatory runner safety and checksum/order design.
- ADR/schema/API/checklist/changelog reconciled to avoid implementation-overclaiming.

## 3. Classification

- Spec-level P0 blockers: addressed in draft artifacts.
- Runtime implementation: pending.
- Disposable PostgreSQL validation: NOT RUN in this workspace.

## 4. Remaining decisions (NEEDS APPROVAL)

- Primary auth transport mode.
- Exact service-role grants.
- Worker concurrency and claim batch limits.
- Idempotency and payload retention windows.
- DB target identity allowlist pattern.
- Marketing CORS origin allowlist.
- Render/PostgreSQL capacity and limits.

Recommended defaults are documented in the canonical contract, ADR and migration convention.

## 5. Current gate posture

Foundation implementation should not start until foundation-gate approvals in the readiness checklist are complete.

See:
- DEVELOPMENT_READINESS_CHECKLIST_REMEDIATED.md
- FINAL_DEVELOPMENT_READINESS_GATE_REPORT.md
