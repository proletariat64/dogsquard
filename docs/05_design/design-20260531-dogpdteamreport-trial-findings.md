---
title: "dogpdteamreport Dogsquard Trial Findings"
doc_type: "design"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# dogpdteamreport Dogsquard Trial Findings

## Links

- Trial repo: <https://github.com/proletariat64/dogpdteamreport-dogsquard-trial>
- Trial Control Board: <https://github.com/proletariat64/dogpdteamreport-dogsquard-trial/issues/1>
- Trial PR: <https://github.com/proletariat64/dogpdteamreport-dogsquard-trial/pull/2>

## What Worked

- Dogsquard governance could be applied to a real Node.js, Express, TypeScript, sql.js, and static frontend app.
- Existing app code and project docs were preserved.
- Dogsquard issue templates, PR template, labels, docs governance, and local doc checks transferred cleanly.
- The trial PR passed local validation and PR Quality Gate after Node-specific adaptation.

## What Required Manual Adaptation

- Makefile needed to be rewritten around npm commands.
- PR Quality Gate needed a Node Quality job instead of Dogsquard's Go/frontend example app assumptions.
- Existing root README content needed to be preserved rather than replaced.
- Existing `ddd/` and `spec/` needed to remain project-specific docs.
- Dogsquard example app and dev deploy workflow needed to stay out of the first adoption PR.

## Node-specific Findings

- `package.json` and npm scripts are the source of local validation behavior.
- `npm test` and `npm run build` are the core default checks.
- Lint should be optional because the source project did not define a lint script.
- The generated Makefile should succeed with a clear message when lint is absent.

## CI Findings

- Node projects need Node setup and `npm ci`.
- PR Quality Summary remains useful.
- Go setup, Go tests, frontend subdirectory build, and Playwright smoke should not be assumed for Node-only repos.

## data/.gitkeep Finding

The source app expects a writable `data/` directory for runtime files such as lock and database data. Runtime files should remain ignored, but the directory placeholder should be committed when the project profile needs it.

## Legacy SSH UAT E2E Finding

The source project included a legacy SSH-based UAT/e2e file targeting `ifundaitest`. That check should not run in the default local or CI gate unless the external environment is intentionally available.

## Historical Bug Behavior Test Finding

Some tests asserted historical bug behavior rather than current behavior. During adoption, those assertions were aligned with current application behavior so the default gate validates the present app.

## v0.1.1 Recommendation

Dogsquard should add project profiles, starting with `PROJECT_TYPE=node`.

The Node profile should generate npm-based Makefile and PR Quality Gate assets while preserving existing project files and skipping Dogsquard example app and dev deploy assets by default.

## What Dogsquard Should Change Next

- Add `PROJECT_TYPE` support to bootstrap.
- Add Node-specific Makefile and PR Quality Gate templates.
- Keep dry-run default.
- Preserve existing files unless explicit overwrite is requested.
- Add profile tests using the dogpdteamreport trial as evidence.

## v0.1.1 Bootstrap Trial Follow-up

A follow-up `PROJECT_TYPE=node` trial against `dogpdteamreport-dogsquard-trial` confirmed that the profile-aware bootstrap generated a usable Node Makefile and PR Quality Gate without manual Makefile or CI adaptation.

The follow-up trial also found policy gaps:

- dev deploy remained opt-in instead of default for the Node profile.
- cn.ant high-port defaults were not generated.
- existing `.gitignore` files needed appended ignores for `AGENTS.md`, `CLAUDE.md`, and `roster.md`.
- optional npm script detection passed but could print noisy npm lifecycle output.

Dogsquard v0.1.1 fixes address those gaps by making dev deploy default for `node` and `go-js`, keeping docs-only non-deploy by default, generating cn.ant high-port defaults, appending local/private agent ignores, and quieting optional npm script detection.
