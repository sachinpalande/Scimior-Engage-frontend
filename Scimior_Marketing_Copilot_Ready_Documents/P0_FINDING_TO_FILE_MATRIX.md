# P0 Finding-to-File Matrix

Date: 2026-10-09

| P0 finding | Resolution summary | Files updated |
|---|---|---|
| RLS allowed app-role access to NULL-tenant globals | App-role policies now require non-null tenant context; service-only policies cover global workflows | 001_initial_schema.sql, DATABASE_SCHEMA_DESIGN.md, ADR_001_TENANT_SECURITY_AND_WORKER_HOSTING.md |
| Role/grant boundary undefined | Roles, ownership, grants and force-RLS encoded in SQL and documented | 001_initial_schema.sql, DATABASE_SCHEMA_DESIGN.md, ADR_001_TENANT_SECURITY_AND_WORKER_HOSTING.md |
| Secure bootstrap paths undefined | Bootstrap role and flow mapping documented and encoded in SQL policy boundaries | 001_initial_schema.sql, CANONICAL_API_CONTRACT.md, DATABASE_SCHEMA_DESIGN.md |
| Migration runner safety undefined | Runner specification defines URL-only source, URL equality reject, explicit target identity allowlist, checksums and ordering | MARKETING_MIGRATION_CONVENTION.md, 001_initial_schema.sql |
| Composite FK delete conflicts | Replaced conflicting composite SET NULL actions with RESTRICT semantics | 001_initial_schema.sql |
| full_name mismatch | users.full_name added and contract aligned | 001_initial_schema.sql, CANONICAL_API_CONTRACT.md |
| Generic idempotency mismatch | idempotency_keys table added; contract/schema aligned | 001_initial_schema.sql, CANONICAL_API_CONTRACT.md, DATABASE_SCHEMA_DESIGN.md |
| status-rank enforcement mismatch | Trigger-based non-regression enforcement added and documented | 001_initial_schema.sql, DATABASE_SCHEMA_DESIGN.md |
| Migration numbering confusion | Convention examples changed to avoid duplicating 001 content | MARKETING_MIGRATION_CONVENTION.md |
| Overstated closure in reporting | Changelog/final reports updated to distinguish spec resolution vs implementation/validation pending | FINDING_RESOLUTION_CHANGELOG.md, PRE_DEVELOPMENT_REMEDIATION_FINAL_REPORT.md, FINAL_DEVELOPMENT_READINESS_GATE_REPORT.md |
