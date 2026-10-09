-- Scimior Marketing PostgreSQL schema (P0 remediation draft)
-- Migration: 001_initial_schema.sql
-- IMPORTANT: apply to a dedicated Marketing database only.
-- Never run on Scimior or any shared/production database in this phase.
--
-- This SQL is a specification artifact until validated in an isolated disposable
-- PostgreSQL environment.

BEGIN;

-- ---------------------------------------------------------------------------
-- Safety guard (defense in depth only)
-- ---------------------------------------------------------------------------
-- This check is intentionally conservative, but it is not sufficient alone.
-- The migration runner must still enforce URL equality checks and target identity.
DO $$
BEGIN
    IF current_database() IN ('salon_nxt', 'scimior', 'postgres')
       OR current_database() ILIKE '%scimior%'
       OR current_database() ILIKE '%salon%' THEN
        RAISE EXCEPTION 'Refusing to run marketing migration on database: %', current_database();
    END IF;
END $$;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- Role model (no BYPASSRLS application roles)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'marketing_owner') THEN
        CREATE ROLE marketing_owner NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'marketing_app_role') THEN
        CREATE ROLE marketing_app_role NOINHERIT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'marketing_service_role') THEN
        CREATE ROLE marketing_service_role NOINHERIT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'marketing_bootstrap_role') THEN
        CREATE ROLE marketing_bootstrap_role NOINHERIT;
    END IF;
END $$;

COMMENT ON ROLE marketing_owner IS 'Schema owner and migration executor only.';
COMMENT ON ROLE marketing_app_role IS 'Tenant-scoped runtime role for authenticated tenant APIs.';
COMMENT ON ROLE marketing_service_role IS 'Privileged role for audited service workflows only.';
COMMENT ON ROLE marketing_bootstrap_role IS 'Restricted role for pre-tenant bootstrap flows.';

-- ---------------------------------------------------------------------------
-- Helper context functions for RLS
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app_current_organization_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.current_organization_id', true), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION app_current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::uuid;
$$;

-- ---------------------------------------------------------------------------
-- Identity and tenant root
-- ---------------------------------------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    email_normalized TEXT NOT NULL UNIQUE,
    password_hash TEXT,
    auth_provider TEXT NOT NULL DEFAULT 'password' CHECK (auth_provider IN ('password', 'external')),
    email_verified_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'pending_verification' CHECK (status IN ('pending_verification', 'active', 'disabled', 'locked')),
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    organization_type TEXT,
    country_code CHAR(2),
    timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    website TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'closed')),
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE organization_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'campaign_operator', 'inbox_operator', 'viewer')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('invited', 'active', 'suspended', 'removed')),
    invited_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    joined_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organization_id, user_id),
    UNIQUE (organization_id, id)
);
CREATE INDEX idx_org_members_user_status ON organization_members(user_id, status);

CREATE TABLE auth_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    last_seen_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    ip_hash TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_auth_sessions_user_expiry ON auth_sessions(user_id, expires_at);

CREATE TABLE password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_password_reset_user_expiry ON password_reset_tokens(user_id, expires_at);

CREATE TABLE user_terms_acceptance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    terms_version TEXT NOT NULL,
    privacy_version TEXT NOT NULL,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    acceptance_source TEXT NOT NULL,
    ip_hash TEXT,
    user_agent TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX idx_terms_user_time ON user_terms_acceptance(user_id, accepted_at DESC);

