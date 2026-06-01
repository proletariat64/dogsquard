---
title: "Project Bootstrap Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-06-01"
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

Production profile scaffold is opt-in and planning-only:

```bash
PROJECT_TYPE=node TARGET_DIR=../target-repo DRY_RUN=false INCLUDE_PRODUCTION_PROFILE=true scripts/bootstrap-project.sh
```

This generates production placeholders, runbook, test plan, and guard script. It does not generate a production deploy workflow, deploy anything, change servers, or expose a route.

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

## Production Profile Scaffold

Use production scaffold only after production implementation planning is approved:

```bash
PROJECT_TYPE=node TARGET_DIR=../target-repo DRY_RUN=false INCLUDE_PRODUCTION_PROFILE=true scripts/bootstrap-project.sh
```

Generated assets:

- `.env.dogsquard-production.example`
- `scripts/production-profile-guard.sh`
- `docs/07_runbooks/runbook-production-profile.md`
- `docs/06_testing/test-production-profile.md`

The scaffold is intentionally not a deploy implementation. It must not create:

- `.github/workflows/deploy-production.yml`
- reverse proxy config
- server config
- public route activation
- secrets files

The generated guard can validate candidate values without deploying:

```bash
PROD_HOST=us.hermes \
PROD_DOMAIN=proletariat.icu \
PROD_REPO_NAME=dogpdteamreport \
PROD_ROUTE=/dogpdteamreport \
scripts/production-profile-guard.sh
```

Current approved planning route shape:

- frontend: `https://proletariat.icu/{reponame}/`
- backend: `https://proletariat.icu/{reponame}/api`

The guard must reject raw protected IP use, root `/`, top-level `/api`, and `proletariat.icu` routes outside the approved repo prefix.

This route strategy does not approve production implementation, reverse proxy edits, server changes, or public route activation.

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
- production profile scaffold remains opt-in.
- production profile scaffold does not generate production deploy workflow.
- generated production guard accepts only the approved `us.hermes` plus repo-scoped `proletariat.icu/{reponame}` route shape and rejects unsafe route collisions.

## Trial Repo Lessons

- Profile-aware Makefile and CI generation is needed.
- Existing product docs need to be preserved.
- Runtime ignored directories may need committed `.gitkeep` placeholders.
- Legacy external-host tests should not be part of default local gates unless the environment is available.
- Historical bug-expectation tests may need review during adoption.

## Operating-loop Lessons

The first real-project operating loop in `dogpdteamreport` showed that adoption does not end after bootstrap and PR Quality Gate installation.

After adoption, agents should expect a short operating-loop follow-up:

1. Merge at least one real product PR through the adopted workflow.
2. Triage stale or pre-adoption product issues.
3. Close issues that are already fixed with concrete evidence.
4. Record reusable Dogsquard friction as Dogsquard follow-up work instead of mixing it into product PRs.

### Browser-visible Product Changes

For frontend-heavy product PRs, local tests may not prove the visible behavior.

Use scoped browser or manual UI verification when a PR changes or verifies:

- navigation labels
- visible form controls
- layout behavior
- modal, inline editor, or dropdown state
- product workflows that are primarily browser-facing

Record enough evidence for review:

- page or workflow tested
- local URL or environment
- browser method, such as Playwright, system Chromium, or manual browser check
- visible assertions that passed
- whether the check used a temporary local database
- confirmation that production, remote deploy, and public routes were untouched

Do not turn every UI check into a separate PR. Keep browser verification attached to the product PR or operating-loop triage that needs it.

### Legacy Tracked Agent Files

New Dogsquard bootstrap output should ignore local/private agent files by default:

- `.claude/`
- `AGENTS.md`
- `CLAUDE.md`
- `roster.md`

Existing repositories may already track one or more of those files. Adoption should preserve them unless the user explicitly approves migration.

Recommended adoption behavior:

- document legacy tracked agent files in adoption findings
- block newly introduced local/private agent files in ordinary PRs
- do not fail an adoption solely because a legacy file is already tracked
- do not clean up legacy tracked agent files inside unrelated product PRs

### Legacy Remote-host E2E Tests

Some existing projects have e2e tests that target old UAT hosts, SSH aliases, or public URLs.

Default Dogsquard validation should stay local and deterministic. Remote-host e2e tests should be opt-in unless the user explicitly approves that environment for the PR.

Recommended adoption behavior:

- exclude remote-host e2e tests from default `make release-check` and PR Quality Gate
- document the old target and how to run the test manually
- add an explicit opt-in command only when the test remains useful
- never require production, `us.hermes`, or `proletariat.icu` access for default PR validation
