---
title: "Dogsquard Project Roadmap"
doc_type: "design"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Dogsquard Project Roadmap

## Purpose

This document is the durable roadmap and progress history source for Dogsquard.

Issue #1 remains the compact Control Board for current state, next focus, decisions, open questions, and blocked items.

Detailed completed phase history belongs here, not in Issue #1.

## Current Product Definition

Dogsquard is the user's reusable vibe-coding bootstrap kit for future small and medium internal application repositories.

It is not the business product itself.

Dogsquard exists to make future internal app repositories easier to initialize, govern, test, deploy, and maintain with agent-heavy coding and human-controlled product decisions.

## Operating Model

- one-person maintenance
- agent-heavy implementation
- human-controlled design, review, and process
- GitHub Issue and PR driven workflow
- SDD, PRD, BDD, and ADR driven development
- TDD-friendly coding
- strict PR checks
- automated dev deploy
- documentation governance

## Completed Capability Groups

### 1. Documentation Governance

Completed capabilities:

- documentation directory model
- document metadata rules
- document naming rules
- document status lifecycle
- local documentation checks
- Doc Watch Guard concept
- archive and inbox rules

### 2. Local Foundation

Completed capabilities:

- Makefile command center
- local doc checks
- release-check
- safe placeholder environment example
- local scripts for doc checking, doc watch, agent prompt generation, smoke checks, packaging, deploy, runtime, and server preflight

### 3. GitHub Workflow Foundation

Completed capabilities:

- GitHub issue templates
- pull request template
- label source definition
- PR Quality Gate
- branch protection guidance
- CI failure debugging guidance
- CI quality gates test plan

### 4. Example Internal App

Completed capabilities:

- Go backend skeleton
- JS/TS frontend skeleton
- Internal Task Intake CRUD model
- backend validation and JSON errors
- API smoke script
- frontend loading, empty, and error states
- minimal Playwright smoke test
- local e2e smoke runner

### 5. Dev Deployment Foundation

Completed capabilities:

- `cn.ant` selected as first dev target
- `us.hermes` protected because it hosts `proletariat.icu` and multica
- server preflight scripts and runbooks
- release artifact packaging
- manual SSH deploy
- user-level runtime start, stop, status, health, logs, diagnose, and rollback
- GitHub Actions Dev Deploy workflow
- Dev Deploy workflow validation
- Dev Deploy workflow hardening

### 6. Dev Public Access Design

Completed capabilities:

- firewall constraints documented
- SSH tunnel first approach documented
- direct high-port option deferred
- reverse proxy and HTTPS option deferred
- `us.hermes` remains excluded
- no public URL exposed yet

## Key Infrastructure Decisions

- `cn.ant` is the first dev deploy target.
- `us.hermes` hosts `proletariat.icu` and multica.
- Dogsquard must not claim `proletariat.icu` `/` or `/api`.
- `us.hermes`, `43.130.49.185`, `proletariat.icu`, and `www.proletariat.icu` are protected targets for the dev deploy workflow.
- GitHub Actions is the CI/CD authority.
- GitHub-hosted runner is enough for now.
- Production deployment is future and requires explicit approval.
- Current public access is not exposed yet.
- Firewall accessible ports are `80`, `22`, `443`, `8000-8999`, and ICMP.

## PR Granularity Rules

### Good PR Size

A good PR represents:

- one deliverable capability
- one workflow-level improvement
- one coherent doc or design package
- one bounded implementation plus tests and docs

### Too Small

Avoid PRs for:

- one SSH command check
- one tunnel check
- one comment update
- one validation line
- one typo unless urgent

### Too Large

Avoid combining unrelated high-risk surfaces, such as:

- deployment, production, public routing, and Docker in one PR
- backend feature, CI workflow, and server config in one PR
- product behavior change and infrastructure rollout in one PR

### Rule

A PR should be reviewable in one sitting and leave the repo in a coherent state.

Validation details can be summarized in the PR body and detailed docs rather than split into command-sized PRs.

## Future Roadmap

### Milestone 6D: Dev Access Stabilization

Includes:

- SSH tunnel validation
- decide whether direct high-port public access is needed
- maybe update runtime ports to firewall-friendly public candidates only if explicitly chosen
- document final dev access mode
- no `us.hermes`
- no production

### Milestone 6E: Template Finalization

Includes:

- cleanup template instructions
- bootstrap and init docs
- how to create a new repo from Dogsquard
- agent onboarding files decision
- final local, CI, and dev-deploy checklist
- README improvement
- maybe release `v0.1.0`

### Milestone 7: Production Deployment Later

Includes:

- production deployment design
- approval gate
- tags and releases
- `us.hermes` only after explicit route plan
- no accidental multica impact

## Open Questions

- Is SSH tunnel enough for dev validation?
- Do we need direct high-port access on `cn.ant`?
- Do we need a dev domain or subdomain later?
- When should Dogsquard become a reusable template release?
- Should agent-local files like `AGENTS.md`, `CLAUDE.md`, and `roster.md` be committed or ignored?

## Control Board Policy

Issue #1 should contain only:

- current milestone
- current focus
- next deliverable
- current decisions
- open questions
- blocked items
- links to roadmap and docs

Issue #1 should not contain:

- full historical changelog
- every PR detail
- every command-level validation
- endless micro-phase checklist

Detailed history and milestone grouping belong in this roadmap document.