-- ---------------------------------------------------------------------------
-- WhatsApp onboarding and connection
-- ---------------------------------------------------------------------------
CREATE TABLE whatsapp_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'meta_cloud_api' CHECK (provider IN ('meta_cloud_api', 'approved_provider')),
    meta_business_id TEXT,
    waba_id TEXT,
    phone_number_id TEXT,
    phone_number_e164 TEXT,
    display_name TEXT,
    connection_status TEXT NOT NULL DEFAULT 'not_connected' CHECK (connection_status IN ('not_connected', 'onboarding_pending', 'verification_pending', 'connected', 'action_required', 'disconnected', 'reconnect_required')),
    granted_scopes JSONB NOT NULL DEFAULT '[]'::jsonb,
    token_reference TEXT,
    token_expires_at TIMESTAMPTZ,
    last_checked_at TIMESTAMPTZ,
    connected_at TIMESTAMPTZ,
    disconnected_at TIMESTAMPTZ,
    last_error_code TEXT,
    last_error_safe_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organization_id, id)
);

CREATE UNIQUE INDEX uq_whatsapp_provider_phone_number_id
    ON whatsapp_accounts(provider, phone_number_id)
    WHERE phone_number_id IS NOT NULL;

CREATE UNIQUE INDEX uq_whatsapp_provider_waba_phone
    ON whatsapp_accounts(provider, waba_id, phone_number_e164)
    WHERE waba_id IS NOT NULL AND phone_number_e164 IS NOT NULL;

CREATE INDEX idx_whatsapp_accounts_org_status ON whatsapp_accounts(organization_id, connection_status);

CREATE TABLE whatsapp_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    whatsapp_account_id UUID NOT NULL,
    encrypted_access_token TEXT,
    secret_reference TEXT,
    encryption_key_version TEXT,
    token_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    rotated_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    CHECK ((encrypted_access_token IS NOT NULL AND secret_reference IS NULL) OR (encrypted_access_token IS NULL AND secret_reference IS NOT NULL)),
    FOREIGN KEY (organization_id, whatsapp_account_id) REFERENCES whatsapp_accounts(organization_id, id) ON DELETE CASCADE,
    UNIQUE (whatsapp_account_id)
);

CREATE TABLE onboarding_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    initiated_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    state_hash TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled', 'expired', 'failed')),
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    safe_error_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_onboarding_org_status ON onboarding_sessions(organization_id, status, expires_at);

-- ---------------------------------------------------------------------------
-- Contacts, imports, groups, tags, consent
-- ---------------------------------------------------------------------------
CREATE TABLE contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT,
    phone_e164 TEXT NOT NULL,
    email TEXT,
    custom_fields JSONB NOT NULL DEFAULT '{}'::jsonb,
    source_system TEXT NOT NULL DEFAULT 'manual',
    source_contact_id TEXT,
    source_updated_at TIMESTAMPTZ,
    marketing_consent_status TEXT NOT NULL DEFAULT 'unknown' CHECK (marketing_consent_status IN ('unknown', 'opted_in', 'opted_out')),
    opted_out_at TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organization_id, id),
    UNIQUE (organization_id, phone_e164)
);
CREATE INDEX idx_contacts_org_consent ON contacts(organization_id, marketing_consent_status);

CREATE TABLE contact_imports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    filename TEXT,
    status TEXT NOT NULL DEFAULT 'uploaded' CHECK (status IN ('uploaded', 'mapping', 'validating', 'processing', 'completed', 'completed_with_errors', 'failed')),
    total_rows INTEGER NOT NULL DEFAULT 0 CHECK (total_rows >= 0),
    imported_rows INTEGER NOT NULL DEFAULT 0 CHECK (imported_rows >= 0),
    duplicate_rows INTEGER NOT NULL DEFAULT 0 CHECK (duplicate_rows >= 0),
    invalid_rows INTEGER NOT NULL DEFAULT 0 CHECK (invalid_rows >= 0),
    skipped_rows INTEGER NOT NULL DEFAULT 0 CHECK (skipped_rows >= 0),
    field_mapping JSONB NOT NULL DEFAULT '{}'::jsonb,
    error_report_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);
CREATE INDEX idx_contact_imports_org_created ON contact_imports(organization_id, created_at DESC);

CREATE TABLE contact_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organization_id, id),
    UNIQUE (organization_id, name)
);

