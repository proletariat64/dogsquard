---
title: "Dev Deployment Test Plan"
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

# Dev Deployment Test Plan

## Objective

Define how Dogsquard should verify development deployments when Phase 6B implements the SSH artifact deployment path.

Phase 6A documents the test plan only.

## Pre-Deploy Checks

Before deployment starts, the future workflow should verify:

- PR Quality Gate has passed before merge
- build dependencies install successfully
- backend tests pass
- frontend build passes
- minimal Playwright smoke remains healthy before deployment
- required GitHub secrets are present
- required GitHub variables are present
- production deployment is not targeted

## Deployment Verification Checks

After artifact upload, verify:

- artifact exists on the dev host
- artifact unpacks into a timestamped release directory
- release metadata includes commit SHA
- `current` symlink points to the new release only after successful activation
- previous release remains available

## Health Check

Verify:

```text
GET /healthz
```

Expected result:

```json
{"status":"ok"}
```

## API Smoke Check

Run a dev-environment equivalent of the local API smoke:

- `GET /api/tasks`
- create valid task
- reject missing-title task
- update task status
- delete task

Use the configured `DEV_API_URL`.

## Frontend Smoke Check

Run minimal browser smoke against `DEV_APP_URL`:

- app loads
- empty state is visible
- valid task can be created through UI
- missing-title validation is visible

Do not expand to full Playwright regression in Phase 6B unless explicitly approved.

## Rollback Verification

Rollback should verify:

- previous release directory still exists
- `current` symlink can be switched back
- health check passes after rollback
- smoke check passes after rollback or failure is clearly reported

## Failure Cases

The future implementation should cover:

- build failure blocks deployment
- test failure blocks deployment
- missing secret blocks deployment
- SSH failure blocks deployment
- artifact upload failure blocks activation
- health check failure does not replace current release
- smoke failure does not replace current release
- rollback failure is reported clearly

## Future CI/CD Checks

Later phases may add:

- deployment smoke in GitHub Actions
- release artifact checks
- production release gate
- full Playwright regression
- self-hosted runner UAT
- Docker or Docker Compose checks if a future ADR approves them

## Acceptance Criteria For Phase 6B Implementation

- deployment workflow runs only after merge to `main`
- workflow builds, tests, packages, and uploads a dev artifact
- dev host receives timestamped release directory
- `current` symlink changes only after successful activation
- health verification runs
- API smoke verification runs
- frontend smoke verification runs
- failed deployment preserves previous release
- rollback path is documented and testable
- production deployment is not triggered
