---
title: "Production Deployment PRD"
doc_type: "prd"
status: "draft"
owner: "user"
source: "agent"
created: "2026-06-01"
updated: "2026-06-01"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Purpose

Define the production deployment problem Dogsquard must solve after proving bootstrap, adoption, operating-loop follow-up, and one real product feature loop.

This PRD is design-only. It does not approve or implement production deployment.

# Target User

The user as solo product owner, operator, and reviewer of small and medium internal application repositories.

# Problem Statement

Dogsquard can now bootstrap and operate real project repos, but production deployment remains intentionally unimplemented.

Production deployment needs a safe design that:

- protects existing `us.hermes` and `proletariat.icu` routing
- keeps multica untouched
- separates Dogsquard template behavior from adopted app production behavior
- defines explicit approval gates before any server change

# Goals

- define production deployment as an opt-in profile for adopted apps
- identify safe production target options
- define route/domain strategy options
- define required secrets and environment variables without committing values
- define rollback, health, diagnostics, and failure behavior
- define approval gates before implementation
- keep dev deploy and production deploy separate

# Non-goals

- no production implementation
- no GitHub Actions production workflow in this phase
- no reverse proxy config
- no server config changes
- no deployment to `us.hermes`
- no changes to `proletariat.icu`, `/`, or `/api`
- no public URL exposure
- no Docker migration
- no database/auth expansion

# Production Scope Boundary

Dogsquard is the reusable operating kit, not the business product.

Production deployment design should primarily describe how adopted apps can opt into a production deployment profile generated or guided by Dogsquard.

Dogsquard itself should not become a production service unless a future explicit decision says so.

# Candidate Target Strategies

## Option A: Dedicated Production Host

Use a host separate from `us.hermes` and `cn.ant`.

Pros:

- lowest risk to existing multica
- clean production isolation
- easier rollback and monitoring boundaries

Cons:

- requires host provisioning
- requires DNS and certificate setup

## Option B: `us.hermes` With Approved Route Strategy

Use `us.hermes` only after an explicit route plan protects existing multica.

Candidate routes must not claim:

- `/`
- `/api`

Possible future routes:

- subdomain, such as `<app>.proletariat.icu`
- path prefix, such as `/apps/<app>`

Pros:

- uses existing public host
- can share existing operational knowledge

Cons:

- highest risk to multica if route boundaries are unclear
- requires reverse proxy design and approval
- requires certificate and route validation

## Option C: `cn.ant` Production Promotion

Promote `cn.ant` from dev host to production-like host only after explicit approval.

Pros:

- Dogsquard deployment path is already validated there for dev
- avoids `us.hermes` multica routing initially

Cons:

- current public access is designed for dev high ports
- production HTTPS/domain strategy still missing
- dev and production isolation would need careful separation

# Recommended Staged Approach

1. Keep production deployment unimplemented.
2. Complete a production design PR.
3. Choose first production target and route strategy explicitly.
4. Add a production implementation PR only after user approval.
5. Validate rollback and health before exposing a public route.

# Required Configuration Categories

Future implementation will need:

- production host
- production user
- SSH key or deployment credential
- deploy root
- app name
- runtime ports
- public route or domain
- protected host/domain list
- rollback release id

No real values should be committed.

# Acceptance Criteria

- production scope boundary is documented
- `us.hermes` and `proletariat.icu` protections are explicit
- route/domain options are documented
- approval gates are defined
- rollback and failure expectations are defined
- no production implementation is added
