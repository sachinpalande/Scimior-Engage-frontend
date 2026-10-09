# Scimior Marketing Canonical API Contract

Status: P0-remediated specification draft
Date: 2026-10-09

## 1. Scope

This document is the single normative API contract for Scimior Marketing MVP.

- API prefix: /api/marketing/v1
- Tenant model: organizations, organization_members, organization_id
- Authentication: independent Marketing auth/session model
- Data boundary: Marketing DB only
- Deployment boundary: same Render backend process (logical module)
- No Prisma

Routes outside /api/marketing/v1 are non-normative.

## 2. Security and role boundary

### 2.1 Runtime roles

The API implementation must use database roles consistent with SQL:
- marketing_app_role: authenticated tenant runtime only
- marketing_service_role: audited privileged system workflows
- marketing_bootstrap_role: pre-tenant and public bootstrap workflows only

`marketing_app_role` must never read or create NULL-tenant global rows.

### 2.2 Threat boundary for GUC-based RLS

Tenant scoping uses transaction-scoped context:
- SET LOCAL app.current_organization_id = '<uuid>'
- SET LOCAL app.current_user_id = '<uuid>'

This protects against missing tenant filters in app queries. It is not a substitute for secret management or host compromise controls.

### 2.3 Auth/session mode

NEEDS APPROVAL: primary web auth transport.
- Recommended default: opaque server-side session with secure HTTP-only cookie and CSRF protection.
- Alternative: bearer session token with rotation/revocation controls.

## 3. Request standards

### 3.1 Error envelope

All non-2xx responses:

```json
{
  "error": {
    "code": "string_code",
    "message": "safe message",
    "details": [],
    "requestId": "uuid"
  }
}
```

### 3.2 Idempotency

Idempotency is required for state-changing campaign operations and enqueue operations.

- Header: Idempotency-Key
- Scope: scope_key + endpoint + normalized payload hash
- SQL backing table: idempotency_keys

NEEDS APPROVAL: idempotency retention TTL.
- Recommended default: 24 hours for campaign lifecycle requests.

## 4. Auth endpoints

### POST /api/marketing/v1/auth/register
- Public
- Validation: full_name, email, password, terms_version, privacy_version
- Writes: users, user_terms_acceptance
- Uses: marketing_bootstrap_role workflow

### POST /api/marketing/v1/auth/login
- Public
- Validation: email + credential
- Writes: auth_sessions, users.last_login_at
- Uses: marketing_bootstrap_role workflow

### POST /api/marketing/v1/auth/logout
- Auth required
- Writes: auth_sessions.revoked_at

### POST /api/marketing/v1/auth/forgot-password
### POST /api/marketing/v1/auth/reset-password
- Public bootstrap flows
- Writes: password_reset_tokens, users.password_hash

## 5. Tenant and onboarding endpoints

### POST /api/marketing/v1/organizations
- Auth required
- First organization bootstrap uses marketing_bootstrap_role
- Subsequent org operations use marketing_app_role

### POST /api/marketing/v1/organizations/:organizationId/whatsapp/onboarding-session
### POST /api/marketing/v1/webhooks/whatsapp/onboarding-callback
- Callback ingress and reconciliation are service/bootstrap workflows
- Tenant reads/writes remain scoped to organization_id for app role

## 6. Campaign and inbox endpoints

Campaign, contacts, conversation and reporting endpoints remain tenant-scoped under marketing_app_role and role-authorization logic.

## 7. State progression

Recipient and message status rank must not regress.

Enforcement source of truth:
- SQL trigger-based non-regression checks in 001_initial_schema.sql

## 8. Open decisions

- Primary auth transport: NEEDS APPROVAL (recommended default above)
- Multiple WABA/number support per organization: NEEDS APPROVAL
  - Recommended default: allow multiple, maintain provider identity uniqueness
- Idempotency TTL and payload retention: NEEDS APPROVAL
