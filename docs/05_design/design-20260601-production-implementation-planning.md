---
title: "Production Implementation Planning"
doc_type: "design"
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

Define the planning boundary for a future production implementation PR after the user explicitly approved production implementation planning.

This document does not approve production implementation itself. It converts the completed production design into a reviewable implementation plan and preserves the approval gate before any production workflow, route, server, or public exposure change.

# Approval Boundary

Approved now:

- production implementation planning
- implementation scope definition
- target and route decision checklist
- safety guard definition
- future PR sequencing

Not approved now:

- production deployment workflow implementation
- reverse proxy changes
- server configuration changes
- public route activation
- production deploy runs
- `us.hermes` changes
- `proletariat.icu` `/` or `/api` changes

# Planning Objective

Prepare a coherent production implementation path for Dogsquard-adopted apps while keeping Dogsquard itself a reusable operating kit.

The next implementation PR, if separately approved, should be small enough to review in one sitting and broad enough to deliver a useful production deployment capability.

# Candidate Implementation Shape

The recommended implementation shape is an opt-in production profile for adopted apps.

The first implementation PR should prefer generated or templated repo assets over server-side activation:

- production runbook template
- production environment variable names
- GitHub production environment guidance
- protected target guard list
- production deploy workflow skeleton only if explicitly approved
- package, health, rollback, and diagnostics contract

The first implementation PR should not activate a public route unless the route/domain plan is approved in the same prompt or in a prior Control Board decision.

# Required Decisions Before Implementation

Before production implementation starts, the Control Board should answer:

- Which adopted app is the first production target?
- Which host is approved for production?
- Is `us.hermes` explicitly approved, or is a dedicated host preferred?
- What route or domain is approved?
- How does the route avoid `proletariat.icu` `/` and `/api`?
- Which GitHub environment owns production approval?
- What rollback release id is used for rollback validation?
- What diagnostics are safe to collect?

# Protected Targets

Any implementation plan must continue to protect:

- `us.hermes`
- `43.130.49.185`
- `proletariat.icu`
- `www.proletariat.icu`
- `proletariat.icu` `/`
- `proletariat.icu` `/api`
- existing multica containers
- existing reverse proxy configuration
- existing SSL configuration

# Candidate Target Order

## 1. Dedicated Production Host

Lowest operational risk if available.

Use when the user wants production isolation and can provide host, domain, and certificate strategy separately.

## 2. `cn.ant` Production-like Target

Useful for proving production workflow mechanics away from `us.hermes`.

This still requires separation from dev deploy roots, explicit production ports, and a route/domain decision before public exposure.

## 3. `us.hermes`

Highest risk because it hosts multica through `proletariat.icu`.

Only consider after explicit route approval that preserves:

- `/`
- `/api`
- multica frontend
- multica backend
- reverse proxy configuration

# Implementation Guardrails

Future implementation must:

- remain opt-in
- fail closed when required production settings are missing
- reject protected hosts and routes by default
- require GitHub environment approval
- keep secrets in GitHub secrets, not committed files
- avoid dumping raw server config or logs
- validate health before any route activation
- require explicit rollback target for rollback
- avoid `sudo` in default paths unless separately approved

# Suggested Next PR

If implementation is approved, the next PR should be:

```text
chore: add production profile scaffold
```

Suggested scope:

- add production profile docs/templates
- add production configuration preflight naming
- add protected target guard tests
- add generated production runbook content for adopted apps
- do not activate public route
- do not deploy to production

# Acceptance Criteria

This planning PR is complete when:

- production implementation planning boundary is documented
- required decisions before implementation are listed
- protected target guardrails remain explicit
- roadmap and Control Board reflect implementation planning as active
- production implementation remains blocked until separate explicit approval