CREATE TABLE contact_group_members (
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    group_id UUID NOT NULL,
    contact_id UUID NOT NULL,
    added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (organization_id, group_id, contact_id),
    FOREIGN KEY (organization_id, group_id) REFERENCES contact_groups(organization_id, id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id, contact_id) REFERENCES contacts(organization_id, id) ON DELETE CASCADE
);

CREATE TABLE contact_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organization_id, id),
    UNIQUE (organization_id, name)
);

CREATE TABLE contact_tag_assignments (
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL,
    contact_id UUID NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (organization_id, tag_id, contact_id),
    FOREIGN KEY (organization_id, tag_id) REFERENCES contact_tags(organization_id, id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id, contact_id) REFERENCES contacts(organization_id, id) ON DELETE CASCADE
);

CREATE TABLE consent_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL,
    channel TEXT NOT NULL DEFAULT 'whatsapp',
    purpose TEXT NOT NULL DEFAULT 'marketing',
    action TEXT NOT NULL CHECK (action IN ('opt_in', 'opt_out', 'consent_updated', 'consent_unknown')),
    source TEXT NOT NULL,
    evidence_reference TEXT,
    occurred_at TIMESTAMPTZ NOT NULL,
    recorded_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (organization_id, contact_id) REFERENCES contacts(organization_id, id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- Templates, audiences, campaigns and jobs
-- ---------------------------------------------------------------------------
CREATE TABLE message_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    provider_template_id TEXT,
    name TEXT NOT NULL,
    language_code TEXT NOT NULL,
    category TEXT,
    template_status TEXT NOT NULL DEFAULT 'pending' CHECK (template_status IN ('pending', 'approved', 'rejected', 'paused', 'disabled')),
    components JSONB NOT NULL DEFAULT '[]'::jsonb,
    variables_schema JSONB NOT NULL DEFAULT '{}'::jsonb,
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organization_id, id),
    UNIQUE (organization_id, provider_template_id),
    UNIQUE (organization_id, name, language_code)
);

CREATE TABLE audiences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    definition JSONB NOT NULL,
    estimated_count INTEGER,
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organization_id, id),
    UNIQUE (organization_id, name)
);

CREATE TABLE campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    campaign_type TEXT NOT NULL DEFAULT 'broadcast' CHECK (campaign_type IN ('broadcast', 'drip', 'api_triggered')),
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'scheduled', 'queued', 'sending', 'paused', 'completed', 'failed', 'cancelled')),
    template_id UUID,
    audience_id UUID,
    scheduled_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    message_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    idempotency_key TEXT,
    metrics JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (organization_id, template_id) REFERENCES message_templates(organization_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (organization_id, audience_id) REFERENCES audiences(organization_id, id) ON DELETE RESTRICT,
    UNIQUE (organization_id, id),
    UNIQUE (organization_id, idempotency_key)
);
CREATE INDEX idx_campaigns_org_status_time ON campaigns(organization_id, status, created_at DESC);

CREATE TABLE campaign_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    campaign_id UUID NOT NULL,
    contact_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'submitted', 'sent', 'delivered', 'read', 'failed', 'cancelled', 'skipped')),
    status_rank SMALLINT NOT NULL DEFAULT 10,
    attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    max_attempts INTEGER NOT NULL DEFAULT 3 CHECK (max_attempts BETWEEN 1 AND 10),
    next_retry_at TIMESTAMPTZ,
    provider_message_id TEXT,
    submitted_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    last_error_code TEXT,
    last_error_safe_message TEXT,
    snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (organization_id, campaign_id) REFERENCES campaigns(organization_id, id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id, contact_id) REFERENCES contacts(organization_id, id) ON DELETE RESTRICT,
    UNIQUE (organization_id, campaign_id, contact_id)
);
CREATE INDEX idx_recipients_claim_queue ON campaign_recipients(organization_id, campaign_id, status, next_retry_at, id);
CREATE INDEX idx_recipients_provider_msg ON campaign_recipients(organization_id, provider_message_id);

