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

Phase 6B-1 validates local packaging and opt-in manual deploy scripts. It does not validate public routing or production deployment.

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

For Phase 6B-1 local validation, run:

```bash
make package-release
make deploy-dev-dry-run HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev
```

Use `us.hermes` dry-run only after confirming the deploy root is isolated from multica:

```bash
make deploy-dev-dry-run HOST=us.hermes DEPLOY_ROOT=~/apps/dogsquard-dev
```

Actual deploy is optional for PR acceptance and requires explicit `DRY_RUN=false`.

## Package Release Validation

Verify `make package-release`:

- builds the backend binary
- builds frontend static assets
- writes a `.tar.gz` artifact under `dist/`
- includes `release/manifest.txt`
- includes `release/backend/dogsquard-server`
- includes `release/frontend/dist/`
- excludes `.git`
- excludes `node_modules`
- excludes `.env.local`
- excludes secrets

Artifact contents can be inspected locally:

```bash
tar -tzf dist/dogsquard-*.tar.gz
```

## Remote Deploy Dry-Run Validation

Verify `make deploy-dev-dry-run`:

- requires `HOST`
- packages a release if `ARTIFACT` is not provided
- uploads the artifact to the remote artifact path
- runs the remote deploy script in `DRY_RUN=true`
- prints planned release directory operations
- does not create release directories
- does not extract the artifact
- does not update `current`
- does not edit reverse proxy config
- does not restart services
- does not run Docker commands

## Actual Manual Deploy Validation

If the user explicitly approves manual deploy with `DRY_RUN=false`, verify:

- artifact exists on the remote host
- deploy root exists or is created in the selected writable path
- release directory is created under `releases/`
- artifact extracts into the release directory
- `current` points to the new release
- previous releases remain available
- no reverse proxy config changed
- no multica services changed

## Deployment Verification Checks

After artifact upload, verify:

- artifact exists on the dev host
- artifact unpacks into a timestamped release directory
- release metadata includes commit SHA
- `current` symlink points to the new release only after successful activation
- previous release remains available

For Phase 6B-1, these checks apply only when `DRY_RUN=false` is explicitly used.

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

Phase 6B-1 script failure cases:

- missing `HOST` blocks local deploy wrapper
- missing artifact blocks remote deploy
- invalid `DRY_RUN` value blocks deploy
- unwritable deploy root fails without `sudo`
- existing release directory blocks overwrite

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

## Acceptance Criteria For Phase 6B-1

- `make package-release` creates a local artifact
- artifact contains backend binary and frontend static assets
- artifact manifest documents commit SHA and build time
- deploy wrapper defaults to dry-run
- remote deploy script defaults to dry-run
- dry-run does not create directories, extract artifacts, or update symlinks
- actual deploy requires explicit `DRY_RUN=false`
- scripts do not edit reverse proxy config
- scripts do not restart nginx, Caddy, Traefik, multica, or Docker services
- scripts do not require `sudo`
- no public route is configured
