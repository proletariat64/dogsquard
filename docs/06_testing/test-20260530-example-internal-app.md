---
title: "Example Internal App Test Plan"
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

# Example Internal App Test Plan

## Test Strategy

The example app should be implemented with tests before or alongside behavior changes.

The first implementation pass should keep the app small enough that tests are easy to read, fast to run, and useful as a Dogsquard template proof.

## TDD Order

Recommended order:

1. Backend validation tests.
2. Backend in-memory storage tests.
3. API behavior tests for health and task CRUD.
4. Frontend form and table checks when frontend tooling exists.
5. Local `make release-check`.
6. PR Quality Gate.

## Backend Unit Tests

Backend tests should cover:

- required title validation
- allowed priority values
- allowed status values
- default status on create
- id generation
- created and updated timestamps
- in-memory create/list/update/delete behavior

## API Behavior Tests

API tests should cover:

- `GET /health`
- `GET /api/tasks`
- `POST /api/tasks`
- `PATCH /api/tasks/{id}`
- `DELETE /api/tasks/{id}`
- JSON error response for invalid input
- missing task behavior for update and delete

## Frontend Checks

Frontend checks should cover:

- empty dashboard state
- form rendering
- client-visible validation message
- successful task creation display
- status update display
- deleted task removal from table

These checks should use the frontend tooling selected in the implementation phase. Phase 5A does not choose or install tooling.

## Playwright Smoke Tests Later

Playwright smoke tests are planned for a later phase.

Initial smoke candidates:

- app loads
- create task through UI
- task appears in table
- update status
- delete task

Do not add Playwright in Phase 5A.

## Release-Check Expectations

`make release-check` should remain the local pre-PR command.

Expected behavior after implementation:

- documentation checks pass
- Go tests run when backend Go files exist
- frontend tests run when frontend tooling exists
- missing frontend tooling should not break unrelated backend-only progress unless the implementation phase requires it

## Local Validation Commands

Run:

```bash
make doc-check
make doc-guard
make release-check
git diff --check
bash -n scripts/*.sh
```

## PR Validation Expectations

The PR Quality Gate should run on pull requests and pass before merge.

Future implementation PRs should include:

- linked issue
- updated docs when behavior changes
- test evidence
- no secrets
- no deployment unless explicitly in scope

## Out-of-Scope Tests For Phase 5B

Phase 5B should not require:

- production deployment tests
- self-hosted runner checks
- full Playwright regression
- database integration tests
- authentication tests
- load tests

## Future CI Expansion Notes

Later phases may add:

- explicit Go setup
- explicit frontend setup
- Playwright smoke checks
- artifact or coverage reporting
- deployment verification
