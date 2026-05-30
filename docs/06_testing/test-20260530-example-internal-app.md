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

Phase 5B implements backend tests for validation, in-memory storage behavior, and handler behavior.

Phase 5C extends backend coverage for response consistency and hardening.

Backend tests should cover:

- required title validation
- allowed priority values
- allowed status values
- default status on create
- id generation
- created and updated timestamps
- in-memory create/list/update/delete behavior
- invalid JSON handling
- consistent JSON error envelopes
- JSON content type for JSON responses
- unsupported method handling

## API Behavior Tests

Phase 5B implements API behavior tests for the current standard-library HTTP skeleton.

Phase 5C introduces `scripts/smoke-api.sh` for deterministic local API smoke testing against a running backend.

API tests should cover:

- `GET /healthz`
- `GET /api/tasks`
- `POST /api/tasks`
- `PATCH /api/tasks/{id}`
- `DELETE /api/tasks/{id}`
- JSON error response for invalid input
- missing task behavior for update and delete

The API smoke script covers:

- health check
- empty task list success
- valid task creation
- invalid task creation without title
- task status update
- task deletion

The smoke script intentionally does not start the backend. Start the backend first, then run `make smoke-api`.

## Frontend Checks

Phase 5B adds a lightweight Vite TypeScript frontend skeleton and validates it with `npm run build`.

Frontend checks should cover:

- empty dashboard state
- form rendering
- client-visible validation message
- successful task creation display
- status update display
- deleted task removal from table

These checks use the frontend tooling selected in Phase 5B. Dedicated frontend tests may be added later.

## Playwright Smoke Tests Later

Playwright smoke tests are planned for a later phase.

Initial smoke candidates:

- app loads
- create task through UI
- task appears in table
- update status
- delete task

Do not add Playwright in Phase 5B or Phase 5C.

## Release-Check Expectations

`make release-check` should remain the local pre-PR command.

Expected behavior after implementation:

- documentation checks pass
- Go tests run when backend Go files exist
- frontend tests run when frontend tooling exists
- frontend build runs when the frontend package exists
- API smoke testing remains separate because it requires a running backend server

## Local Validation Commands

Run:

```bash
make doc-check
make doc-guard
make release-check
git diff --check
bash -n scripts/*.sh
cd backend && go test ./...
cd frontend && npm install
cd frontend && npm run build
```

To run API smoke locally:

```bash
cd backend && go run ./cmd/server
make smoke-api
```

If port `8080` is already in use:

```bash
cd backend && HTTP_ADDR=127.0.0.1:18080 go run ./cmd/server
API_BASE_URL=http://127.0.0.1:18080 make smoke-api
```

## PR Validation Expectations

The PR Quality Gate should run on pull requests and pass before merge.

Future implementation PRs should include:

- linked issue
- updated docs when behavior changes
- test evidence
- no secrets
- no deployment unless explicitly in scope

## Out-of-Scope Tests For Phase 5C

Phase 5C should not require:

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
