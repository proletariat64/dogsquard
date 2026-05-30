---
title: "Use Small Internal Task Intake as Example App"
doc_type: "adr"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# ADR 0002: Use Small Internal Task Intake as Example App

## Status

Draft

## Context

Dogsquard needs a small example application to prove that its documentation, local commands, issue templates, PR checks, and future delivery flow work on a realistic internal app.

The example should represent the common target project shape:

- Go backend
- JS/TS frontend
- form input
- dashboard table
- CRUD workflow
- validation
- tests
- GitHub-based delivery

The example must remain a bootstrap-kit proof, not a production product.

## Decision

Use a small Internal Task Intake app as the Dogsquard example application.

The app will manage task intake records with:

- id
- title
- description
- priority
- status
- created_at
- updated_at

The first implementation should use a Go HTTP API, a simple JS/TS frontend, and in-memory storage.

## Consequences

Positive consequences:

- Exercises realistic full-stack paths without large scope.
- Gives agents concrete requirements and behavior scenarios.
- Keeps TDD practical.
- Provides a future place for Playwright smoke coverage.
- Avoids premature database, auth, and deployment decisions.

Tradeoffs:

- In-memory storage does not prove persistence.
- No auth means it does not prove permission behavior.
- The app is intentionally small and not a complete internal operations system.

## Alternatives Considered

### Generic todo app

Rejected because it is too generic and does not express the internal-app intent as clearly.

### Inventory or CRM mini-app

Rejected for the first example because those domains invite more fields, workflows, and product assumptions.

### Pure backend example

Rejected because Dogsquard targets internal full-stack apps and needs to prove frontend and backend workflow together.

### Pure frontend example

Rejected because Dogsquard targets Go backend services and API validation as part of the standard stack.

## Why The App Should Be Small

The example exists to test Dogsquard governance and workflow.

Small scope makes it easier to:

- review agent output
- write tests first
- keep PRs focused
- avoid product direction drift
- preserve one-person maintenance

## Why No Database Initially

No database is used initially because persistence would add setup, migration, configuration, and deployment concerns before the bootstrap workflow is proven.

In-memory storage is enough to validate routing, validation, JSON responses, state changes, and local tests.

## Why No Auth Initially

No auth is used initially because authentication adds product and security decisions that are not needed to prove the basic Dogsquard lifecycle.

Auth may be introduced later if Dogsquard needs to prove permission or session workflows.

## Why Playwright Is Later, Not Phase 5A

Phase 5A is documentation-only.

Playwright should be added after the example backend and frontend skeleton exists, so smoke tests can target real behavior instead of speculative UI.

## Support For Dogsquard Bootstrap Kit

The Internal Task Intake app supports Dogsquard by providing a compact, repeatable proving ground for:

- PRD-driven implementation
- BDD acceptance scenarios
- ADR-backed architecture choices
- TDD-friendly backend and frontend work
- local `release-check`
- PR Quality Gate behavior
- future Playwright and deployment phases
