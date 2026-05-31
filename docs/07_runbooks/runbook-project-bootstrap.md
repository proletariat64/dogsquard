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

Future bootstrap should accept a profile:

```bash
PROJECT_TYPE=node scripts/init-new-repo.sh ../target-repo
DRY_RUN=false PROJECT_TYPE=node scripts/init-new-repo.sh ../target-repo
```

Profiles should decide the Makefile, PR Quality Gate, validation commands, optional assets, and runtime placeholders.

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
- Generate PR Quality Gate with Node setup and Node Quality job.
- Add runtime placeholders such as `data/.gitkeep` only when needed.
- Do not copy Dogsquard example app.
- Do not copy dev deploy workflow by default.

## PROJECT_TYPE=go-js Expected Steps

- Preserve existing `backend/` and `frontend/`.
- Generate Go and frontend validation commands.
- Keep Playwright smoke optional.
- Keep dev deployment assets opt-in.

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

## Do Not Copy Deploy Workflow By Default

Deployment requires host, route, secrets, and runtime decisions. Dev deploy workflow should be opt-in.

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

## Trial Repo Lessons

- Profile-aware Makefile and CI generation is needed.
- Existing product docs need to be preserved.
- Runtime ignored directories may need committed `.gitkeep` placeholders.
- Legacy external-host tests should not be part of default local gates unless the environment is available.
- Historical bug-expectation tests may need review during adoption.
