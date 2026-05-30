---
title: "Dev Deployment Runbook"
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

# Dev Deployment Runbook

## Purpose

This runbook describes the intended development deployment workflow for Dogsquard.

Phase 6A does not implement deployment. It documents the expected future operating procedure for Phase 6B.

## Deployment Overview

Future dev deployment should run after changes are merged to `main`.

Expected high-level flow:

```text
merge to main
  -> GitHub Actions builds and tests
  -> GitHub Actions packages artifact
  -> GitHub Actions uploads artifact to dev host over SSH
  -> dev host unpacks timestamped release
  -> current symlink moves to new successful release
  -> health and smoke verification run
```

## Required GitHub Secrets

Suggested secrets:

```text
DEV_HOST
DEV_USER
DEV_SSH_KEY
```

Do not commit real secret values to the repository.

## Required GitHub Variables

Suggested variables:

```text
DEV_APP_NAME
DEV_DEPLOY_PATH
DEV_APP_URL
DEV_API_URL
```

Example placeholder values:

```text
DEV_APP_NAME=dogsquard
DEV_DEPLOY_PATH=/opt/dogsquard
DEV_APP_URL=https://example.invalid/dogsquard
DEV_API_URL=https://example.invalid/dogsquard/api
```

## Expected Server Directory Layout

Suggested layout:

```text
/opt/dogsquard/
  releases/
  current -> releases/<timestamp>
  shared/
  logs/
```

`releases/` stores immutable timestamped releases.

`current` points to the active release.

`shared/` stores runtime files that should survive release replacement.

`logs/` stores deployment and runtime logs.

## Expected Artifact Layout

The future artifact should include:

```text
artifact/
  backend/
  frontend/
  metadata/
```

Metadata should include the commit SHA and build timestamp.

The artifact must not include secrets.

## Expected Dev URL

The dev app should be reachable through the configured placeholder:

```text
DEV_APP_URL
```

The dev API should be reachable through:

```text
DEV_API_URL
```

Dogsquard should support HTTPS path-based exposure rather than assuming a root-domain app.

## Manual Preflight Checklist

Before implementing or enabling dev deployment:

- GitHub PR Quality Gate passes on `main`
- dev host exists and is reachable by the owner
- target deploy path is chosen
- GitHub secrets are added
- GitHub variables are added
- domain and SSL routing are prepared
- rollback directory layout is understood
- production environment is not targeted

## us.hermes Multica Warning

`us.hermes` already serves multica through:

```text
https://proletariat.icu
https://www.proletariat.icu
```

Existing routes:

```text
/      -> multica frontend Docker service
/api   -> multica backend Docker service
```

Before any Dogsquard deploy implementation:

- run server preflight first
- do not overwrite root routing
- do not overwrite `/api`
- do not restart services during discovery
- do not edit reverse proxy or SSL config during discovery
- do not stop or restart multica containers

## Future GitHub Actions Flow

The Phase 6B workflow should:

- trigger from `main` after merge
- run quality checks before deploying
- build backend
- build frontend
- package artifact
- upload artifact over SSH
- activate release only after upload and unpack succeed
- run health verification
- run smoke verification
- report failure without replacing a working release

## Health Verification

Health verification should check:

```text
GET /healthz
```

Expected result:

```json
{"status":"ok"}
```

## Smoke Verification

Smoke verification should include:

- API task list request
- frontend load check
- minimal browser smoke when configured against `DEV_APP_URL`

Full regression is not required for the first dev deployment implementation.

## Rollback Concept

Rollback should switch:

```text
current -> releases/<previous-successful-release>
```

The rollback should not require rebuilding the artifact.

## Troubleshooting Checklist

Check:

- GitHub secret names
- GitHub variable names
- SSH connectivity
- artifact upload path
- release directory permissions
- `current` symlink target
- backend health response
- frontend base URL configuration
- reverse proxy or HTTPS path routing
- deployment and runtime logs

## Phase 6A Boundary

Phase 6A does not add:

- deployment workflow
- deployment script
- Docker
- Docker Compose
- server configuration
- production deployment
- self-hosted runner
- database setup
- auth setup
