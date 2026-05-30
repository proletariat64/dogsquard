---
title: "Example App Local Development Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Example App Local Development Runbook

## Purpose

This runbook describes the local workflow for the Internal Task Intake example app.

## Expected Future Local Workflow

Expected workflow:

1. Review PRD, BDD, ADR, and test plan.
2. Run local documentation checks.
3. Start backend API.
4. Start frontend dev server.
5. Exercise create/list/update/delete behavior.
6. Run tests.
7. Run `make release-check`.
8. Open a PR and let PR Quality Gate validate the branch.

## Backend Commands

```bash
cd backend
go test ./...
go run ./cmd/server
```

The backend listens on `127.0.0.1:8080` unless `HTTP_ADDR` is set.

## Frontend Commands

```bash
cd frontend
npm install
npm run build
npm run dev
```

The frontend dev server expects the backend API at `http://127.0.0.1:8080` by default.

## Test Commands

Expected local test command:

```bash
make test
```

Expected backend direct command after Go code exists:

```bash
cd backend
go test ./...
```

Frontend build command:

```bash
cd frontend
npm run build
```

No dedicated frontend test script is included in Phase 5B.

## Expected Release-Check Behavior

`make release-check` should:

- run documentation checks
- run backend lint and tests when Go files exist
- run frontend lint and tests when scripts are available
- pass with the Phase 5B skeleton

## Known Pending Items

- Persistent storage is not implemented.
- Authentication is not implemented.
- Playwright is planned later.
- Deployment is planned later.

## Root Commands

```bash
make test
make lint
make release-check
make backend-dev
make frontend-dev
```
