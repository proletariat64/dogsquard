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

# Planning-phase Validation

Production implementation planning should validate:

- planning approval is documented without implying implementation approval
- required implementation decisions are listed
- target host and route decisions remain unresolved unless explicitly approved
- no production workflow is added
- no server or reverse proxy config is changed
- no deploy command is run
- protected targets remain blocked by policy

Current planning evidence:

- `us.hermes` is selected as the first production planning target.
- `proletariat.icu/{reponame}/` is the approved frontend route shape.
- `proletariat.icu/{reponame}/api` is the approved backend route shape.
- production implementation remains unapproved.

# Future Implementation Validation

Future approved implementation should validate:

- production config preflight fails clearly when required values are missing
- protected host/domain guard rejects unsafe targets
- package and deploy steps use existing release artifacts where possible
- runtime health runs before route activation
- rollback requires an explicit release id
- failure diagnostics do not dump secrets or raw server config

# First Launch Validation Results

The first production launch activation was completed for `dogpdteamreport`.

Validated:

- frontend route `https://proletariat.icu/dogpdteamreport/` returned HTTP 200 and served app HTML
- backend route `https://proletariat.icu/dogpdteamreport/api/health` returned JSON health success
- static assets loaded under `/dogpdteamreport/`
- rollback switched to a previous release and then rolled forward to the fixed release
- final active release was `20260601131820-67b0897f3892`
- existing multica behavior remained on `www.proletariat.icu` `/` and `/api`

Additional regression expectations for future adopted apps:

- `/{reponame}` redirects to `/{reponame}/`
- `/{reponame}/` returns frontend HTML and does not self-redirect
- deploy root expansion does not create a literal `$HOME/~` directory
- route activation checks the active nginx file, not only a `sites-available` copy

# Negative Tests

Future tests must confirm production deploy does not:

- target raw `43.130.49.185`
- claim `proletariat.icu` `/`
- claim `proletariat.icu` `/api`
- claim a `proletariat.icu` route outside the approved `/{reponame}/` prefix
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

For the implementation planning PR:

- local docs checks pass
- PR Quality Gate passes
- planning scope is documented
- implementation remains blocked until separate explicit approval
