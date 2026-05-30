---
title: "CI Quality Gates Test Plan"
doc_type: "test"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# CI Quality Gates Test Plan

## Purpose

This test plan documents the current Dogsquard CI quality gates and how they should be treated before branch protection is enabled.

## Current Required Checks

The recommended required branch protection check is:

```text
PR Quality Summary
```

The summary job depends on:

- `Shell Check`
- `Repository Hygiene`
- `Local Foundation`
- `Playwright Smoke`
- `Temporary Scope Guard`

If any dependency fails or is cancelled, `PR Quality Summary` fails.

## Current Advisory Checks

Individual jobs are useful for diagnosis and may be viewed directly:

- `Shell Check`
- `Repository Hygiene`
- `Local Foundation`
- `Playwright Smoke`
- `Temporary Scope Guard`

For branch protection, the summary job should be required first to keep the protected-branch rule simple.

## Current Excluded Checks

Phase 5E does not require:

- deployment smoke tests
- production release checks
- Docker build checks
- database integration checks
- authentication checks
- self-hosted runner UAT
- full Playwright regression
- label sync automation
- external SaaS integrations

These remain future phases or explicit later decisions.

## Mapping To Local Commands

CI maps to local commands as follows:

| CI job | Local command |
| --- | --- |
| Shell Check | `bash -n scripts/*.sh` |
| Repository Hygiene | `git diff --check` |
| Local Foundation | `make help`, `make doc-check`, `make doc-guard`, `make release-check` |
| Playwright Smoke | `make e2e-smoke` |
| Temporary Scope Guard | review changed file paths against current phase scope |
| PR Quality Summary | all required jobs succeeded |

## Playwright Smoke Scope

The Playwright smoke test is intentionally minimal.

It verifies:

- app loads
- empty state is visible
- valid task can be created through UI
- validation error is visible when title is missing

It does not verify every CRUD path, status update behavior, delete behavior, auth, deployment, or production readiness.

Minimal smoke gives Dogsquard a deterministic browser check without turning Phase 5D or Phase 5E into a full frontend regression project.

## Future Expansion

Future gates may add:

- full Playwright regression
- deployment smoke checks
- production release gate
- self-hosted runner UAT
- dependency or vulnerability scanning
- release artifact checks

Each future gate should be introduced through a focused phase and documented before it becomes required.

## Acceptance Criteria For Phase 5E

- branch protection guidance exists
- CI failure debugging guidance exists
- current CI gates are documented
- `PR Quality Summary` is documented as the recommended required check
- future checks are clearly separated from current checks
- no deployment, Docker, database, auth, production release, self-hosted runner, full regression, or new product feature is added
