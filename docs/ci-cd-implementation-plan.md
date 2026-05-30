# CI/CD Implementation Plan

## Goal

Build a practical GitHub-based CI/CD system for `dogsquard` that supports solo development, keeps documentation rules in order, and separates fast local feedback from official merge and deployment gates.

The target operating model is:

```text
Local workstation = fast TDD, doc watcher, optional coding agent
GitHub Actions = official quality gate and deployment controller
Cloud dev host = real development deployment target
Cloud production host = stable production runtime with approval
Optional self-hosted runner = heavy UAT, private-network, or multica integration work
```

## Key Decisions

### 1. Use GitHub Actions as the CI/CD authority

GitHub Actions should be the official source of truth for:

- PR quality checks
- linting
- unit tests
- documentation checks
- build checks
- Playwright smoke tests
- dev deployment
- production deployment approval flow

Local agents and CLI tools can help, but they should not replace deterministic CI checks.

### 2. Use local watcher as advisory support

A local watcher should run on the Ubuntu workstation and warn early when documentation rules are violated.

It should check:

- code changed but docs did not change
- `CHANGELOG.md` missing or not updated
- missing required documentation folders
- bad ADR filename format
- missing PRD / BDD / testing notes for meaningful product changes

Local watcher result is advisory. GitHub Actions remains the official gate.

### 3. Use Claude Code CLI or other coding agents only as optional helpers

Agent CLI usage is allowed for:

- reviewing local git diff
- suggesting documentation updates
- drafting PRD / BDD / ADR content
- explaining failed CI logs
- generating PR summaries
- helping with Playwright scripts

Agent CLI should not be required for merge. It should not be allowed to silently bypass CI, auto-deploy production, or invent documentation just to satisfy a rule.

Important rule:

```text
Do not hardcode unverified model names, CLI commands, config schemas, or versions.
Use wrapper scripts and verify the actual installed CLI behavior before enabling automation.
```

### 4. Start with GitHub-hosted runners

Use GitHub-hosted runners first for:

- PR lint
- Go tests
- frontend tests
- build checks
- documentation gate
- Playwright smoke tests
- release packaging

Add a self-hosted runner later only if needed for:

- heavy Playwright UAT
- private network checks
- access to the real `multica` container
- Docker cache / faster integration tests
- server-local deployment verification

### 5. Use cloud hosts as deployment targets

Do not use the production host as the main CI runner at the beginning.

Recommended split:

```text
GitHub-hosted runner:
  - build
  - test
  - package
  - SSH deploy

Cloud dev host:
  - dev runtime
  - Docker Compose
  - SSL/domain verification

Cloud production host:
  - production runtime
  - manual approval required
  - tag or workflow_dispatch based deploy
```

### 6. Use Docker for runtime parity, native commands for TDD speed

Local development should support both native and Docker workflows.

Native local commands:

```bash
go test ./...
npm test
npm run dev
```

Docker workflow:

```bash
docker compose up -d --build
```

Recommended rule:

```text
TDD speed = native local
Deployment confidence = Docker / Docker Compose
```

### 7. Do not run full E2E on every PR initially

Recommended testing policy:

```text
Every PR:
  - lint
  - unit tests
  - typecheck
  - build
  - documentation gate
  - Playwright smoke tests only

Merge to main:
  - deploy to dev
  - post-deploy smoke verification

Before production release:
  - full Playwright regression
  - manual approval
  - tag vX.Y.Z or workflow_dispatch

Epic branch:
  - manual UAT deploy
  - larger Playwright suite
```

This keeps normal development fast while preserving release confidence.

## Target Repository Structure

