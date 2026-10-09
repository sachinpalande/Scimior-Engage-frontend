# Scimior Marketing Canonical API Contract

Status: Remediation draft for pre-development alignment
Date: 2026-10-09

## 1. Scope

This document is the single canonical API contract for Scimior Marketing MVP.

- API prefix: /api/marketing/v1
- Tenant model: organizations, organization_members, organization_id
- Auth: independent Marketing authentication and authorization
- Data boundary: Marketing DB only; no direct Scimior DB queries

Legacy examples using /api/contacts, /api/businesses, /api/auth outside /api/marketing/v1 are non-normative and must not be implemented.

## 2. Global API rules

### 2.1 Authentication and sessions

- Public routes: register, login, forgot-password, reset-password, webhook verification/receipt endpoints that must be public.
- All other routes require Marketing session authentication.
- Session model: opaque session token in secure cookie or bearer token with server-side session record.
- Session persistence table: auth_sessions.

NEEDS APPROVAL: cookie-based vs bearer-token primary mode for web clients.

### 2.2 Authorization and tenant checks

- Every tenant route resolves active organization membership server-side.
- Client-provided organizationId is never sufficient authorization proof.
- Role checks are enforced for each protected operation.

Roles:
- owner
- admin
- campaign_operator
- inbox_operator
- viewer

### 2.3 Validation

- Validate body, params, query at API boundary.
- Normalize phone numbers to E.164 where applicable.
- Return structured field errors for invalid input.

### 2.4 Error format

All non-2xx responses use:

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

- No secrets in message/details.
- 401 for unauthenticated, 403 for unauthorized, 404 for scoped-not-found, 409 for idempotency/uniqueness conflicts, 422 for validation semantics.

### 2.5 Idempotency

- Required for campaign launch/schedule/cancel/retry and any enqueue operation.
- Header: Idempotency-Key.
- Key scope: organization + endpoint + normalized payload hash.
- Duplicate key with same payload returns prior result.
- Duplicate key with different payload returns 409.

### 2.6 Rate limiting

- Strict route-specific limits for auth and onboarding callbacks.
- Additional limits for campaign lifecycle endpoints and webhook processing.

## 3. Endpoint families

## 3.1 Auth

### POST /api/marketing/v1/auth/register
- Auth: public
- Validation: full_name, email, password (or approved provider flow), terms acceptance fields
- Writes: users, user_terms_acceptance, audit_events
- Response: 201 created + verification pending/active status

### POST /api/marketing/v1/auth/login
- Auth: public
- Validation: email + credential
- Writes: auth_sessions, users.last_login_at
- Response: 200 session established

### POST /api/marketing/v1/auth/logout
- Auth: required
- Writes: auth_sessions.revoked_at
- Idempotent: yes

### POST /api/marketing/v1/auth/forgot-password
- Auth: public
- Writes: password_reset_tokens

### POST /api/marketing/v1/auth/reset-password
- Auth: public
- Writes: users.password_hash, password_reset_tokens.used_at

## 3.2 Me and organizations

### GET /api/marketing/v1/me
- Auth: required
- Response: current user + organizations + effective roles

### POST /api/marketing/v1/organizations
- Auth: required
- Role: any authenticated user
- Writes: organizations, organization_members(owner), audit_events

### GET /api/marketing/v1/organizations/:organizationId
- Auth: required
- Role: any active member

## 3.3 WhatsApp onboarding and connection

### POST /api/marketing/v1/organizations/:organizationId/whatsapp/onboarding-session
- Auth: required
- Role: owner, admin
- Writes: onboarding_sessions
- Validation: active membership, existing active session policy

### POST /api/marketing/v1/webhooks/whatsapp/onboarding-callback
- Auth: public provider callback
- Validation: one-time state, expiry, replay check
- Writes: whatsapp_accounts, whatsapp_credentials, onboarding_sessions, audit_events
- Idempotent: callback replay-safe

