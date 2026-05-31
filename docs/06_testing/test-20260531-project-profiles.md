---
title: "Project Profiles Test Plan"
doc_type: "test"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Project Profiles Test Plan

## Objective

Validate that Dogsquard project profiles can initialize or adopt repositories without destructive overwrites and with correct local and CI validation behavior for the chosen project type.

## dogpdteamreport Trial Validation Summary

Trial repository: <https://github.com/proletariat64/dogpdteamreport-dogsquard-trial>

Trial PR: <https://github.com/proletariat64/dogpdteamreport-dogsquard-trial/pull/2>

Validation passed:

- `npm ci`
- `npm test`
- `npm run build`
- `make help`
- `make doc-check`
- `make doc-guard`
- `make test`
- `make lint`
- `make release-check`
- `git diff --check`
- `bash -n scripts/*.sh`
- PR Quality Gate: Shell Check, Repository Hygiene, Node Quality, PR Quality Summary

## Expected Validation for PROJECT_TYPE=node

- Dry-run shows Node-specific Makefile and PR Quality Gate actions.
- Apply mode preserves existing README and package files.
- Generated Makefile runs npm-based commands.
- PR Quality Gate sets up Node and runs `npm ci`.
- `make release-check` passes in a Node repo without Go or Dogsquard example app directories.
- Existing `ddd/`, `spec/`, source, and tests are preserved.
- Runtime placeholders such as `data/.gitkeep` are created only when needed.
- `scripts/bootstrap-project.sh` does not create `backend/` or `frontend/` unless `INCLUDE_EXAMPLE_APP=true`.

## Expected Validation for PROJECT_TYPE=go-js

- Dry-run shows Go/backend and frontend actions.
- Go tests run when `backend/go.mod` exists.
- Frontend build runs when `frontend/package.json` exists.
- Playwright smoke is optional and only enabled when the repo includes the expected frontend e2e setup.
- Dev deploy workflow is opt-in.

## Expected Validation for PROJECT_TYPE=docs-only

- Makefile exposes docs commands only.
- PR Quality Gate runs shell syntax, repository hygiene, documentation checks, and summary.
- No Go, Node, frontend, Playwright, or deployment assumptions are required.

## Bootstrap Dry-run Expectations

- Dry-run is default.
- Planned creates, copies, skips, and adaptations are visible.
- Existing files that would be preserved are listed as `SKIP` or equivalent.
- Profile choice is printed.

## Overwrite Safety Expectations

- Existing `README.md`, package files, source, tests, docs, and workflows are never overwritten without explicit `FORCE=true` or a future backup mechanism.
- Tool-local files and secrets are never copied.
- Deployment workflows are only copied when requested.

## Future Acceptance Tests for v0.1.1

- Fresh `PROJECT_TYPE=node` target passes generated local checks.
- Existing Node project adoption preserves app files and passes generated local checks.
- `PROJECT_TYPE=go-js` Dogsquard-style target still passes existing Dogsquard validation.
- `PROJECT_TYPE=docs-only` target passes without app source.
- Default bootstrap remains conservative and non-destructive.

## Bootstrap Script Validation Results

Implemented validation command:

```bash
make bootstrap-test
```

Validation coverage:

- `docs-only` dry-run does not write files.
- `docs-only` apply generates Makefile, PR Quality Gate, docs folders, and doc scripts.
- `docs-only` apply includes core governance docs and passes `make doc-check`.
- `node` apply preserves existing README, source, tests, and package files.
- `node` apply generates npm-based Makefile and Node Quality workflow.
- `node` apply creates `data/.gitkeep` when runtime-data signals are present.
- `node` apply includes core governance docs and passes `make doc-check`.
- `go-js` apply generates Go/JS Makefile and Go/JS Quality workflow.
- `INCLUDE_EXAMPLE_APP=true` copies `backend/` and `frontend/` while excluding `node_modules` and build output.
- `INCLUDE_DEV_DEPLOY=true` copies dev deploy workflow/scripts only when requested.