```text
.
├── .github/
│   ├── workflows/
│   │   ├── pr-quality.yml
│   │   ├── doc-check.yml
│   │   └── deploy.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── feature.yml
│   │   └── bug.yml
│   └── pull_request_template.md
├── docs/
│   ├── adr/
│   ├── prd/
│   ├── bdd/
│   ├── runbooks/
│   └── testing/
├── scripts/
│   ├── doc-check-local.sh
│   ├── watch-docs.sh
│   ├── e2e-ci.sh
│   ├── remote-deploy.sh
│   └── agent-doc-review.sh
├── backend/
├── frontend/
├── Makefile
├── CHANGELOG.md
└── .env.example
```

## Implementation Phases

## Phase 1: Local Foundation

### Objective

Make local development and documentation rules repeatable before adding complex GitHub Actions.

### Files to add

```text
Makefile
scripts/doc-check-local.sh
scripts/watch-docs.sh
scripts/agent-doc-review.sh
.env.example
CHANGELOG.md
docs/adr/
docs/prd/
docs/bdd/
docs/runbooks/
docs/testing/
```

### Required local commands

```bash
make test
make lint
make release-check
make watch-docs
make agent-docs
```

### Acceptance criteria

- `make release-check` works locally.
- documentation folders exist.
- doc check fails when code changes but docs do not.
- doc check can explain what is missing.
- agent wrapper exists but does not assume a specific model name or CLI schema.

## Phase 2: PR Quality Gate

### Objective

Every pull request must pass deterministic quality checks before merge.

### Workflow file

```text
.github/workflows/pr-quality.yml
```

### Required checks

- Go lint
- Go unit tests
- frontend lint
- frontend typecheck
- frontend tests
- build checks
- documentation gate
- Playwright smoke E2E for normal PRs

### Labels

```text
feat       normal feature
bug        bug fix
epic       large feature; skip normal PR E2E and use manual UAT
hotfix     urgent fix; may skip heavy E2E but not unit tests
skip-docs  allow documentation gate bypass with justification
```

### Acceptance criteria

- PR cannot merge if deterministic checks fail.
- `epic` label does not run full PR E2E.
- `hotfix` label still keeps unit tests and documentation discipline.
- `skip-docs` is explicit and visible.

## Phase 3: Documentation Gate

### Objective

Make documentation consistency part of the development lifecycle.

### Workflow file

```text
.github/workflows/doc-check.yml
```

### Rules

When product or source code changes, at least one relevant documentation path should change:

```text
README.md
CHANGELOG.md
docs/prd/
docs/bdd/
docs/adr/
docs/runbooks/
docs/testing/
```

Bypass rule:

```text
skip-docs label is allowed, but should require PR explanation.
```

### Acceptance criteria

- PR fails when meaningful code changes do not update docs.
- `CHANGELOG.md` format is checked.
- ADR filename format is checked.
- local and GitHub checks share the same core logic where possible.

## Phase 4: Development Deployment

### Objective

After merge to `main`, deploy automatically to the development cloud host.

### Workflow file

```text
.github/workflows/deploy.yml
```

### Trigger

```text
push to main
```

### Deployment behavior

```text
main merge
  -> build release artifact
  -> upload artifact
  -> SSH to dev host
  -> unpack into release directory
  -> update current symlink
  -> docker compose up -d --build
  -> run smoke verification
```

### Required secrets

```text
DEV_HOST
DEV_USER
DEV_SSH_KEY
DEV_DEPLOY_PATH
```

### Acceptance criteria

- merge to `main` deploys to dev automatically.
- failed dev deploy is visible in GitHub Actions.
- old releases are retained for rollback.
- smoke test runs after deploy.

## Phase 5: Production Deployment

### Objective

Production deploys should be intentional, approved, and traceable.

### Triggers

```text
tag push: v*.*.*
manual workflow_dispatch
```

### Required GitHub environment

```text
production
```

Recommended setting:

```text
Settings -> Environments -> production -> Required reviewers
```

### Required secrets

```text
PROD_HOST
PROD_USER
PROD_SSH_KEY
PROD_DEPLOY_PATH
```

### Acceptance criteria

