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

## Phase 6B-2 Validation Results

Phase 6B-2 was validated from local `main` after Phase 6B-1 was merged.

Validated successfully:

- `make package-release`
- `make deploy-dev-dry-run HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- `make deploy-dev HOST=cn.ant DRY_RUN=false DEPLOY_ROOT=~/apps/dogsquard-dev`
- `ssh cn.ant` post-deploy layout checks
- `make deploy-dev-dry-run HOST=us.hermes DEPLOY_ROOT=~/apps/dogsquard-dev`

Sanitized `cn.ant` result:

- release artifact uploaded to the remote temporary artifact path
- isolated deploy root created under the user's home directory
- `releases/`, `shared/`, and `logs/` directories exist
- `current` points to a timestamped release under `releases/`
- no reverse proxy integration was configured
- no public URL was exposed

Sanitized `us.hermes` result:

- dry-run plan completed
- no real deploy activation was performed
- multica routing remains protected

No raw server config, secrets, SSH config, or full command output is committed.

## Phase 6B-3 Runtime Validation Results

Phase 6B-3 validated user-level runtime management on `cn.ant`.

Validated successfully:

- `make deploy-dev HOST=cn.ant DRY_RUN=false DEPLOY_ROOT=~/apps/dogsquard-dev`
- `make runtime-start HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- `make runtime-status HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- `make runtime-health HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- `make runtime-stop HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- stopped status after runtime stop
- `make runtime-start HOST=us.hermes DEPLOY_ROOT=~/apps/dogsquard-dev` is blocked by default

Sanitized `cn.ant` result:

- backend ran on `127.0.0.1:18080`
- frontend static server ran on `127.0.0.1:14173`
- pid files were managed under `shared/run/`
- logs were written under `logs/`
- health checks passed before stop
- both processes were stopped after validation

Issue found and fixed:

- first runtime attempt exposed a glibc mismatch for the Go backend binary
- `scripts/package-release.sh` now builds the backend with `CGO_ENABLED=0`
- the statically linked backend artifact validated on `cn.ant`

No public URL was exposed, no reverse proxy was changed, and no system-wide service was added.

## Phase 6B-4 Runtime Hardening Validation Results

Phase 6B-4 validated runtime hardening on `cn.ant`.

Validated successfully:

- `make deploy-dev HOST=cn.ant DRY_RUN=false DEPLOY_ROOT=~/apps/dogsquard-dev`
- `make runtime-start HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- idempotent second `runtime-start`
- `make runtime-status HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- `make runtime-health HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- `make runtime-logs HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- `make runtime-diagnose HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- `make runtime-restart HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- health after restart
- `make runtime-stop HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- stopped status after stop
- stale backend pid file reporting and cleanup
- unknown frontend port occupant diagnostic
- explicit rollback to a previous release
- explicit rollback back to the latest release
- `make runtime-start HOST=us.hermes DEPLOY_ROOT=~/apps/dogsquard-dev` is blocked by default

Sanitized result:

- runtime remained localhost-only
- logs and diagnose did not require `sudo`
- runtime scripts managed only Dogsquard pid-file processes
- rollback changed only the `current` symlink under the isolated deploy root
- no reverse proxy config was changed
- no public URL was exposed

An intermittent SSH connection close was observed during one transfer/log command and succeeded on retry. No script change was needed for that network-level event.

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

Phase 6B-3 runtime failure cases:

- missing `current` symlink blocks start
- missing backend binary blocks start
- missing frontend dist blocks start
- backend port occupied causes backend health failure
- frontend port occupied causes frontend start or health failure
- stale pid file is reported and removed during start or stop
- missing `python3` blocks frontend static serving
- missing `curl` blocks health checks

Phase 6B-4 runtime hardening cases:

- stale pid file is reported by `status`
- stale pid file is removed by `start`
- second `start` is idempotent when Dogsquard owns the pid and port
- unknown process on configured port blocks `start`
- `logs` prints recent backend and frontend log lines
- `diagnose` prints release, pid, port, log, and health context
- rollback requires explicit `TARGET_RELEASE`
- `us.hermes` start, restart, and rollback are blocked by default

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

## Acceptance Criteria For Phase 6B-2

- release packaging is validated from `main`
- `cn.ant` dry-run deploy succeeds
- `cn.ant` real isolated deploy succeeds under `~/apps/dogsquard-dev`
- `cn.ant` `current` symlink points to a release under `releases/`
- `us.hermes` deploy validation remains dry-run only
- no reverse proxy config is modified
- no service is restarted
- no Docker state is modified
- no public route is exposed

## Acceptance Criteria For Phase 6B-3

- runtime start succeeds on `cn.ant`
- runtime status reports backend and frontend running
- runtime health passes for backend and frontend localhost endpoints
- runtime stop stops only Dogsquard pid-file processes
- stopped status reports backend and frontend stopped
- `us.hermes` runtime start is blocked by default
- no reverse proxy config is modified
- no service is restarted
- no Docker state is modified
- no public route is exposed

## Acceptance Criteria For Phase 6B-4

- stale pid handling is clear and non-destructive
- unknown occupied port blocks runtime start with diagnostics
- idempotent start does not create duplicate Dogsquard processes
- logs action works for runtime logs
- diagnose action reports runtime state without secrets
- restart works and health passes afterward
- rollback helper switches only the isolated `current` symlink
- `us.hermes` runtime start remains blocked by default
- no reverse proxy config is modified
- no service is restarted
- no Docker state is modified
- no public route is exposed
