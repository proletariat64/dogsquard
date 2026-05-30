---
title: "Dev Deployment PRD"
doc_type: "prd"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Dev Deployment PRD

## Purpose

Define the development deployment requirements for Dogsquard before implementation.

Phase 6A chooses the dev deployment strategy only. It does not add a deployment workflow, server configuration, Docker, production deployment, or self-hosted runner.

## Target User

The target user is the repository owner validating that Dogsquard can deploy a small internal full-stack app to a real development cloud host through GitHub-controlled delivery.

Secondary users are future agents that will implement, debug, and document deployment phases under human review.

## Deployment Goals

- deploy the current `main` branch to a development environment after merge
- keep GitHub Actions as the CI/CD controller
- keep the cloud host as a deployment target, not the primary CI authority
- package build output into a predictable artifact
- upload artifacts to the dev cloud host over SSH
- activate releases through a `current` symlink
- support fast rollback to the previous release
- run post-deploy health and smoke verification
- keep secrets in GitHub secrets, not in the repository

## Non-Goals

- do not deploy production in Phase 6A
- do not add a deployment workflow in Phase 6A
- do not add Docker or Docker Compose in Phase 6A
- do not modify server configuration in Phase 6A
- do not add a self-hosted runner in Phase 6A
- do not add database or authentication setup
- do not hardcode real hostnames, usernames, keys, or secrets

## Dev Environment Definition

The dev environment is a cloud-hosted runtime used to verify merged Dogsquard changes before any future production release path exists.

It should be treated as disposable enough for iteration but stable enough to catch deployment, runtime, URL, health, and smoke-test issues.

Suggested placeholder identity:

```text
DEV_APP_NAME=dogsquard
DEV_APP_URL=https://example.invalid/dogsquard
DEV_API_URL=https://example.invalid/dogsquard/api
```

## GitHub Actions Role

GitHub Actions should:

- run PR Quality Gate before merge
- build and test from `main` in a future deployment workflow
- package backend and frontend artifacts
- connect to the dev host using GitHub secrets
- upload the artifact
- switch the dev release atomically when verification passes
- report deployment success or failure in the workflow run

GitHub Actions remains the deterministic CI/CD authority.

## Cloud Host Role

The cloud host should:

- receive release artifacts
- store timestamped release directories
- expose the dev service through the configured HTTPS path
- keep shared runtime data outside release directories when needed
- retain logs for troubleshooting
- retain previous releases for rollback

The cloud host should not become the default CI runner in Phase 6A.

## Artifact Strategy

The future deployment workflow should produce a versioned or timestamped artifact that contains:

- backend executable or backend runtime bundle
- built frontend static assets
- deployment metadata such as commit SHA and build timestamp
- runtime start or restart instructions in a later implementation phase

The artifact should not contain secrets.

## Environment Variable Strategy

Use placeholder environment variables in documentation and GitHub configuration:

```text
DEV_APP_NAME
DEV_DEPLOY_PATH
DEV_APP_URL
DEV_API_URL
```

Runtime environment values should be configured on the dev host or through GitHub environment variables, depending on the final implementation design.

## Secrets Strategy

Use GitHub secrets for sensitive values:

```text
DEV_HOST
DEV_USER
DEV_SSH_KEY
```

Do not commit real secrets, private keys, tokens, server IP addresses, or production credentials.

## URL And Path Strategy

Dogsquard services may be exposed through HTTPS paths such as:

```text
https://example.invalid/dogsquard
```

The dev deployment should support a configured base URL and API URL rather than assuming root-domain deployment.

The frontend build should be able to target the configured dev API URL.

## Health Check Expectations

The deployed backend should expose:

```text
GET /healthz
```

The dev deployment should verify that the health response is successful and returns JSON with status `ok`.

## Smoke Verification Expectations

Post-deploy smoke should verify:

- health endpoint responds
- API task list responds
- frontend loads from `DEV_APP_URL`
- minimal browser smoke can run against the dev URL when configured

Full regression is not required for the first dev deployment implementation.

## Rollback Expectations

Rollback should switch `current` to the previous successful release and restart or reload the dev service.

Failed deployments must not replace the currently active release.

## Logging Expectations

The dev host should keep deploy and runtime logs in a predictable shared directory.

Suggested placeholder:

```text
/opt/dogsquard/shared/logs/
```

Logs should help diagnose upload, unpack, service start, health, and smoke verification failures.

## Security Constraints

- use least-privilege SSH credentials
- store SSH keys only in GitHub secrets
- avoid exposing secrets in logs
- avoid production credentials in the dev workflow
- do not allow agents to approve production release
- keep self-hosted runner decisions for a later phase

## Future Production Separation

Production deployment must remain separate from dev deployment.

Future production deployment should require explicit approval, a dedicated environment, and release-oriented verification.

Dev deployment must not deploy production.

## Acceptance Criteria

- dev deployment strategy is documented
- SSH artifact deploy direction is recorded in an ADR
- required secrets and variables are named with placeholders only
- URL/path, health, smoke, rollback, logging, and security expectations are defined
- Phase 6B implementation scope is clear
- no deployment workflow, Docker, server configuration, database, auth, production deploy, or self-hosted runner is added in Phase 6A
