---
title: "Dogsquard Project Roadmap"
doc_type: "design"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-06-02"
related_issue: "#1, #42"
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

## Bounded Control Board Model

Issue #1 remains the project cockpit, but it must not become an infinite task factory.

The Control Board should now show:

- Freeze State
- Frozen Scope
- Change Requests
- Later / Parking Lot
- Current Milestone and Objective
- Capability Map
- Now / Next / Later
- Current Decisions
- Open Questions
- Guardrails
- Latest Completed
- Next Deliverable

The Freeze Model controls expansion:

- Design Draft allows exploration and candidate tasks.
- Design Frozen stops major design expansion unless the user re-approves scope.
- Implementation Plan Draft defines exact files or areas, acceptance criteria, non-goals, validation, PR budget, and artifact budget.
- Implementation Plan Frozen allows only Frozen Scope, blockers, safety fixes, acceptance-criteria requirements, or user-approved Change Requests.
- Released means the deliverable met its release stop rule and new ideas go to Change Requests or Later.
- Reopened is only for acceptance-criteria gaps, CI/test failures, safety/security issues, or explicit user direction changes.

After freeze, discovery creates Change Requests or Later items instead of automatic Now tasks.

## Scope Control Rules

### Frozen Scope

Each active deliverable should define:

- outcome
- must-change files or areas
- may-change files or areas
- must-not-change non-goals
- acceptance criteria
- PR budget
- artifact budget

Every Now item after Implementation Plan Freeze must map to Frozen Scope or to an approved Change Request.

### Change-Control Entry Criteria

New work may enter Now after freeze only if:

- it blocks Frozen Scope
- it fixes a safety or security issue
- it is required by acceptance criteria
- the user explicitly approves scope expansion

Otherwise it belongs in Change Requests, Later, Case Study, or Archive.

### Artifact Budget

Artifact cost should match change complexity.

| Tier | Change type | Expected artifacts |
|---|---|---|
| 0 | typo, wording, link, README clarification | PR body only |
| 1 | small script, Makefile, or doc-check fix | PR body and direct test if needed |
| 2 | workflow behavior change | affected runbook or test update, not full bundle |
| 3 | new reusable capability | short design or PRD, test, and runbook if humans operate it |
| 4 | production, security, or server mutation | PRD/design, ADR, runbook, test plan, explicit approval, and safety gate |

Do not create a PRD + BDD + ADR + runbook + test-plan bundle unless the work is Tier 3 or Tier 4, the user approved the capability, the Control Board artifact budget allows it, and the PR explains why each artifact is needed.

### PR Budget

One capability should normally take one or two PRs.

More than two PRs for the same capability requires a Control Board budget exception that explains:

- why another PR is needed
- what risk is avoided by splitting
- which files or areas are affected
- why the split is not task sprawl
- the user approval record

Small work should usually skip a separate design PR.

## Template Scope Classification

Dogsquard should separate reusable core from real-project evidence.

| Class | Meaning | Rule |
|---|---|---|
| Core | minimal default-on template behavior | requires explicit reason and should remain small |
| Optional Pattern | reusable but opt-in capability | must not become default-on without user approval and evidence |
| Case Study | evidence from one real project | becomes Core only after repeated evidence or explicit approval |
| Archive | historical or superseded detail | preserves context but must not drive current scope |

Current Core:

- README canonical entrypoint
- `scripts/bootstrap-project.sh`
- `scripts/test-bootstrap-project.sh`
- Makefile profile commands
- basic docs governance
- issue templates
- PR template
- PR Quality Gate
- basic local/private file ignore policy
- minimal agent charter and Control Board guidance

Current Optional Patterns:

- dev deploy pattern
- production profile scaffold
- runtime scripts
- rollback pattern
- high-port dev access
- production health investigation runbook

Current Case Studies:

- `dogpdteamreport` bootstrap trial
- `dogpdteamreport` production launch lessons
- production 502 investigation

## Stable Safety Invariants

Stable safety rules:

- do not commit secrets
- do not commit raw server config or raw logs
- do not claim protected routes `/` or `/api`
- do not touch reverse proxy or server config without explicit approval
- do not deploy, restart, or rollback production runtime without explicit approval

Operational lessons from production should first be classified as Optional Pattern or Case Study. They become Core only when the user approves that promotion or repeated evidence proves they are broadly reusable.

## Current Release Stop Rule

Current release target: `v0.1.x` bounded operating model correction.

Release when:

- Issue #1 operating model has Freeze State, Frozen Scope, Change Requests, and Later guidance
- Control Board runbook defines design freeze and implementation plan freeze
- artifact budget and PR budget are documented
- Core / Optional Pattern / Case Study / Archive distinction is documented
- PR template asks reviewers to confirm scope control
- no unapproved production automation is added

