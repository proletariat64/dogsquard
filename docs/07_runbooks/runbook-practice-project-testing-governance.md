---
title: "Practice Project Testing Governance Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-06-09"
updated: "2026-06-09"
related_issue: "#50"
related_pr: ""
supersedes: ""
---

# Practice Project Testing Governance Runbook

## Purpose

This runbook gives small Dogsquard practice projects a lightweight testing governance template.

Use it when a project needs testing expectations that are specific enough for PR review but not heavy enough to become a full QA program.

It fits projects with:

- basic CRUD backend/frontend behavior
- a small canonical seed dataset
- dashboard or summary read models
- single-session update/delete usage
- no current concurrency, load, fuzz, or security-test requirement

## Testing Taxonomy

### Smoke Test

Smoke tests prove the app starts and the main path is reachable.

Typical checks:

- backend starts locally
- seed data loads
- health or core read endpoint returns success
- frontend can load the main screen when relevant

Smoke tests should be fast and should not claim broad coverage.

### API Contract Test

API contract tests protect frontend-facing response shapes.

Typical checks:

- response envelope
- field names
- list and detail shapes
- status codes
- JSON error structure

Use these tests when backend routes, API docs, frontend API consumers, or shared DTOs change.

### CRUD And Relationship Functional Test

CRUD and relationship functional tests prove the core data behavior works together.

Typical checks:

- create, read, update, and delete behavior
- required-field validation
- reference validation
- relationship consistency across people, teams/tags, products, goals, or equivalent project entities

For small practice projects, these tests should focus on expected usage and important integrity rules, not exhaustive boundary exploration.

### Seed/Data Integrity Test

Seed/data integrity tests prove canonical seed data is loadable and internally consistent.

Typical checks:

- expected record counts
- required columns or fields
- unique identifiers
- valid references between seeded entities
- no orphaned relationships

Canonical seed data may be happy-path and integrity data. Do not describe it as fuzz, boundary, negative, or adversarial data unless it was intentionally built for that purpose.

### Dashboard Read Model Check

Dashboard read model checks verify the current dashboard or summary API.

Typical checks:

- endpoint returns the documented top-level shape
- metrics are present and derived from current seed/data rules
- expected grouping or summary items are present
- placeholders are present only when the current API intentionally returns them

Do not claim analytical drilldown, filtering, time-series, hierarchy expansion, or other future analytics coverage until those backend APIs exist.

## Run Modes

### Quick Check

Use Quick Check for small, low-risk changes.

Expected coverage:

- local unit tests for the affected backend/frontend area
- smoke reads for the main endpoint or screen when relevant
- docs checks when docs changed

Example:

```bash
make doc-check
make doc-guard
```

Add project-specific commands such as Go tests, npm tests, or smoke scripts when they exist.

### Feature Check

Use Feature Check when behavior, schema, seed data, API contracts, or frontend API consumers change.

Expected coverage:

- relevant unit or functional tests
- API contract checks for changed routes
- CRUD/relationship checks for changed entity behavior
- seed/data integrity checks when seed files or import logic change
- docs/runbook updates when testing expectations change

Feature Check should stay scoped to the feature. It should not become a full release rehearsal unless the change affects release-critical behavior.

### Pre-Merge Check

Use Pre-Merge Check before merging a practice-project feature PR.

Expected coverage:

- seed/data integrity validation
- project frontend test command, such as `npm test`, when available
- project backend test command, such as `go test ./...`, when available
- smoke checks for core read paths
- dashboard read model check when dashboard behavior exists or changed
- cleanup verification for temporary files, local-only output, and generated artifacts
- pass/fail summary in the PR

Pre-Merge Check is the broadest practice-project mode, but it is still not a load, concurrency, security, fuzz, or full E2E mandate unless the project explicitly requires those checks.

## Testing Impact Check

Every PR should decide whether testing docs or runbooks need to change when it touches:

- schema or data model rules
- DDD/API docs
- backend routes
- seed files or import behavior
- frontend API consumers
- test plans or runbooks

The PR should state one of:

- testing docs/runbook updated
- no testing update needed, with reason

This keeps Dogsquard's documentation discipline explicit without forcing every small change into a new testing artifact.

## PR Review Guidance

Reviewers should check:

- the selected run mode matches the risk of the change
- tests are named according to the behavior they protect
- seed data is described honestly as happy-path/integrity, fuzz, boundary, or negative data
- dashboard read model checks do not overstate unsupported analytics
- skipped testing updates include a short reason

Reject claims of coverage that rely on behavior the backend does not provide.

## Non-Goals

This runbook does not require:

- concurrency tests
- load tests
- fuzz tests
- security tests
- full analytical drilldown tests
- heavyweight QA phase gates
- production validation

Add those only when a project's scope, risk, or user-approved requirements make them necessary.