### GET /api/marketing/v1/organizations/:organizationId/whatsapp/connection
- Auth: required
- Role: owner, admin, campaign_operator, viewer

### POST /api/marketing/v1/organizations/:organizationId/whatsapp/connection/check
- Auth: required
- Role: owner, admin
- Writes: whatsapp_accounts.last_checked_at, connection_status

### POST /api/marketing/v1/organizations/:organizationId/whatsapp/disconnect
- Auth: required
- Role: owner, admin
- Writes: whatsapp_accounts status, whatsapp_credentials revoked metadata, audit_events
- Idempotent: yes

## 3.4 Contacts and segmentation

### GET /api/marketing/v1/contacts
### POST /api/marketing/v1/contacts
### PATCH /api/marketing/v1/contacts/:contactId
- Auth: required
- Role: owner, admin, campaign_operator
- Tenant check: organization scope mandatory

### POST /api/marketing/v1/contact-imports
### GET /api/marketing/v1/contact-imports/:importId
- Auth: required
- Role: owner, admin, campaign_operator
- Async processing via durable jobs

### GET/POST /api/marketing/v1/groups
### GET/POST /api/marketing/v1/tags
- Auth: required
- Role: owner, admin, campaign_operator

## 3.5 Templates, audiences, campaigns

### GET /api/marketing/v1/templates
### POST /api/marketing/v1/templates/sync
- Auth: required
- Role: owner, admin, campaign_operator

### GET/POST /api/marketing/v1/audiences
- Auth: required
- Role: owner, admin, campaign_operator

### POST /api/marketing/v1/campaigns
### PATCH /api/marketing/v1/campaigns/:campaignId
### POST /api/marketing/v1/campaigns/:campaignId/test
### POST /api/marketing/v1/campaigns/:campaignId/schedule
### POST /api/marketing/v1/campaigns/:campaignId/start
### POST /api/marketing/v1/campaigns/:campaignId/pause
### POST /api/marketing/v1/campaigns/:campaignId/resume
### POST /api/marketing/v1/campaigns/:campaignId/cancel
### POST /api/marketing/v1/campaigns/:campaignId/retry
### GET /api/marketing/v1/campaigns/:campaignId/report
### GET /api/marketing/v1/campaigns/:campaignId/recipients
- Auth: required
- Role:
  - mutate: owner, admin, campaign_operator
  - report/read: owner, admin, campaign_operator, viewer
- Idempotency: required for schedule/start/pause/resume/cancel/retry

## 3.6 Conversations and inbox

### GET /api/marketing/v1/conversations
### GET /api/marketing/v1/conversations/:conversationId/messages
### POST /api/marketing/v1/conversations/:conversationId/messages
- Auth: required
- Role:
  - read: owner, admin, inbox_operator, viewer
  - reply: owner, admin, inbox_operator

## 3.7 Webhooks (delivery and inbound messages)

### GET /api/marketing/v1/webhooks/whatsapp
- Purpose: provider verification handshake

### POST /api/marketing/v1/webhooks/whatsapp
- Purpose: status + inbound events
- Verification: signature validation required
- Processing: dedup + replay-safe + out-of-order tolerant
- Writes: webhook_events, message_status_events, messages, campaign_recipients, campaigns

## 4. State transitions (normative)

Campaign status:
- draft -> scheduled | queued
- scheduled -> queued | cancelled
- queued -> sending | paused | cancelled
- sending -> paused | completed | failed | cancelled
- paused -> queued | cancelled
- completed, failed, cancelled are terminal

Recipient status:
- queued -> processing -> submitted
- submitted -> sent | delivered | read | failed
- queued | processing -> cancelled | skipped
- delivered -> read
- Terminal: read, failed, cancelled, skipped

Out-of-order webhook status updates must never regress a later terminal state.

## 5. Compatibility notes

- No Prisma.
- No dependency on Scimior salon middleware.
- Scimior integration is optional and only through explicit provider adapters.
