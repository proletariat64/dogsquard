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

This document stores the detailed roadmap and project history for Dogsquard.

Issue #1 stores the one-screen dashboard: current milestone, objective, capability map, decisions, open questions, guardrails, latest completed work, and next deliverable.

The Issue #1 dashboard should use checkbox/todo style with green, yellow, and red status indicators. It should show a high-level capability map while breaking down only the next two or three deliverables into actionable task detail.

The roadmap should preserve the full project picture without turning Issue #1 into a historical changelog.

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

- documentation directory model
- document metadata, naming, and lifecycle rules
- local documentation checks
- Doc Watch Guard concept
- inbox, archive, and generated document rules

### 2. Local Foundation

- Makefile command center
- safe placeholder environment example
- local doc-check and release-check commands
- local helper scripts for docs, smoke, packaging, deploy, runtime, and preflight

### 3. GitHub Workflow Foundation

- GitHub issue templates and PR template
- label source definition and labels runbook
- PR Quality Gate
- branch protection guidance
- CI failure debugging and quality gates docs

### 4. Example Internal App

- Go backend and JS/TS frontend skeleton
- Internal Task Intake CRUD flow
- backend validation and JSON error shape
- API smoke script
- minimal Playwright smoke test

### 5. Dev Deployment Foundation

- `cn.ant` selected as first dev target
- `us.hermes` protected because it hosts `proletariat.icu` and multica
- release artifact packaging and manual SSH deploy
- user-level runtime start, stop, status, health, logs, diagnose, and rollback
- GitHub Actions Dev Deploy workflow implemented, validated, and hardened

### 6. Dev Public Access Design

- firewall constraints documented
- SSH tunnel first approach documented
- direct high-port option deferred
- reverse proxy and HTTPS option deferred
- no public URL exposed yet

### 7. Template Finalization and Real-world Trial

- Dogsquard `v0.1.0` released
- fresh new-repo bootstrap trial passed
- `dogpdteamreport` real-world trial applied Dogsquard governance to a Node/Express app
- trial evidence showed project profiles are needed
- `PROJECT_TYPE=node` identified as the first `v0.1.1` candidate

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

Validation details can be summarized in the PR body and relevant test docs rather than split into command-sized PRs.

## Future Roadmap

### Milestone 6D: Dev Access Stabilization

Status: in review.

Result:

- SSH tunnel access validated for `cn.ant`
- SSH tunnel is the current recommended dev access mode
- direct high-port public access remains optional future work
- reverse proxy and HTTPS remain optional future work
- no `us.hermes`
- no production

### Milestone 6E: Template Finalization

6E should remain bounded to template finalization and project-profile strategy. Do not create command-sized micro-milestones.

Deliverables:

- 6E-A Template Productization Design: done
- 6E-B Template Finalization Implementation: done
- `v0.1.0` release candidate and fresh-repo trial: done
- Project Profiles and Bootstrap Strategy: current
- Bootstrap Script PR with `PROJECT_TYPE=node`, `PROJECT_TYPE=go-js`, and `PROJECT_TYPE=docs-only`: in progress

Scope:

- define template kit boundary
- decide example app handling
- decide agent-local files policy
- design and implement bootstrap/init flow
- improve README as template entrypoint
- define final local, CI, and dev-deploy checklist
- define project-type profiles for adoption into existing repos

Current 6E result:

- README acts as the Dogsquard template entrypoint
- bootstrap script initializes conservative template core
- example app is optional material
- dev deploy assets are optional material
- agent-local files are excluded unless explicitly templated
- real-world Node trial identified profile-aware bootstrap as the next improvement

`v0.1.1` candidate direction:

- add profile-aware bootstrap through `scripts/bootstrap-project.sh`
- support `PROJECT_TYPE=node`
- support `PROJECT_TYPE=go-js`
- support `PROJECT_TYPE=docs-only`
- generate npm-based Makefile and PR Quality Gate
- preserve existing README, `ddd/`, `spec/`, source, and tests
- keep Dogsquard example app and dev deploy workflow opt-in
- keep dry-run and overwrite safety as defaults
- validate profile behavior with `make bootstrap-test`

### Milestone 7: Production Deployment Later

Includes:

- production deployment design
- approval gate
- tags and releases
- `us.hermes` only after explicit route plan
- no accidental multica impact

## Open Questions

- When should Dogsquard become a reusable template release?
- Do we need direct high-port access on `cn.ant` later?
- Do we need a dev domain or subdomain later?
