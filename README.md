# Dogsquard

Dogsquard is a reusable vibe-coding bootstrap kit for future small and medium internal application repositories.

It is not the business product itself.

Dogsquard provides project governance, local commands, GitHub workflow, PR quality checks, optional dev deploy patterns, and agent operating rules so new repositories can start with a disciplined delivery foundation.

## Who It Is For

Dogsquard is for the user as a solo developer, product owner, and process owner.

The intended working model is:

- human controls product meaning, review, process, and release decisions
- agents do most implementation work
- GitHub issues and PRs control project progress
- docs drive development through BRD, PRD, BDD, ADR, tests, and runbooks

## Current Capabilities

- documentation governance structure and checks
- Makefile command center
- GitHub issue and PR templates
- PR Quality Gate workflow
- example Go backend and TypeScript frontend
- API smoke and Playwright smoke tests
- dev deployment pattern for `cn.ant`
- user-level runtime management
- GitHub Actions Dev Deploy workflow
- SSH tunnel dev validation
- Control Board dashboard process

## Quick Start For This Repo

Run local checks:

```bash
make doc-check
make doc-guard
make release-check
git diff --check
bash -n scripts/*.sh
```

Run the example app checks:

```bash
cd backend && go test ./...
cd ../frontend && npm install && npm run build
cd ..
make e2e-smoke
```

Package a release artifact:

```bash
make package-release
```

## New Repo Bootstrap Flow

Dogsquard assumes the user manually creates a new GitHub repository first.

Canonical profile-aware flow:

```bash
git clone <new-repo-url>
cd dogsquard
PROJECT_TYPE=node TARGET_DIR=../new-repo scripts/bootstrap-project.sh
PROJECT_TYPE=node TARGET_DIR=../new-repo DRY_RUN=false scripts/bootstrap-project.sh
```

Optional example app:

```bash
PROJECT_TYPE=go-js TARGET_DIR=../new-repo DRY_RUN=false INCLUDE_EXAMPLE_APP=true scripts/bootstrap-project.sh
```

Optional production profile scaffold:

```bash
PROJECT_TYPE=node TARGET_DIR=../new-repo DRY_RUN=false INCLUDE_PRODUCTION_PROFILE=true scripts/bootstrap-project.sh
```

`scripts/init-new-repo.sh` remains a conservative legacy compatibility flow. Use `scripts/bootstrap-project.sh` by default because it supports `PROJECT_TYPE=node`, `PROJECT_TYPE=go-js`, and `PROJECT_TYPE=docs-only`, and it is covered by `make bootstrap-test`.

Review generated files before committing in the target repo.

## GitHub Setup Overview

Dogsquard provides:

- `.github/ISSUE_TEMPLATE/`
- `.github/pull_request_template.md`
- `.github/labels.yml`
- `.github/workflows/pr-quality.yml`

Labels are documented as source configuration and may need manual setup until label automation is added.

Dev deploy requires manual GitHub Environment setup if used.

## Dev Deploy Overview

The current Dogsquard dev deployment target is `cn.ant`.

The current dev runtime is isolated under:

```text
~/apps/dogsquard-dev
```

Public access is not exposed by default. SSH tunnel access is the validated human dev validation mode.

## Safety Notes

- Do not deploy Dogsquard to `us.hermes`.
- Do not target `43.130.49.185`.
- Do not claim `/` or `/api` on `proletariat.icu`.
- Do not modify reverse proxy, SSL, or firewall configuration as part of template bootstrap.
- Do not commit secrets, raw server output, private SSH config, or local agent session files.
- Production deployment is future work and requires explicit approval.

## Key Docs

- Control Board: https://github.com/proletariat64/dogsquard/issues/1
- Project roadmap: `docs/05_design/design-20260531-project-roadmap.md`
- New repo bootstrap runbook: `docs/07_runbooks/runbook-new-repo-bootstrap.md`
- PR Quality Gate runbook: `docs/07_runbooks/runbook-pr-quality-gate.md`
- Dev deployment runbook: `docs/07_runbooks/runbook-dev-deployment.md`
- Template Finalization PRD: `docs/02_prd/prd-20260531-template-finalization.md`
- Template boundary ADR: `docs/04_adr/0007-define-dogsquard-template-kit-boundary.md`
- Template inventory: `docs/05_design/design-20260531-template-inventory.md`

## v0.1.0 Readiness Status

Dogsquard is in Milestone 6E Template Finalization.

Current target:

- bootstrap/init path implemented
- README usable as template entrypoint
- fresh repo initialization validated locally
- no secrets or local-only files copied
- PR Quality Gate green

Production deployment is not required for `v0.1.0`.
