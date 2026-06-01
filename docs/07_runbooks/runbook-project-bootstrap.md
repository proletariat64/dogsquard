---
title: "Project Bootstrap Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Project Bootstrap Runbook

## Purpose

Explain how Dogsquard should be applied to new or existing repositories today, and how future profile-based bootstrap should work.

## Manual Bootstrap Process Today

1. Create or clone the target repository.
2. Run Dogsquard bootstrap in dry-run mode.
3. Review planned files.
4. Apply only the conservative governance core.
5. Manually adapt Makefile and PR Quality Gate to the project stack.
6. Preserve existing README, product docs, source, and tests.
7. Run local checks before opening a PR.

## Future Profile-based Bootstrap Process

Profile-aware bootstrap now uses `scripts/bootstrap-project.sh`:

```bash
PROJECT_TYPE=node TARGET_DIR=../target-repo scripts/bootstrap-project.sh
PROJECT_TYPE=node TARGET_DIR=../target-repo DRY_RUN=false scripts/bootstrap-project.sh
```

Profiles should decide the Makefile, PR Quality Gate, validation commands, optional assets, and runtime placeholders.

## Script Usage

Dry-run is the default:

```bash
PROJECT_TYPE=node TARGET_DIR=../target-repo scripts/bootstrap-project.sh
```

Apply changes:

```bash
PROJECT_TYPE=node TARGET_DIR=../target-repo DRY_RUN=false scripts/bootstrap-project.sh
```

Create the target directory only when explicitly requested:

```bash
PROJECT_TYPE=docs-only TARGET_DIR=../target-repo CREATE_TARGET=true scripts/bootstrap-project.sh
```

Overwrite existing generated files only when explicitly requested:

```bash
PROJECT_TYPE=node TARGET_DIR=../target-repo DRY_RUN=false FORCE=true scripts/bootstrap-project.sh
```

Optional example app material remains opt-in:

```bash
PROJECT_TYPE=go-js TARGET_DIR=../target-repo DRY_RUN=false INCLUDE_EXAMPLE_APP=true scripts/bootstrap-project.sh
```

Dev deploy material is included by default for `node` and `go-js` profiles. Disable it explicitly when a target should receive governance only:

```bash
PROJECT_TYPE=node TARGET_DIR=../target-repo DRY_RUN=false INCLUDE_DEV_DEPLOY=false scripts/bootstrap-project.sh
```

Docs-only repositories do not receive dev deploy material by default, but it can still be requested explicitly:

```bash
PROJECT_TYPE=docs-only TARGET_DIR=../target-repo DRY_RUN=false INCLUDE_DEV_DEPLOY=true scripts/bootstrap-project.sh
```

The Makefile wrapper is:

```bash
make bootstrap-dry-run TARGET=../target-repo PROJECT_TYPE=node
make bootstrap-test
```

## Choosing PROJECT_TYPE

- Use `node` for Node.js, JavaScript, or TypeScript-only repos.
- Use `go-js` for Dogsquard-style Go backend plus JS/TS frontend repos.
- Use `docs-only` for governance, planning, or documentation repositories.
- Defer `go-only` until there is a real Go-only adoption target.

## PROJECT_TYPE=node Expected Steps

- Preserve `package.json`, `package-lock.json`, source, tests, README, `ddd/`, and `spec/`.
- Add Dogsquard docs governance.
- Add issue and PR templates.
- Generate npm-based Makefile commands.
- Generate PR Quality Gate with Shell Check, Repository Hygiene, Node Quality, and PR Quality Summary.
- Generate dev deploy support by default.
- Generate cn.ant high-port dev defaults with frontend port `8173` and backend port `8180`.
- Add runtime placeholders such as `data/.gitkeep` only when needed.
- Do not copy Dogsquard example app.
- Allow dev deploy assets to be disabled with `INCLUDE_DEV_DEPLOY=false`.

## PROJECT_TYPE=go-js Expected Steps

