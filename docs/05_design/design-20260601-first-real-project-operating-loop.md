---
title: "First Real Project Operating Loop Findings"
doc_type: "design"
status: "draft"
owner: "user"
source: "agent"
created: "2026-06-01"
updated: "2026-06-01"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Purpose

Record what Dogsquard learned after operating the first real adopted project beyond bootstrap.

# Context

`dogpdteamreport` was adopted as the first real project governed by Dogsquard.

The operating loop included:

- applying Dogsquard v0.1.1 governance to the real repo
- merging one real product PR through the adopted workflow
- triaging and closing stale pre-adoption product issues
- updating both project and Dogsquard Control Boards

# Evidence

- Real project repo: <https://github.com/proletariat64/dogpdteamreport>
- Real project Control Board: <https://github.com/proletariat64/dogpdteamreport/issues/12>
- Adoption PR: <https://github.com/proletariat64/dogpdteamreport/pull/11>
- First product PR: <https://github.com/proletariat64/dogpdteamreport/pull/13>
- Dogsquard Control Board: <https://github.com/proletariat64/dogsquard/issues/1>

# What Worked

- Dogsquard could govern a real Node.js project after bootstrap.
- A real product bug fix merged through local validation and PR Quality Gate.
- The project Control Board stayed useful after adoption.
- Stale issues could be closed with concrete source and runtime evidence.
- Dogsquard process improvements stayed separate from product work.

# Browser and Manual UI Verification

Frontend-heavy product PRs may need evidence beyond static code review and backend tests.

For browser-visible behavior, use a lightweight verification note that records:

- page or workflow tested
- local URL or environment used
- browser method used, such as Playwright, system Chromium, or manual browser check
- key visible assertions, such as labels, buttons, layout state, or row count
- whether the check used a temporary local database
- whether production, dev deploy, or public routes were untouched

This verification should be scoped to the changed behavior. It should not become a broad full-regression browser suite unless the PR explicitly adds that capability.

# Legacy Tracked Agent Files

Existing projects may already have tracked local-agent files such as:

- `CLAUDE.md`
- `.claude/`
- `AGENTS.md`
- `roster.md`

Dogsquard bootstrap should keep these files ignored/local by default for new work, but adoption into an existing repo should not fail solely because legacy files are already tracked.

Recommended handling:

- preserve already-tracked files unless the user explicitly approves migration
- block newly introduced local/private agent files in normal PRs
- document any legacy tracked files in the adoption findings
- avoid mixing cleanup of legacy tracked files into unrelated product PRs

# Legacy Remote-host E2E Tests

Existing projects may contain e2e tests that target old remote hosts or UAT environments.

Default Dogsquard validation should remain local and deterministic. Remote-host e2e tests should be opt-in unless the environment is explicitly available and approved.

Recommended handling:

- exclude remote-host e2e tests from default local and PR gates
- keep a separate command or documented manual validation path for those tests
- avoid requiring external SSH hosts or production-like URLs in default PR Quality Gate
- record old remote target assumptions during adoption

# Follow-up Policy

Reusable Dogsquard improvements discovered while operating a product repo should become Dogsquard follow-up work, not product PR scope.

Product PRs should stay focused on product behavior. Dogsquard process changes should be grouped into coherent Dogsquard deliverables.

# Result

The first real project operating loop succeeded.

Dogsquard should carry forward three operating-loop policies:

- frontend-heavy product PRs should include scoped browser/manual verification evidence when behavior is visible in UI
- legacy tracked local-agent files should be handled as adoption compatibility, not automatic cleanup
- legacy remote-host e2e tests should be opt-in validation, not default PR gate behavior