CREATE TABLE marketing_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    job_type TEXT NOT NULL CHECK (job_type IN ('campaign_dispatch', 'status_reconciliation', 'contact_import_processing', 'template_sync')),
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'completed', 'failed', 'cancelled')),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    locked_by TEXT,
    lock_expires_at TIMESTAMPTZ,
    attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    max_attempts INTEGER NOT NULL DEFAULT 10 CHECK (max_attempts > 0),
    last_error_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);
CREATE INDEX idx_jobs_claim ON marketing_jobs(status, available_at, lock_expires_at);

CREATE TABLE idempotency_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    scope_key TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    request_method TEXT NOT NULL,
    response_status_code INTEGER,
    response_body JSONB,
    locked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    UNIQUE (scope_key, endpoint, request_hash)
);
CREATE INDEX idx_idempotency_org_exp ON idempotency_keys(organization_id, endpoint, expires_at);

-- ---------------------------------------------------------------------------
-- Conversations, messages and webhook events
-- ---------------------------------------------------------------------------
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL,
    channel TEXT NOT NULL DEFAULT 'whatsapp',
    last_message_at TIMESTAMPTZ,
    is_open BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_to_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (organization_id, contact_id) REFERENCES contacts(organization_id, id) ON DELETE CASCADE,
    UNIQUE (organization_id, id)
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL,
    contact_id UUID NOT NULL,
    campaign_id UUID,
    direction TEXT NOT NULL CHECK (direction IN ('outbound', 'inbound', 'system')),
    provider_message_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'submitted', 'sent', 'delivered', 'read', 'failed', 'received')),
    status_rank SMALLINT NOT NULL DEFAULT 5,
    content_type TEXT NOT NULL DEFAULT 'text' CHECK (content_type IN ('text', 'template', 'media', 'interactive', 'system')),
    content TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    sent_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    provider_timestamp TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (organization_id, conversation_id) REFERENCES conversations(organization_id, id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id, contact_id) REFERENCES contacts(organization_id, id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id, campaign_id) REFERENCES campaigns(organization_id, id) ON DELETE RESTRICT
);
CREATE INDEX idx_messages_org_convo_time ON messages(organization_id, conversation_id, created_at DESC);
CREATE INDEX idx_messages_provider_msg ON messages(provider_message_id);

CREATE TABLE message_status_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    message_id UUID,
    provider_message_id TEXT NOT NULL,
    normalized_status TEXT NOT NULL CHECK (normalized_status IN ('submitted', 'sent', 'delivered', 'read', 'failed')),
    provider_timestamp TIMESTAMPTZ NOT NULL,
    error_code TEXT,
    raw_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (organization_id, message_id) REFERENCES messages(organization_id, id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_message_status_dedup
    ON message_status_events(provider_message_id, normalized_status, provider_timestamp, COALESCE(error_code, ''));

CREATE TABLE webhook_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    provider TEXT NOT NULL DEFAULT 'meta_cloud_api',
    event_type TEXT,
    provider_event_id TEXT,
    event_fingerprint TEXT NOT NULL,
    signature_valid BOOLEAN NOT NULL DEFAULT FALSE,
    verification_error TEXT,
    payload JSONB NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ,
    processing_status TEXT NOT NULL DEFAULT 'received' CHECK (processing_status IN ('received', 'deduplicated', 'processed', 'failed')),
    processing_error TEXT
);

CREATE UNIQUE INDEX uq_webhook_provider_event
    ON webhook_events(provider, provider_event_id)
    WHERE provider_event_id IS NOT NULL;

CREATE UNIQUE INDEX uq_webhook_fingerprint ON webhook_events(event_fingerprint);
CREATE INDEX idx_webhook_received_status ON webhook_events(received_at, processing_status);

