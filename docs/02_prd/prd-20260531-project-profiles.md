---
title: "Project Profiles PRD"
doc_type: "prd"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Project Profiles PRD

## Purpose

Dogsquard needs project profiles so it can initialize different repository types without manual adaptation.

## Problem

The `dogpdteamreport` trial showed that applying Dogsquard to a Node repo required manual Makefile and CI adaptation.

Dogsquard v0.1.0 successfully provided reusable governance, but its default bootstrap assets still reflected the Dogsquard reference repo shape. A real Node.js project needed the existing README, `ddd/`, `spec/`, source, and tests preserved while generated Makefile and PR Quality Gate behavior needed to match npm-based validation.

## Target User

The user, as a solo developer using agent-heavy vibe coding.

## Goals

- Support project-type specific bootstrap.
- Preserve existing project files.
- Avoid copying irrelevant example app or deploy workflow assets.
- Generate correct Makefile and PR Quality Gate behavior for each profile.
- Keep governance docs consistent across repos.
- Reduce cognitive load when starting or adopting new repositories.

## Non-goals

- No implementation script in this PR.
- No production deploy.
- No modifying the `dogpdteamreport` trial repo.
- No public template release yet.

## Profiles

### PROJECT_TYPE=node

For Node, JavaScript, and TypeScript-only repositories.

Expected inputs:

- `package.json`
- npm scripts
- existing source and tests
- optional existing docs such as `ddd/` and `spec/`

Expected bootstrap behavior:

- Preserve source and tests.
- Preserve `README.md` unless explicitly replaced.
- Generate or adapt Makefile targets around npm commands.
- Run `npm ci`, `npm test`, and `npm run build` when available.
- Treat lint as optional: run `npm run lint` if present, otherwise print a clear skip or build-validation message.
- Generate a PR Quality Gate with Node Quality instead of Go/backend checks.
- Do not copy the Dogsquard Go example app.
- Do not copy the dev deploy workflow by default.

### PROJECT_TYPE=go-js

For Dogsquard-style full-stack repositories with a Go backend and JavaScript or TypeScript frontend.

Expected inputs:

- `backend/`
- `frontend/`
- Go module in `backend/go.mod`
- frontend `package.json`

Expected bootstrap behavior:

- Preserve backend and frontend when present.
- Generate Makefile targets for Go tests and frontend build.
- Keep Playwright smoke optional and profile-aware.
- Keep dev deploy optional rather than default.
- Use Go and Node setup in PR Quality Gate only when the relevant directories are present or requested.

### PROJECT_TYPE=docs-only

For documentation, process, planning, or governance repositories.

Expected bootstrap behavior:

- Copy docs governance structure.
- Copy doc-check and doc-guard scripts.
- Generate a Makefile with documentation commands only.
- Generate a PR Quality Gate that does not assume app source, Go, Node, Playwright, or deployment.

### Optional Future: PROJECT_TYPE=go-only

For Go service repositories without a frontend.

Potential behavior:

- Run `go test ./...`.
- Run Go formatting/vet checks.
- Omit frontend, npm, and Playwright assumptions.

## Bootstrap Behavior

### Always Copy

- Docs governance directories.
- Documentation check scripts.
- Issue templates.
- PR template.
- Label source definition.
- Control Board and roadmap guidance.

### Copy If Missing

- `README.md` starter section or companion Dogsquard README.
- `CHANGELOG.md`.
- `.env.example`.
- `.gitignore` entries for local and runtime files.

### Adapt By Profile

- Makefile.
- PR Quality Gate workflow.
- Validation commands.
- Test plan language.
- Optional runtime directory placeholders such as `data/.gitkeep`.

### Never Overwrite Without Backup

- `README.md`.
- `package.json`.
- `go.mod`.
- Existing source directories.
- Existing test directories.
- Existing project docs such as `ddd/` and `spec/`.
- Existing deployment docs.

### Skip By Profile

- Do not copy Dogsquard example app unless requested.
- Do not copy deploy workflow unless deployment profile is enabled.
- Do not copy server topology docs into unrelated repos by default.
- Do not copy tool/session-local files.

## Runtime Directory Placeholders

Profiles may need safe placeholders for ignored runtime directories. For Node repos like `dogpdteamreport`, `data/.gitkeep` can be created when tests or runtime code need a writable directory while database, lock, backup, and generated files remain ignored.

## Acceptance Criteria

- Profiles are documented.
- Node profile requirements are clear.
- Go/JS profile requirements are clear.
- Bootstrap strategy avoids destructive overwrite.
- `dogpdteamreport` trial findings are captured.
- `v0.1.1` direction is clear.
