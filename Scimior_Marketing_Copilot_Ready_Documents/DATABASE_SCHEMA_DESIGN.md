# Scimior Marketing Database Schema Design (Remediated)

Status: Canonical pre-development schema design
Date: 2026-10-09

## 1. Scope and goals

This document defines the canonical Marketing database design for MVP.

Goals:
- Strong tenant isolation
- Durable campaign processing
- Replay-safe webhook ingestion
- Auditable consent and legal acceptance
- Operationally safe coexistence with existing Scimior runtime

## 2. Hard boundaries

- Use a separate Marketing PostgreSQL database connection and credentials.
- Use separate migration history from Scimior backend.
- No direct queries to Scimior tables.
- No Prisma.

## 3. Canonical tenancy model

- Tenant root: organizations
- Membership: organization_members
- Tenant key in owned tables: organization_id

## 4. Security model

### 4.1 Row-level security

- Enable RLS on tenant-owned tables.
- API runtime sets transaction-scoped tenant context:
  - app.current_organization_id
  - app.current_user_id
- RLS policies scope reads/writes to the active tenant context.

### 4.2 Role model

- marketing_owner: migration/admin only
- marketing_app_role: tenant-scoped API runtime
- marketing_service_role: privileged system workflows

NEEDS APPROVAL: exact grants for marketing_service_role for incident and reconciliation paths.

### 4.3 Sensitive data

- Store only token ciphertext or external secret reference.
- Never store plaintext provider access tokens.
- Hash all session and reset tokens.

## 5. Domain tables

### Identity and legal
- users
- auth_sessions
- password_reset_tokens
- user_terms_acceptance

### Tenant and access
- organizations
- organization_members

### WhatsApp integration
- whatsapp_accounts
- whatsapp_credentials
- onboarding_sessions

### Contacts and consent
- contacts
- contact_groups
- contact_group_members
- contact_tags
- contact_tag_assignments
- consent_events
- contact_imports

### Campaigns and delivery
- message_templates
- audiences
- campaigns
- campaign_recipients
- marketing_jobs

### Inbox and event ingestion
- conversations
- messages
- message_status_events
- webhook_events

### Operations
- audit_events
- usage_records
- schema_migrations

## 6. Uniqueness and dedup strategy

- users.email_normalized unique globally.
- organization_members unique by (organization_id, user_id).
- contacts unique by (organization_id, phone_e164).
- whatsapp_accounts provider identifiers globally unique where present:
  - (provider, phone_number_id)
  - (provider, waba_id, phone_number_e164)
- webhook_events dedup:
  - (provider, provider_event_id) unique when provider_event_id exists
  - event_fingerprint unique
- message_status_events dedup:
  - (provider_message_id, normalized_status, provider_timestamp, COALESCE(error_code,'')) unique

## 7. Campaign status and retry controls

- Campaign lifecycle: draft, scheduled, queued, sending, paused, completed, failed, cancelled.
- Recipient lifecycle: queued, processing, submitted, sent, delivered, read, failed, cancelled, skipped.
- Prevent status regression using monotonic status_rank checks.
- Retry controls:
  - attempt_count
  - max_attempts
  - next_retry_at
  - last_error_code

## 8. Webhook ingestion guarantees

- Signature validation required before domain mutation.
- Store webhook raw payload and verification metadata.
- Idempotent write path via dedup unique indexes.
- Out-of-order events never downgrade terminal states.

## 9. Migration and environment safety

- SQL migration must reject accidental execution against Scimior DB names.
- Migration numbers are strict and never reused.
- Never edit already applied migration files.

See MARKETING_MIGRATION_CONVENTION.md.

## 10. Open decisions

- Pool sizing for app/service roles: NEEDS APPROVAL
- Worker concurrency and claim batch size: NEEDS APPROVAL
- Payload retention windows for webhook/messages: NEEDS APPROVAL
- Exact allowed host pattern for DB safety guard: NEEDS APPROVAL
