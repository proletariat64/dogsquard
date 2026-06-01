---
title: "Production Deployment Test Plan"
doc_type: "test"
status: "draft"
owner: "user"
source: "agent"
created: "2026-06-01"
updated: "2026-06-01"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Objective

Define how future production deployment support should be validated without implementing it in this design phase.

# Design-phase Validation

This phase should validate:

- production deployment docs exist
- production implementation is not added
- no production workflow is added
- no reverse proxy config is committed
- no public URL is exposed
- `us.hermes` and `proletariat.icu` protections are documented

# Future Implementation Validation

Future approved implementation should validate:

- production config preflight fails clearly when required values are missing
- protected host/domain guard rejects unsafe targets
- package and deploy steps use existing release artifacts where possible
- runtime health runs before route activation
- rollback requires an explicit release id
- failure diagnostics do not dump secrets or raw server config

# Negative Tests

Future tests must confirm production deploy does not:

- target `us.hermes` without explicit route approval
- target `43.130.49.185` without explicit route approval
- claim `proletariat.icu` `/`
- claim `proletariat.icu` `/api`
- restart nginx, caddy, traefik, or multica by default
- require sudo in the default path
- commit secrets or raw server output

# Acceptance Criteria

For the design PR:

- local docs checks pass
- PR Quality Gate passes
- no deployment behavior changes
- no server behavior changes
- no production workflow is added

For a future implementation PR:

- production deploy is opt-in
- environment protection is configured
- approval gate is documented
- rollback is tested before public exposure