- production deploy does not happen from normal PR.
- production deploy requires tag or manual trigger.
- production environment approval is enabled.
- full E2E or release smoke tests run before / after deploy.

## Phase 6: Optional Self-Hosted Runner

### Objective

Use a cloud host runner only for work that GitHub-hosted runners cannot do well.

### Use cases

- heavy UAT Playwright suite
- multica integration verification
- private server/network checks
- long-running browser tests
- Docker-cache-heavy jobs

### Security rule

Do not run untrusted public PR code on the self-hosted runner.

### Recommended labels

```text
self-hosted
linux
x64
uat
```

### Acceptance criteria

- self-hosted runner is not required for normal PR quality gate.
- self-hosted runner is used only for manual UAT or trusted branches.
- secrets are scoped carefully.

## Phase 7: Branch Protection and GitHub Settings

### Main branch protection

Require:

```text
Pull request before merge
Required status checks
Conversation resolution
No direct push to main if possible
```

Recommended required checks:

```text
PR Quality Gate
Documentation Gate
Build Check
Playwright Smoke
```

### Environments

Create:

```text
development
uat
production
```

Recommended behavior:

```text
development = automatic after main merge
uat = manual workflow_dispatch
production = tag/manual + approval
```

## Local Agent Wrapper Policy

Add a wrapper script:

```text
scripts/agent-doc-review.sh
```

The wrapper should:

- inspect `git diff`
- generate an agent prompt
- optionally call the verified local CLI command
- never hardcode unverified model names
- never be required for merge
- never commit automatically unless explicitly requested

Initial safe behavior:

```bash
./scripts/agent-doc-review.sh
```

prints a prompt like:

```text
Review the current git diff. If product behavior changed, suggest updates to README.md, CHANGELOG.md, docs/prd, docs/bdd, docs/adr, docs/runbooks, or docs/testing. Do not invent facts. Do not change files unless explicitly instructed.
```

## E2E Policy

### PR smoke tests

Run on normal PRs:

- app loads
- core navigation works
- one critical CRUD path works
- auth/session smoke if applicable

### Full E2E regression

Run before production release:

- full dashboard flows
- CRUD happy paths
- validation errors
- permission cases
- critical integration paths

### Epic UAT

Run manually on a specific branch:

```text
Actions -> Deploy -> workflow_dispatch
environment = uat
ref = feature/epic-name
run_e2e = true
```

## Rollback Strategy

Every deployment should create a timestamped release directory:

```text
/opt/dogsquard/releases/20260530120000
/opt/dogsquard/current -> /opt/dogsquard/releases/20260530120000
```

Rollback means switching `current` to the previous release and restarting Docker Compose or the systemd service.

## First Pull Request Scope

The first implementation PR should only add foundation files:

```text
Makefile
.env.example
CHANGELOG.md
docs/ci-cd-implementation-plan.md
docs/adr/.gitkeep
docs/prd/.gitkeep
docs/bdd/.gitkeep
docs/runbooks/.gitkeep
docs/testing/.gitkeep
scripts/doc-check-local.sh
scripts/watch-docs.sh
scripts/agent-doc-review.sh
```

Do not add deployment yet in the first PR.

## Second Pull Request Scope

Add PR checks:

```text
.github/workflows/pr-quality.yml
.github/workflows/doc-check.yml
.github/pull_request_template.md
.github/ISSUE_TEMPLATE/feature.yml
.github/ISSUE_TEMPLATE/bug.yml
```

## Third Pull Request Scope

Add deployment:

```text
.github/workflows/deploy.yml
scripts/remote-deploy.sh
```

## Success Criteria

The CI/CD system is considered ready when:

- local `make release-check` works
- PR checks block bad merges
- docs are enforced or explicitly skipped
- dev deploy runs after `main` merge
- production deploy requires tag/manual trigger and approval
- E2E policy is fast for PRs and strict for releases
- optional agent tooling helps but does not control the pipeline