Do not include in this release:

- next production app selection
- route automation
- new deploy workflow
- reverse proxy or server mutation behavior
- new PRD, BDD, ADR, or standalone test plan for this process correction

After release:

- new ideas go to Later or Change Requests
- no new scope enters Now without explicit approval or change-control criteria

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
- cn.ant high-port dev access is now the default app-profile bootstrap direction
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
- Bootstrap Script PR with `PROJECT_TYPE=node`, `PROJECT_TYPE=go-js`, and `PROJECT_TYPE=docs-only`: done
- v0.1.1 Bootstrap Fixes: current

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
- dev deploy assets are default for app profiles and disabled by default for docs-only
- cn.ant high-port dev access defaults are part of app profile bootstrap output
- agent-local files are excluded unless explicitly templated
- real-world Node trial identified profile-aware bootstrap as the next improvement

`v0.1.1` candidate direction:

- add profile-aware bootstrap through `scripts/bootstrap-project.sh`
- support `PROJECT_TYPE=node`
- support `PROJECT_TYPE=go-js`
- support `PROJECT_TYPE=docs-only`
- generate npm-based Makefile and PR Quality Gate
- generate dev deploy support by default for app profiles
- generate cn.ant high-port dev defaults on ports `8173` and `8180`
- preserve existing README, `ddd/`, `spec/`, source, and tests
- keep Dogsquard example app opt-in
- keep docs-only deploy-free by default
- keep dry-run and overwrite safety as defaults
- append local/private agent file ignores
- validate profile behavior with `make bootstrap-test`

### Milestone 7: Production Deployment Design

Before starting production design, close the Dogsquard operating-loop follow-up from the first real adopted project.

Operating-loop follow-up scope:

- browser/manual UI verification expectations for frontend-heavy product PRs
- legacy tracked agent-file handling during adoption
- old remote-host e2e tests as opt-in validation
- keeping Dogsquard process improvements separate from product work

Status: current.

Design scope:

- production deployment design
- approval gate
- tags and releases
- `us.hermes` only after explicit route plan
- no accidental multica impact

Current design direction:

- production deployment is an opt-in profile for adopted apps
- Dogsquard itself remains the reusable operating kit, not a production service by default
- production implementation is not approved by design work alone
- first production planning target is `us.hermes`
- approved route shape is `proletariat.icu/{reponame}/` for frontend and `proletariat.icu/{reponame}/api` for backend
- route/domain strategy must protect `proletariat.icu` `/` and `/api`
- a dedicated production host remains the lowest-risk option if one is available

### Milestone 7A: Production Implementation Planning

Status: completed.

The user has explicitly approved production implementation planning only.

Planning scope:

- convert production design into a future implementation scope
- list required target, host, route, and approval decisions
- define protected target and route guardrails
- define safe PR sequencing
- keep implementation blocked until separately approved
- add scaffold-only production profile templates, checklists, and guards for adopted apps

Planning exclusions:

- no production workflow implementation
- no production deploy
- no server or reverse proxy changes
- no public route exposure
- no `us.hermes` activation until separate production implementation approval

Recommended next step after planning:

- review the scaffold-only production profile PR
- if implementation is approved later, open one focused production implementation PR
- if implementation is deferred, return to product feature work or Dogsquard hardening

### Milestone 7B: First Production Launch Activation

Status: completed for `dogpdteamreport`.

The first production proof app is live on the approved route:

- frontend: `https://proletariat.icu/dogpdteamreport/`
- backend: `https://proletariat.icu/dogpdteamreport/api`

Validated launch evidence:

- production deploy/runtime/health/rollback support was implemented in the adopted app
- route activation was scoped to `/dogpdteamreport`
- rollback was validated and the app was rolled forward to the fixed release
- existing multica behavior on `www.proletariat.icu` `/` and `/api` was preserved

Reusable lessons are captured in:

- `docs/05_design/design-20260601-first-production-launch-findings.md`

Recommended next step after launch:

- fold concrete reusable lessons back into Dogsquard production profile guidance
- do not automate raw reverse proxy edits yet
- keep future production routes approval-gated

## Open Questions

- When should Dogsquard become a reusable template release?
- Do we need direct high-port access on `cn.ant` later?
- Do we need a dev domain or subdomain later?
- Which adopted app should be the first production implementation target?
- What production approval gate should be enforced in GitHub before implementation?
- Should the first implementation PR be scaffold-only or include a production workflow?
- Should route activation remain a manual operator step or become an approval-gated workflow after more proof apps?
