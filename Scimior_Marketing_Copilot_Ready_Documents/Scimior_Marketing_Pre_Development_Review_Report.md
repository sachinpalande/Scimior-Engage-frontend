## Section 1 — Executive summary
Status: Not ready for development yet.

You should not start implementation until a small set of architectural/documentation blockers are resolved.
Main reasons:

1. Critical spec contradictions still exist across docs for tenant model and API routes (legacy /api/* + businesses vs canonical /api/marketing/v1 + organizations), which will cause implementation drift.
2. Backend runtime readiness gaps for shared-process campaign workers: no verified graceful shutdown path for queued worker state, and existing cron/scheduler load already runs inside the same Node process.
3. Marketing schema risk items need explicit decisions before coding (notably WhatsApp asset uniqueness scope, webhook/event idempotency constraints, and DB-level tenant hardening strategy).
4. Operational prerequisites are UNVERIFIED (actual Render resource headroom, PostgreSQL version/extension constraints, and migration governance for a second DB workflow).

No code changes were made.

---

## Section 2 — Verified existing backend architecture

### A) Stack and startup
- Backend is Node.js + Express + ESM ("type": "module"): [Scimior-backend/package.json#L4](Scimior-backend/package.json#L4), [Scimior-backend/package.json#L23](Scimior-backend/package.json#L23)
- Entry export is index.js re-exporting app from bootstrap: [Scimior-backend/index.js#L9](Scimior-backend/index.js#L9)
- HTTP server starts in server.local.js via app.listen: [Scimior-backend/server.local.js#L48](Scimior-backend/server.local.js#L48)
- Production start script points to server.local.js: [Scimior-backend/package.json#L8](Scimior-backend/package.json#L8)

### B) Route registration and API conventions
- Health route is /api/health: [Scimior-backend/bootstrap.js#L45](Scimior-backend/bootstrap.js#L45)
- Existing route namespace is /api/... (non-versioned, non-marketing): [Scimior-backend/bootstrap.js#L324](Scimior-backend/bootstrap.js#L324), [Scimior-backend/bootstrap.js#L353](Scimior-backend/bootstrap.js#L353)
- No Marketing routes currently mounted (/api/marketing not present in backend code search).

### C) Middleware and security conventions
- helmet, cors, JSON parser enabled globally: [Scimior-backend/bootstrap.js#L129](Scimior-backend/bootstrap.js#L129), [Scimior-backend/bootstrap.js#L130](Scimior-backend/bootstrap.js#L130)
- General and auth-specific rate limiting used: [Scimior-backend/bootstrap.js#L163](Scimior-backend/bootstrap.js#L163), [Scimior-backend/bootstrap.js#L312](Scimior-backend/bootstrap.js#L312)
- CORS defaults include Scimior domains but not marketing.scimior.com: [Scimior-backend/bootstrap.js#L57](Scimior-backend/bootstrap.js#L57), [Scimior-backend/bootstrap.js#L60](Scimior-backend/bootstrap.js#L60)
- Global error and 404 handlers exist: [Scimior-backend/bootstrap.js#L356](Scimior-backend/bootstrap.js#L356), [Scimior-backend/bootstrap.js#L377](Scimior-backend/bootstrap.js#L377)

### D) Authn/Authz model
- JWT auth middleware (verifyToken) with token blacklist and access cache: [Scimior-backend/middleware/auth.js#L112](Scimior-backend/middleware/auth.js#L112), [Scimior-backend/middleware/auth.js#L20](Scimior-backend/middleware/auth.js#L20)
- Middleware is salon-coupled (req.salonId, user_salon_relationships, onboarding check): [Scimior-backend/middleware/auth.js#L151](Scimior-backend/middleware/auth.js#L151), [Scimior-backend/middleware/auth.js#L244](Scimior-backend/middleware/auth.js#L244), [Scimior-backend/middleware/auth.js#L279](Scimior-backend/middleware/auth.js#L279)
- Role/permission checks are route-level through requirePermission/requireAnyPermission: [Scimior-backend/middleware/permissions.js#L58](Scimior-backend/middleware/permissions.js#L58), [Scimior-backend/routes/customers.js#L279](Scimior-backend/routes/customers.js#L279)
- Multi-salon membership exists (user_salon_relationships): [Scimior-backend/config/database.sql#L1585](Scimior-backend/config/database.sql#L1585), [Scimior-backend/routes/auth.js#L1153](Scimior-backend/routes/auth.js#L1153)

### E) Database architecture
- PostgreSQL driver is pg, single exported pool in db.js: [Scimior-backend/db.js#L1](Scimior-backend/db.js#L1), [Scimior-backend/db.js#L52](Scimior-backend/db.js#L52)
- Connection uses either DATABASE_URL or split DB env vars: [Scimior-backend/db.js#L31](Scimior-backend/db.js#L31)
- Pool limits currently small (max: 10 with URL; max: 5 otherwise): [Scimior-backend/db.js#L37](Scimior-backend/db.js#L37), [Scimior-backend/db.js#L49](Scimior-backend/db.js#L49)
- Retry helper exists for transient DB errors: [Scimior-backend/db.js#L78](Scimior-backend/db.js#L78)
- Prisma is not present in backend package deps (verified by package search).

### F) Migrations and schema conventions
- Large SQL migration set exists in [Scimior-backend/migrations](Scimior-backend/migrations)
- Migration application appears manual (psql -f ... comments in migration files), no dedicated migration runner script found in [Scimior-backend/scripts](Scimior-backend/scripts)
- Duplicate migration numbers exist (e.g., 036, 054, 060, 061), increasing ordering/governance risk.

### G) Background processing and integrations
- Existing recurring schedulers (node-cron) run every minute and are started at boot: [Scimior-backend/server.local.js#L70](Scimior-backend/server.local.js#L70), [Scimior-backend/utils/appointmentReminderScheduler.js#L429](Scimior-backend/utils/appointmentReminderScheduler.js#L429), [Scimior-backend/utils/salonClosingScheduler.js#L134](Scimior-backend/utils/salonClosingScheduler.js#L134)
- WebSocket server is attached in-process: [Scimior-backend/server.local.js#L58](Scimior-backend/server.local.js#L58), [Scimior-backend/websocket/websocketServer.js#L29](Scimior-backend/websocket/websocketServer.js#L29)
- No verified generic webhook verification pattern in current routes (no webhook routes/signature handlers found).
- Existing “WhatsApp message” route is placeholder/non-provider-integrated: [Scimior-backend/routes/messages.js#L11](Scimior-backend/routes/messages.js#L11), [Scimior-backend/routes/messages.js#L50](Scimior-backend/routes/messages.js#L50)

### H) Tests and commands
- Jest + Playwright scripts are defined: [Scimior-backend/package.json#L9](Scimior-backend/package.json#L9), [Scimior-backend/package.json#L13](Scimior-backend/package.json#L13)
- Jest config and test setup files present: [Scimior-backend/jest.config.js#L3](Scimior-backend/jest.config.js#L3), [Scimior-backend/jest.config.js#L46](Scimior-backend/jest.config.js#L46)

### I) UNVERIFIED items
- Exact Node runtime version in deployment (no engines field in package).
- Actual Render start command/service settings and autosuspend/restart behavior (no render.yaml/Procfile found).
- Production PostgreSQL version and extension permissions.

---

## Section 3 — Findings by severity

### P0 — Critical

F-P0-001: Canonical API route conflicts across docs
- Evidence:
  - Canonical says /api/marketing/v1: [Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/IMPLEMENTATION_GUIDE.md#L41](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/IMPLEMENTATION_GUIDE.md#L41)
  - PRD still specifies legacy /api/contacts and /api/webhooks/whatsapp: [Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/WhatsApp_Marketing_Application_Detailed_PRD_UPDATED.md#L575](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/WhatsApp_Marketing_Application_Detailed_PRD_UPDATED.md#L575), [Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/WhatsApp_Marketing_Application_Detailed_PRD_UPDATED.md#L600](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/WhatsApp_Marketing_Application_Detailed_PRD_UPDATED.md#L600)
- Impact: High risk of implementing wrong routes and breaking frontend/backed contract alignment.
- Resolution: Freeze one canonical contract (/api/marketing/v1/...) and mark all legacy examples as non-normative.
- Decision required: Yes.

F-P0-002: Tenant model conflict (organizations vs businesses)
- Evidence:
  - Canonical tenant = organizations: [IMPLEMENTATION_GUIDE.md#L39](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/IMPLEMENTATION_GUIDE.md#L39)
  - Onboarding/PRD still include businesses/business_members: [Scimior_Marketing_User_Registration_WhatsApp_Onboarding_UPDATED.md#L131](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/Scimior_Marketing_User_Registration_WhatsApp_Onboarding_UPDATED.md#L131), [WhatsApp_Marketing_Application_Detailed_PRD_UPDATED.md#L537](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/WhatsApp_Marketing_Application_Detailed_PRD_UPDATED.md#L537)
- Impact: Data model split-brain and migration churn before MVP.
- Resolution: Normalize all docs/tables/endpoints to one tenant vocabulary (organizations, organization_members, organization_id).
- Decision required: Yes.

F-P0-003: Marketing DB schema allows cross-tenant WhatsApp asset duplication
- Evidence:
  - whatsapp_accounts uniqueness is (organization_id, phone_number_id) only: [001_initial_schema.sql#L113](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/001_initial_schema.sql#L113)
- Impact: Same provider phone asset can be linked to multiple organizations unless prevented in app logic; can cause misrouting, ownership conflicts, and security incidents.
- Resolution: Add global uniqueness for provider-scoped asset keys (at minimum phone_number_id, likely also provider+waba_id) or an explicit ownership transfer flow.
- Decision required: Yes.

F-P0-004: No DB-level RLS/policies in proposed Marketing schema
- Evidence: static search found no ENABLE ROW LEVEL SECURITY / CREATE POLICY statements in [001_initial_schema.sql](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/001_initial_schema.sql)
- Impact: If credentials leak or broader DB access exists, all-tenant data exposure risk is significantly higher.
- Resolution: Decide security posture now:
  - Option A: strict app-only private DB user + network isolation (documented compensating controls)
  - Option B: add RLS + policies for tenant tables.
- Decision required: Yes.

### P1 — High

F-P1-001: Shared-process worker lifecycle is not graceful today
- Evidence:
  - Schedulers and WebSocket start on boot: [server.local.js#L58](Scimior-backend/server.local.js#L58), [server.local.js#L70](Scimior-backend/server.local.js#L70)
  - No SIGTERM/SIGINT shutdown handlers for closing HTTP server/pools/workers found in app server files.
- Impact: Campaign jobs in-flight can be interrupted on restart/deploy without controlled checkpointing.
- Resolution: Add explicit startup/shutdown orchestration before campaign worker implementation.
- Decision required: No.

F-P1-002: Existing background load competes for same Node process
- Evidence:
  - Multiple per-minute cron tasks: [appointmentReminderScheduler.js#L429](Scimior-backend/utils/appointmentReminderScheduler.js#L429), [salonClosingScheduler.js#L134](Scimior-backend/utils/salonClosingScheduler.js#L134)
- Impact: Marketing send bursts can degrade Scimior API latency unless strict concurrency and pool partitioning are implemented.
- Resolution: Define concurrency budgets, DB pool budgets, and circuit-breaking policies pre-implementation.
- Decision required: Yes (thresholds).

F-P1-003: CORS default does not include Marketing frontend origin
- Evidence: allowed origins list includes Scimior domains only: [bootstrap.js#L57](Scimior-backend/bootstrap.js#L57), [bootstrap.js#L60](Scimior-backend/bootstrap.js#L60)
- Impact: Marketing frontend will fail cross-origin calls unless environment config is updated.
- Resolution: Add marketing.scimior.com to controlled allowlist for marketing API paths.
- Decision required: No.

F-P1-004: No existing reusable webhook signature-verification pattern
- Evidence: no webhook route/signature verification conventions found in backend route scan.
- Impact: Higher risk of inconsistent/insecure webhook implementation for Meta events.
- Resolution: Define standard middleware for signature validation, replay protection, safe ACK timing.
- Decision required: No.

F-P1-005: Migration governance risk for second database workflow
- Evidence:
  - Manual migration application hints in migration files (psql -f ...)
  - Duplicate migration numbers in existing migrations directory.
- Impact: Increased chance of ordering errors and drift when introducing Marketing migrations.
- Resolution: Introduce explicit per-module migration tracking/versioning convention before first Marketing migration.
- Decision required: Yes.

F-P1-006: Existing auth middleware is salon-bound and not reusable for Marketing tenancy
- Evidence: verifyToken logic relies on salonId and salon relationship checks: [middleware/auth.js#L151](Scimior-backend/middleware/auth.js#L151), [middleware/auth.js#L244](Scimior-backend/middleware/auth.js#L244)
- Impact: Reusing existing auth middleware for Marketing would force incorrect domain coupling.
- Resolution: Build isolated Marketing auth/session middleware and role checks.
- Decision required: No.

### P2 — Medium

F-P2-001: API versioning inconsistency (/api/marketing/* vs /api/marketing/v1/*)
- Evidence: architecture lists unversioned /api/marketing/*: [Architecture doc#L111](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/Scimior_Marketing_Architecture_Design_UPDATED.md#L111), while canonical addenda require /v1.
- Impact: avoidable churn in clients and docs.
- Resolution: standardize on /api/marketing/v1 now.
- Decision required: No.

F-P2-002: Terms/privacy acceptance requirement lacks explicit schema support
- Evidence: onboarding requires storing terms/privacy acceptance: [Onboarding doc#L52](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/Scimior_Marketing_User_Registration_WhatsApp_Onboarding_UPDATED.md#L52); no dedicated acceptance table/fields in proposed SQL.
- Impact: compliance/audit gap.
- Resolution: add acceptance audit model before auth implementation.
- Decision required: Yes.

F-P2-003: Event dedup/ordering safeguards are partially modeled but not fully constrained
- Evidence:
  - webhook dedup via unique event_fingerprint: [001_initial_schema.sql#L486](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/001_initial_schema.sql#L486)
  - no obvious uniqueness constraint on message_status_events for (provider_message_id,status,timestamp) combinations.
- Impact: duplicate status ingestion can distort metrics/state transitions.
- Resolution: define exact dedup keys and terminal state transition rules now.
- Decision required: Yes.

F-P2-004: Existing backend layering is route-heavy (limited controller/repository split)
- Evidence: large SQL-heavy route files like [Scimior-backend/routes/customers.js](Scimior-backend/routes/customers.js), [Scimior-backend/routes/auth.js](Scimior-backend/routes/auth.js)
- Impact: higher chance of boundary leakage when adding Marketing module in same repo.
- Resolution: enforce module boundaries for Marketing even if legacy Scimior routes remain route-centric.
- Decision required: No.

### P3 — Low

F-P3-001: UI mockup is broad but not a complete behavioral contract
- Evidence: reference image is dashboard/list/wizard oriented and does not define backend states exhaustively: [Scimior_Marketing_Dashboard_Mockup_REFERENCE.png](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/Scimior_Marketing_Dashboard_Mockup_REFERENCE.png)
- Impact: minor risk if treated as source of truth.
- Resolution: keep image as visual-only artifact.
- Decision required: No.

---

## Section 4 — Documentation inconsistencies (discrepancy table)

| Documents | Inconsistency | Evidence | Recommended change |
|---|---|---|---|
| PRD vs Implementation/Architecture addenda | Legacy unversioned routes (/api/contacts, /api/webhooks/whatsapp) vs canonical /api/marketing/v1/* | [PRD#L575](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/WhatsApp_Marketing_Application_Detailed_PRD_UPDATED.md#L575), [Implementation Guide#L41](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/IMPLEMENTATION_GUIDE.md#L41) | Replace legacy route table with canonical /api/marketing/v1 matrix and keep old routes labeled historical example only. |
| Onboarding doc internal sections | Uses both businesses/business_members and organizations/organization_members | [Onboarding#L131](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/Scimior_Marketing_User_Registration_WhatsApp_Onboarding_UPDATED.md#L131), [Onboarding#L269](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/Scimior_Marketing_User_Registration_WhatsApp_Onboarding_UPDATED.md#L269) | Keep only canonical organization naming throughout. |
| Architecture doc route examples | Mixes /api/marketing/* and later canonical /api/marketing/v1/* | [Architecture#L111](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/Scimior_Marketing_Architecture_Design_UPDATED.md#L111), [Architecture#L670](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/Scimior_Marketing_Architecture_Design_UPDATED.md#L670) | Normalize all architecture endpoint examples to /api/marketing/v1. |
| WhatsApp checklist doc | References .docx files while working set is markdown | [whatsappMarketing_UPDATED.md#L10](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/whatsappMarketing_UPDATED.md#L10) | Update references to .md files to avoid source ambiguity. |
| PRD data model table | Uses businesses/business_members while schema SQL uses organizations | [PRD#L537](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/WhatsApp_Marketing_Application_Detailed_PRD_UPDATED.md#L537), [001 SQL#L28](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/001_initial_schema.sql#L28) | Align PRD data model terms with actual proposed SQL. |

---

## Section 5 — Database schema review

### Confirmed table inventory (from SQL)
Identity, tenancy, WhatsApp, contacts/import/segmentation, templates/audiences/campaigns, queue/jobs, inbox/messages/events, audit/usage are all present in [001_initial_schema.sql](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/001_initial_schema.sql).

### Missing or questionable entities/fields
- Terms/privacy acceptance audit fields/table: missing vs onboarding requirement.
- Explicit invitation lifecycle artifacts for org membership: not obvious in baseline schema.
- Recipient-level retry ceiling field (max_attempts) exists for jobs, not clearly for recipients.

### Incorrect/risky constraints
- WhatsApp account ownership uniqueness scoped per org, not globally provider-asset-safe: [001_initial_schema.sql#L113](Scimior-Engage-frontend/Scimior_Marketing_Copilot_Ready_Documents/001_initial_schema.sql#L113)
- webhook_events.event_fingerprint is global unique; good for dedup if fingerprint strategy is robust, but hashing scheme is UNVERIFIED.
- Message status dedup constraints are not explicit enough for replay/out-of-order handling.

### Missing indexes (high-value candidates)
- Consider composite indexes for queue claim patterns including lock columns on recipients/jobs.
- Consider additional index on webhook_events(provider, provider_event_id) if provider sends event IDs reliably.
- Consider organization-scoped indexes for conversation/message status queries used by reports.

### Tenant-isolation concerns
- Strong use of composite foreign keys in many places is good.
- DB-level RLS/policies are absent in Marketing SQL (static scan), so tenant isolation is application-only unless compensating controls are defined.

### Campaign queue/webhook concerns
- Schema supports durable jobs (marketing_jobs) and recipient states.
- Pre-send idempotency and webhook replay safety are only partially encoded; transition rules and unique constraints need finalization before implementation.

### Migration/PostgreSQL compatibility concerns
- Uses pgcrypto and gen_random_uuid(); PostgreSQL extension availability is UNVERIFIED.
- Existing backend migration practice appears manual; Marketing needs a deterministic separate migration workflow before coding.

---

## Section 6 — API contract matrix (proposed vs current backend reality)

All Marketing endpoints are new (none currently exist in backend route mounts). Existing backend is salon-domain routes only: [Scimior-backend/bootstrap.js#L324](Scimior-backend/bootstrap.js#L324).

| Canonical endpoint | Purpose | Exists now | Depends on Scimior auth/data | Key tables | External integration | Idempotency/retry/tenant notes |
|---|---|---|---|---|---|---|
| POST /api/marketing/v1/auth/register | Marketing account signup | No | No (should be standalone) | users | optional email provider | rate-limit + terms acceptance evidence required |
| POST /api/marketing/v1/auth/login | Session/token issuance | No | No | users, auth_sessions | none | avoid reuse of salon-coupled middleware |
| POST /api/marketing/v1/auth/logout | Revoke session | No | No | auth_sessions | none | idempotent revoke |
| POST /api/marketing/v1/auth/forgot-password | Recovery start | No | No | password_reset_tokens | email provider | strict rate limit |
| POST /api/marketing/v1/auth/reset-password | Recovery finish | No | No | users, password_reset_tokens | none | one-time token semantics |
| GET /api/marketing/v1/me | Current user and org memberships | No | No | users, organization_members, organizations | none | tenant-safe projection |
| POST /api/marketing/v1/organizations | Create workspace | No | No | organizations, organization_members | none | owner role bootstrap |
| GET /api/marketing/v1/organizations/:id | Workspace metadata | No | No | organizations | none | membership required |
| POST /api/marketing/v1/organizations/:id/whatsapp/onboarding-session | Start onboarding | No | No | onboarding_sessions | Meta | CSRF/state binding |
| POST /api/marketing/v1/webhooks/whatsapp/onboarding-callback | Complete onboarding | No | No | onboarding_sessions, whatsapp_accounts, whatsapp_credentials | Meta | one-time state + replay block |
| GET /api/marketing/v1/organizations/:id/whatsapp/connection | Connection status | No | No | whatsapp_accounts | Meta(optional check) | sanitized response only |
| POST /api/marketing/v1/organizations/:id/whatsapp/connection/check | Health/permission check | No | No | whatsapp_accounts | Meta | bounded retry |
| POST /api/marketing/v1/organizations/:id/whatsapp/disconnect | Disconnect/revoke | No | No | whatsapp_accounts, whatsapp_credentials, audit_events | Meta | preserve history |
| GET/POST /api/marketing/v1/contacts (+imports/groups/tags) | Contact mgmt/segmentation/import | No | Optional via provider adapter | contacts, contact_imports, groups/tags | optional Scimior provider | strict org scoping |
| GET/POST /api/marketing/v1/templates (+sync) | Template sync/list | No | No | message_templates | Meta | approval-state aware |
| POST /api/marketing/v1/campaigns/:id/start/schedule/pause/resume/cancel/retry | Campaign lifecycle | No | No | campaigns, campaign_recipients, marketing_jobs | Meta | idempotent campaign launch required |
| GET /api/marketing/v1/campaigns/:id/report/recipients | Reporting | No | No | campaigns, recipients, status events, usage_records | none | clear denominator definitions |
| GET/POST /api/marketing/v1/conversations/:id/messages | Inbox + replies | No | No | conversations, messages | Meta | messaging-window rules |
| GET/POST /api/marketing/v1/webhooks/whatsapp | Event ingest | No | No | webhook_events, message_status_events, messages | Meta | signature verify + dedup + out-of-order safe |

---

## Section 7 — Decoupling assessment

### Can Marketing be logically isolated in this backend?
Yes, but only after boundary hardening decisions.

### Module level
- Feasible to mount isolated route tree under /api/marketing/v1.
- Must not reuse salon-coupled auth middleware from [middleware/auth.js](Scimior-backend/middleware/auth.js).

### Database level
- Separate pool is technically feasible.
- Existing codebase is built around one shared exported pool; Marketing must introduce its own pool module and not import Scimior repositories.

### Authentication level
- Current auth and permission model is salon-centric (salonId, salon relationship checks).
- Marketing requires independent user/org sessions and role checks.

### API/domain model level
- Documentation now points to provider-interface-based integration; this is the correct decoupling seam.
- For optional Scimior contact integration, a CustomerProvider adapter boundary is strongly recommended (not direct table reads).

### Deployment/failure domain
- Marketing remains coupled to Scimior at process/restart/resource level while co-hosted on single Render service.
- This is acceptable for MVP only with strict workload controls and shutdown/recovery design.

---

## Section 8 — Shared deployment risk assessment (Render single service)

### Verified risks
1. CPU/memory contention between existing cron jobs/WebSocket + new campaign workers.
2. DB connection contention if second pool is added without budgets.
3. Restart interruption without graceful stop/drain and persisted claim/retry semantics.
4. Webhook spike storms could affect core Scimior API latency in same process.

### Required mitigations without adding a second service
1. Separate DB pools with explicit per-pool max and queue backpressure.
2. Per-organization and global worker concurrency caps.
3. Fast webhook ACK path + durable event persistence + async processing.
4. Graceful SIGTERM flow: stop claiming new jobs, finish/hand off inflight, close pools.
5. SLO guardrails (p95 API latency, queue age, pool saturation alerts).
6. Operational kill-switches for campaign processing during incidents.

### UNVERIFIED operational constraints
- Actual Render CPU/memory limits and suspend/restart behavior.
- Actual PostgreSQL connection limits for both DBs in production plans.

---

## Section 9 — Required decisions (only items needing your input)

1. Tenant security posture for Marketing DB
- Default recommendation: Add RLS policies for tenant tables plus app-level checks.
- Trade-off: More SQL complexity now, stronger blast-radius control later.

2. Global uniqueness rules for WhatsApp assets
- Default recommendation: enforce unique provider ownership of phone_number_id (and likely waba_id) across all organizations.
- Trade-off: stronger safety vs added transfer/reassignment workflow complexity.

3. Canonical route and entity vocabulary freeze
- Default recommendation: lock to /api/marketing/v1 + organizations.
- Trade-off: minor doc cleanup now vs large rework later.

4. Shared-hosting performance guardrails
- Default recommendation: define hard launch thresholds before coding workers.
- Trade-off: upfront planning effort vs production instability risk.

5. Migration governance for Marketing DB
- Default recommendation: independent migration numbering namespace and tracked apply-state.
- Trade-off: process overhead vs deployment drift risk.

---

## Section 10 — Prioritized remediation plan

### Documentation corrections
1. Normalize all API examples to /api/marketing/v1.
2. Remove/annotate legacy businesses/business_members and retain only canonical organization model.
3. Add a single source-of-truth endpoint matrix appendix and reference it from all docs.
4. Update checklist doc references from .docx to actual .md files.

### Database schema corrections
1. Add global/provider-scoped uniqueness rules for WhatsApp ownership.
2. Decide and implement tenant hardening strategy (RLS or explicitly documented compensating controls).
3. Add terms/privacy acceptance persistence model.
4. Finalize webhook/status dedup keys and campaign recipient retry constraints.

### API contract corrections
1. Publish canonical route family list with auth requirements and roles per endpoint.
2. Add explicit idempotency requirements for campaign launch/schedule/retry and webhook ingest.
3. Define standard error shape + correlation ID format.

### Architecture/security decisions
1. Define isolated Marketing auth/session middleware (do not reuse salon middleware).
2. Define worker lifecycle contract (startup/stop/drain/recovery).
3. Define pool budgets and per-tenant throttling policy.
4. Define webhook signature verification middleware standard.

### Development prerequisites
1. Confirm PostgreSQL version + pgcrypto availability for Marketing DB.
2. Confirm Render runtime constraints and acceptable campaign concurrency envelope.
3. Define migration execution protocol for Marketing DB.
4. Define monitoring dashboards/alerts for queue, latency, pool saturation, webhook failures.

---

## Section 11 — Development readiness checklist

- [ ] All docs use canonical organizations tenant model.
- [ ] All docs use canonical /api/marketing/v1 routes only.
- [ ] Endpoint matrix approved with authz, validation, idempotency, and tenant rules.
- [ ] Marketing DB security posture decision made and reflected in SQL.
- [ ] WhatsApp asset uniqueness/ownership rules finalized.
- [ ] Worker lifecycle (graceful shutdown + restart recovery) design approved.
- [ ] DB pool budgets and latency protection thresholds approved.
- [ ] Migration governance and environment promotion flow approved.
- [ ] Webhook verification + replay/out-of-order handling contract approved.
- [ ] PostgreSQL version/extension compatibility verified.
- [ ] Render operational constraints and scaling assumptions verified.
- [ ] Monitoring/alerting and incident runbook prerequisites defined.

---

## Direct answer to your final question
No, not safely yet.

You can safely begin implementation only after fixing or deciding these first:

1. Freeze canonical API and entity model (/api/marketing/v1, organizations).
2. Resolve WhatsApp ownership uniqueness and tenant security strategy in schema.
3. Define worker lifecycle and resource guardrails for single-process Render hosting.
4. Finalize migration governance and operational prerequisites (Postgres/Render verification).

Once those are locked, the current backend architecture can support a logically decoupled Marketing module, but with shared deployment risk controls in place.