-- ---------------------------------------------------------------------------
-- Audit, usage, and migration tracking
-- ---------------------------------------------------------------------------
CREATE TABLE audit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    entity_type TEXT,
    entity_id UUID,
    safe_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_org_time ON audit_events(organization_id, created_at DESC);

CREATE TABLE usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    period_month DATE NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value BIGINT NOT NULL DEFAULT 0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organization_id, period_month, metric_name)
);

CREATE TABLE schema_migrations (
    version TEXT PRIMARY KEY,
    checksum TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    applied_by TEXT NOT NULL
);

-- ---------------------------------------------------------------------------
-- Status rank enforcement
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_non_regressing_status_rank()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.status_rank < OLD.status_rank THEN
        RAISE EXCEPTION 'Status rank regression is not allowed (% -> %)', OLD.status_rank, NEW.status_rank;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_campaign_recipient_rank_no_regress
BEFORE UPDATE ON campaign_recipients
FOR EACH ROW
EXECUTE FUNCTION enforce_non_regressing_status_rank();

CREATE TRIGGER trg_messages_rank_no_regress
BEFORE UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION enforce_non_regressing_status_rank();

-- ---------------------------------------------------------------------------
-- RLS enablement and policy boundaries
-- ---------------------------------------------------------------------------
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_tag_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE consent_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE audiences ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketing_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE idempotency_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_status_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE password_reset_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_terms_acceptance ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

ALTER TABLE organizations FORCE ROW LEVEL SECURITY;
ALTER TABLE organization_members FORCE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_credentials FORCE ROW LEVEL SECURITY;
ALTER TABLE onboarding_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE contacts FORCE ROW LEVEL SECURITY;
ALTER TABLE contact_imports FORCE ROW LEVEL SECURITY;
ALTER TABLE contact_groups FORCE ROW LEVEL SECURITY;
ALTER TABLE contact_group_members FORCE ROW LEVEL SECURITY;
ALTER TABLE contact_tags FORCE ROW LEVEL SECURITY;
ALTER TABLE contact_tag_assignments FORCE ROW LEVEL SECURITY;
ALTER TABLE consent_events FORCE ROW LEVEL SECURITY;
ALTER TABLE message_templates FORCE ROW LEVEL SECURITY;
ALTER TABLE audiences FORCE ROW LEVEL SECURITY;
ALTER TABLE campaigns FORCE ROW LEVEL SECURITY;
ALTER TABLE campaign_recipients FORCE ROW LEVEL SECURITY;
ALTER TABLE marketing_jobs FORCE ROW LEVEL SECURITY;
ALTER TABLE idempotency_keys FORCE ROW LEVEL SECURITY;
ALTER TABLE conversations FORCE ROW LEVEL SECURITY;
ALTER TABLE messages FORCE ROW LEVEL SECURITY;
ALTER TABLE message_status_events FORCE ROW LEVEL SECURITY;
ALTER TABLE webhook_events FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_events FORCE ROW LEVEL SECURITY;
ALTER TABLE usage_records FORCE ROW LEVEL SECURITY;
ALTER TABLE auth_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE password_reset_tokens FORCE ROW LEVEL SECURITY;
ALTER TABLE user_terms_acceptance FORCE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;