- Preserve existing `backend/` and `frontend/`.
- Generate Go and frontend validation commands.
- Keep Playwright smoke optional.
- Generate dev deploy support by default.
- Generate cn.ant high-port dev defaults with frontend port `8173` and backend port `8180`.
- Generate PR Quality Gate with Shell Check, Repository Hygiene, Go/JS Quality, and PR Quality Summary.

## PROJECT_TYPE=docs-only Expected Steps

- Generate docs governance folders.
- Copy the core governance documents required by `make doc-check`.
- Generate doc-check and doc-guard scripts.
- Generate documentation-only Makefile commands.
- Generate PR Quality Gate with shell, repository hygiene, docs quality, and summary jobs.
- Keep dev deployment assets disabled by default unless `INCLUDE_DEV_DEPLOY=true`.
- Do not require Go, npm, Playwright, deployment, or runtime scripts.

## Preserve Existing Repo Content

Bootstrap must preserve:

- `README.md`
- package/module files
- source directories
- test directories
- existing domain docs such as `ddd/` and `spec/`
- existing deployment docs unless explicitly migrated

## Do Not Overwrite README Without Explicit Approval

If a target repo already has `README.md`, bootstrap should add a short Dogsquard section or companion doc rather than replacing it.

## Do Not Copy Example App By Default

The Dogsquard example app is validation material. It should be copied only when the user explicitly asks for example app material.

## Deploy Workflow Defaults

Docs-only repositories should not receive deploy workflow by default.

For `node` and `go-js`, dev deploy support is now default Dogsquard bootstrap content because the current Control Board treats cn.ant dev deployment and high-port access as baseline template capabilities. The generated material is still dev-only and does not add production deployment.

## Dev High-port Defaults

Applicable profiles generate:

- `.env.dogsquard-dev.example`
- `docs/07_runbooks/runbook-dev-high-port-access.md`

Default dev access values:

- dev host: `cn.ant`
- firewall range: `8000-8999`
- frontend public/dev candidate port: `8173`
- backend public/dev candidate port: `8180`

These values are development defaults only. They must not be used to target `us.hermes`, `proletariat.icu` root, `proletariat.icu/api`, or production.

## Post-bootstrap Validation Commands

For Node projects:

```bash
npm ci
npm test
npm run build
make help
make doc-check
make doc-guard
make test
make lint
make release-check
git diff --check
bash -n scripts/*.sh
```

For Go/JS projects, include Go backend tests and frontend build according to the generated Makefile.

For docs-only projects:

```bash
make help
make doc-check
make doc-guard
make release-check
git diff --check
bash -n scripts/*.sh
```

## Bootstrap Script Validation

Dogsquard validates the profile-aware bootstrap behavior with:

```bash
make bootstrap-test
```

The test script creates temporary targets, exercises dry-run and apply mode, verifies existing README preservation, checks generated Makefile and PR Quality Gate files, verifies docs folders and core governance docs, runs `make doc-check` in generated docs-only and node targets, confirms optional example app remains opt-in, and checks deploy defaults per profile.

Current validation also confirms:

- `PROJECT_TYPE=node` includes dev deploy by default.
- `PROJECT_TYPE=node` can disable dev deploy with `INCLUDE_DEV_DEPLOY=false`.
- `PROJECT_TYPE=go-js` includes dev deploy by default.
- `PROJECT_TYPE=docs-only` excludes dev deploy by default.
- existing `.gitignore` files are preserved and appended with local/private agent file ignores.
- generated Node Makefile optional script detection avoids noisy npm lifecycle errors.

## Trial Repo Lessons

- Profile-aware Makefile and CI generation is needed.
- Existing product docs need to be preserved.
- Runtime ignored directories may need committed `.gitkeep` placeholders.
- Legacy external-host tests should not be part of default local gates unless the environment is available.
- Historical bug-expectation tests may need review during adoption.
