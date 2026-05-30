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

Use an alternate port if another local service already uses `8080`:

```bash
cd backend
HTTP_ADDR=127.0.0.1:18080 go run ./cmd/server
```

## Frontend Commands

```bash
cd frontend
npm install
npm run build
npm run dev
```

The frontend dev server expects the backend API at `http://127.0.0.1:8080` by default.

Override the frontend API base URL when the backend uses another port:

```bash
cd frontend
VITE_API_BASE_URL=http://127.0.0.1:18080 npm run dev
```

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

No dedicated frontend unit test script is included in Phase 5D.

API smoke command:

```bash
make smoke-api
```

The smoke command expects a running backend at `http://127.0.0.1:8080` by default. Override with `API_BASE_URL` when needed:

```bash
API_BASE_URL=http://127.0.0.1:18080 make smoke-api
```

Playwright e2e smoke command:

```bash
make e2e-smoke
```

The e2e smoke runner:

- starts the backend on `127.0.0.1:18080` by default
- builds the frontend with `VITE_API_BASE_URL=http://127.0.0.1:18080`
- starts Vite preview on `127.0.0.1:4173` by default
- runs the `@smoke` Playwright test
- cleans up local backend and frontend processes on exit

Override ports when needed:

```bash
API_PORT=18081 WEB_PORT=4174 make e2e-smoke
```

If local Playwright browser installation is unavailable on the workstation, set `CHROMIUM_EXECUTABLE_PATH` to a system Chromium path:

```bash
CHROMIUM_EXECUTABLE_PATH=/snap/bin/chromium make e2e-smoke
```

## Three-Terminal Smoke Workflow

Terminal 1:

```bash
cd backend
go run ./cmd/server
```

Terminal 2:

```bash
make smoke-api
```

Terminal 3:

```bash
cd frontend
npm install
npm run dev
```

## One-Command E2E Smoke Workflow

```bash
make e2e-smoke
```

This is the preferred Phase 5D smoke command.

## Expected Release-Check Behavior

`make release-check` should:

- run documentation checks
- run backend lint and tests when Go files exist
- run frontend lint and tests when scripts are available
- run frontend build when `frontend/package.json` exists
- pass with the Phase 5D skeleton and smoke setup

`make release-check` does not run `make smoke-api` or `make e2e-smoke` because smoke testing starts local server processes.

## Known Pending Items

- Persistent storage is not implemented.
- Authentication is not implemented.
- Full Playwright regression is planned later.
- Deployment is planned later.

## Root Commands

```bash
make test
make lint
make backend-test
make frontend-build
make smoke-api
make e2e-smoke
make release-check
make backend-dev
make frontend-dev
```