-- Tenant-scoped policy template for marketing_app_role
CREATE POLICY organizations_app_policy ON organizations
    FOR ALL TO marketing_app_role
    USING (id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY organization_members_app_policy ON organization_members
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_whatsapp_accounts_app ON whatsapp_accounts
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_whatsapp_credentials_app ON whatsapp_credentials
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_onboarding_sessions_app ON onboarding_sessions
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_contacts_app ON contacts
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_contact_imports_app ON contact_imports
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_contact_groups_app ON contact_groups
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_contact_group_members_app ON contact_group_members
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_contact_tags_app ON contact_tags
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_contact_tag_assignments_app ON contact_tag_assignments
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_consent_events_app ON consent_events
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_message_templates_app ON message_templates
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_audiences_app ON audiences
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_campaigns_app ON campaigns
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_campaign_recipients_app ON campaign_recipients
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_marketing_jobs_app ON marketing_jobs
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_idempotency_app ON idempotency_keys
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_conversations_app ON conversations
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_messages_app ON messages
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_message_status_events_app ON message_status_events
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_webhook_events_app ON webhook_events
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_audit_events_app ON audit_events
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY tenant_scope_usage_records_app ON usage_records
    FOR ALL TO marketing_app_role
    USING (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL)
    WITH CHECK (organization_id = app_current_organization_id() AND app_current_organization_id() IS NOT NULL);

CREATE POLICY users_self_app_policy ON users
    FOR SELECT TO marketing_app_role
    USING (id = app_current_user_id() AND app_current_user_id() IS NOT NULL);

CREATE POLICY users_self_update_app_policy ON users
    FOR UPDATE TO marketing_app_role
    USING (id = app_current_user_id() AND app_current_user_id() IS NOT NULL)
    WITH CHECK (id = app_current_user_id() AND app_current_user_id() IS NOT NULL);

CREATE POLICY auth_sessions_self_app_policy ON auth_sessions
    FOR ALL TO marketing_app_role
    USING (user_id = app_current_user_id() AND app_current_user_id() IS NOT NULL)
    WITH CHECK (user_id = app_current_user_id() AND app_current_user_id() IS NOT NULL);

CREATE POLICY password_reset_tokens_self_app_policy ON password_reset_tokens
    FOR SELECT TO marketing_app_role
    USING (user_id = app_current_user_id() AND app_current_user_id() IS NOT NULL);

CREATE POLICY user_terms_acceptance_self_app_policy ON user_terms_acceptance
    FOR SELECT TO marketing_app_role
    USING (user_id = app_current_user_id() AND app_current_user_id() IS NOT NULL);

-- Service role policies (audited privileged operations)
CREATE POLICY service_all_organizations ON organizations
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_organization_members ON organization_members
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_whatsapp_accounts ON whatsapp_accounts
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_whatsapp_credentials ON whatsapp_credentials
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_onboarding_sessions ON onboarding_sessions
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_contacts ON contacts
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_contact_imports ON contact_imports
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_contact_groups ON contact_groups
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_contact_group_members ON contact_group_members
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_contact_tags ON contact_tags
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_contact_tag_assignments ON contact_tag_assignments
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_consent_events ON consent_events
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_message_templates ON message_templates
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_audiences ON audiences
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_campaigns ON campaigns
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_campaign_recipients ON campaign_recipients
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_marketing_jobs ON marketing_jobs
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_idempotency_keys ON idempotency_keys
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_conversations ON conversations
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_messages ON messages
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_message_status_events ON message_status_events
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_webhook_events ON webhook_events
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_audit_events ON audit_events
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_usage_records ON usage_records
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_users ON users
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_auth_sessions ON auth_sessions
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_password_reset_tokens ON password_reset_tokens
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);
CREATE POLICY service_all_terms ON user_terms_acceptance
    FOR ALL TO marketing_service_role USING (true) WITH CHECK (true);

-- Bootstrap role policies (pre-tenant and unauthenticated lifecycle)
CREATE POLICY bootstrap_insert_users ON users
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_update_users ON users
    FOR UPDATE TO marketing_bootstrap_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY bootstrap_insert_sessions ON auth_sessions
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_update_sessions ON auth_sessions
    FOR UPDATE TO marketing_bootstrap_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY bootstrap_insert_reset_tokens ON password_reset_tokens
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_update_reset_tokens ON password_reset_tokens
    FOR UPDATE TO marketing_bootstrap_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY bootstrap_select_reset_tokens ON password_reset_tokens
    FOR SELECT TO marketing_bootstrap_role
    USING (true);

