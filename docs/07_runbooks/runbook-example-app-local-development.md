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

This runbook describes the expected future local workflow for the Internal Task Intake example app.

It is preparatory until Phase 5B implementation exists.

## Expected Future Local Workflow

Expected workflow after implementation:

1. Review PRD, BDD, ADR, and test plan.
2. Run local documentation checks.
3. Start backend API.
4. Start frontend dev server.
5. Exercise create/list/update/delete behavior.
6. Run tests.
7. Run `make release-check`.
8. Open a PR and let PR Quality Gate validate the branch.

## Expected Backend Command

The backend command will be finalized in Phase 5B.

Expected shape:

```bash
cd backend
go run ./...
```

If the implementation chooses a more specific command, update this runbook in the same PR.

## Expected Frontend Command

The frontend command will be finalized in Phase 5B.

Expected shape:

```bash
cd frontend
npm run dev
```

Do not hardcode frontend tooling before it is introduced.

## Expected Test Command

Expected local test command:

```bash
make test
```

Expected backend direct command after Go code exists:

```bash
cd backend
go test ./...
```

Frontend test commands depend on the selected frontend tooling and should be documented when introduced.

## Expected Release-Check Behavior

`make release-check` should:

- run documentation checks
- run backend lint and tests when Go files exist
- run frontend lint and tests when `frontend/package.json` exists and scripts are available
- pass in the early template state when app code is absent

## Known Pending Items

- Backend folder does not exist yet.
- Frontend folder does not exist yet.
- API routes are not implemented yet.
- Frontend tooling is not selected yet.
- Playwright is planned later.
- Deployment is planned later.

## Phase 5B Note

Phase 5B should update this runbook when it adds actual backend and frontend commands.

Until then, this file is a planning document and must not be treated as proof that the app already exists.
