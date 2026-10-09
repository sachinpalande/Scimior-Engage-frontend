# Scimior Marketing User Registration and WhatsApp Onboarding (Remediated)

Status: Canonical onboarding spec
Date: 2026-10-09

## 1. Scope

Defines standalone registration and WhatsApp onboarding for Marketing.

## 2. Canonical model

- Tenant: organizations
- Membership: organization_members
- Tenant key: organization_id
- Do not use businesses/business_members in implementation.

## 3. Canonical endpoints

- POST /api/marketing/v1/auth/register
- POST /api/marketing/v1/auth/login
- POST /api/marketing/v1/auth/logout
- POST /api/marketing/v1/auth/forgot-password
- POST /api/marketing/v1/auth/reset-password
- POST /api/marketing/v1/organizations
- GET /api/marketing/v1/organizations/:organizationId
- POST /api/marketing/v1/organizations/:organizationId/whatsapp/onboarding-session
- POST /api/marketing/v1/webhooks/whatsapp/onboarding-callback
- GET /api/marketing/v1/organizations/:organizationId/whatsapp/connection
- POST /api/marketing/v1/organizations/:organizationId/whatsapp/connection/check
- POST /api/marketing/v1/organizations/:organizationId/whatsapp/disconnect

## 4. Security requirements

- One-time, short-lived state for onboarding callbacks.
- Reject missing, expired, reused, or mismatched state.
- Never expose provider tokens or app secrets to clients.
- Encrypt credentials at rest.
- Enforce org membership and role checks server-side.

## 5. Required persisted onboarding data

- organization_id
- provider
- meta_business_id (when available)
- waba_id
- phone_number_id
- phone_number_e164
- display_name
- granted_scopes
- connection_status
- token metadata (secured)

## 6. Acceptance conditions

- Standalone user can register and create organization without Scimior account.
- User cannot read/write another organization's connection metadata.
- Callback replay does not create duplicate active connections.
- Connected status only after backend verification succeeds.

## 7. Open decisions

- Primary auth transport (cookie session vs bearer): NEEDS APPROVAL
- Multiple WABA/number support policy for one organization: NEEDS APPROVAL