CREATE POLICY bootstrap_insert_terms ON user_terms_acceptance
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_insert_organizations ON organizations
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_insert_organization_members ON organization_members
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_insert_onboarding_sessions ON onboarding_sessions
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_update_onboarding_sessions ON onboarding_sessions
    FOR UPDATE TO marketing_bootstrap_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY bootstrap_insert_whatsapp_accounts ON whatsapp_accounts
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_insert_whatsapp_credentials ON whatsapp_credentials
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_insert_webhook_events ON webhook_events
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_insert_audit_events ON audit_events
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_insert_jobs ON marketing_jobs
    FOR INSERT TO marketing_bootstrap_role
    WITH CHECK (true);

CREATE POLICY bootstrap_update_jobs ON marketing_jobs
    FOR UPDATE TO marketing_bootstrap_role
    USING (true)
    WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- Grants (least privilege)
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO marketing_app_role, marketing_service_role, marketing_bootstrap_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    users,
    organizations,
    organization_members,
    auth_sessions,
    password_reset_tokens,
    user_terms_acceptance,
    whatsapp_accounts,
    whatsapp_credentials,
    onboarding_sessions,
    contacts,
    contact_imports,
    contact_groups,
    contact_group_members,
    contact_tags,
    contact_tag_assignments,
    consent_events,
    message_templates,
    audiences,
    campaigns,
    campaign_recipients,
    marketing_jobs,
    idempotency_keys,
    conversations,
    messages,
    message_status_events,
    webhook_events,
    audit_events,
    usage_records
TO marketing_app_role, marketing_service_role, marketing_bootstrap_role;

GRANT SELECT, INSERT, UPDATE ON TABLE schema_migrations TO marketing_owner;

ALTER TABLE users OWNER TO marketing_owner;
ALTER TABLE organizations OWNER TO marketing_owner;
ALTER TABLE organization_members OWNER TO marketing_owner;
ALTER TABLE auth_sessions OWNER TO marketing_owner;
ALTER TABLE password_reset_tokens OWNER TO marketing_owner;
ALTER TABLE user_terms_acceptance OWNER TO marketing_owner;
ALTER TABLE whatsapp_accounts OWNER TO marketing_owner;
ALTER TABLE whatsapp_credentials OWNER TO marketing_owner;
ALTER TABLE onboarding_sessions OWNER TO marketing_owner;
ALTER TABLE contacts OWNER TO marketing_owner;
ALTER TABLE contact_imports OWNER TO marketing_owner;
ALTER TABLE contact_groups OWNER TO marketing_owner;
ALTER TABLE contact_group_members OWNER TO marketing_owner;
ALTER TABLE contact_tags OWNER TO marketing_owner;
ALTER TABLE contact_tag_assignments OWNER TO marketing_owner;
ALTER TABLE consent_events OWNER TO marketing_owner;
ALTER TABLE message_templates OWNER TO marketing_owner;
ALTER TABLE audiences OWNER TO marketing_owner;
ALTER TABLE campaigns OWNER TO marketing_owner;
ALTER TABLE campaign_recipients OWNER TO marketing_owner;
ALTER TABLE marketing_jobs OWNER TO marketing_owner;
ALTER TABLE idempotency_keys OWNER TO marketing_owner;
ALTER TABLE conversations OWNER TO marketing_owner;
ALTER TABLE messages OWNER TO marketing_owner;
ALTER TABLE message_status_events OWNER TO marketing_owner;
ALTER TABLE webhook_events OWNER TO marketing_owner;
ALTER TABLE audit_events OWNER TO marketing_owner;
ALTER TABLE usage_records OWNER TO marketing_owner;
ALTER TABLE schema_migrations OWNER TO marketing_owner;

COMMIT;

-- VERIFY (static expectation checks only)
-- 1) no marketing table in public schema has RLS disabled
-- 2) webhook_events and audit_events tenant app policy does not allow organization_id IS NULL
-- 3) no application role has BYPASSRLS
