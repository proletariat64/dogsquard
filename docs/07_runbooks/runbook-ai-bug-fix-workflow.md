---
title: "AI Bug Fix Workflow"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-06-05"
updated: "2026-06-05"
related_issue: "#1, #46"
related_pr: ""
supersedes: ""
---

# AI Bug Fix Workflow

## Purpose

This workflow lets Dogsquard prepare a draft PR for an explicitly approved bug issue.

The workflow is approval-gated and bounded. It is not autonomous merge, deploy, or production automation.

## When To Use It

Use it when all of the following are true:

- the issue is a real bug
- the issue scope is narrow enough for a small fix PR
- a human wants AI help with investigation and implementation
- a human still plans to review the resulting draft PR

## When Not To Use It

Do not use it when any of the following are true:

- the issue is a feature request instead of a bug
- the reproduction is unclear and needs product clarification first
- the likely fix requires dependency upgrades
- the likely fix requires production runtime, deploy, proxy, route, or multica changes
- the likely fix would require a broad refactor
- there is already an active AI-fix PR for the same issue

## Required Trigger

The workflow runs only when all approval conditions are met:

- the issue is open
- the issue has `bug`
- the issue has `ai-fix-candidate`
- a maintainer comments `/ai-fix-bug approved`

Maintainer means GitHub author association `OWNER`, `MEMBER`, or `COLLABORATOR`.

`bug` alone is never enough.

## What The Workflow Does

1. Fetch the issue body and comments.
2. Validate labels, trigger text, issue state, and maintainer association.
3. Create a focused branch named `ai-fix/issue-<number>-<slug>`.
4. Ask Claude Code to investigate and attempt the smallest safe fix.
5. Require GitNexus impact analysis before any existing symbol edit.
6. Stop if the proposed work touches forbidden production, runtime, proxy, or dependency files.
7. Run validation based on the changed area.
8. Run GitNexus detect-changes before finalization.
9. Commit, push, and open a draft PR only.
10. Comment back on the issue with reproduction status, fix summary, validation, scope control, residual risk, and GitNexus impact.

## Guardrails

- draft PR only
- no auto-merge
- no automatic issue close action by the workflow
- no production deploy/runtime/proxy/multica changes
- no reverse proxy, nginx, caddy, or traefik changes
- no dependency upgrades unless separately approved
- no broad refactors
- no unrelated docs cleanup

## Workflow Outputs

Expected issue state labels:

- `ai-fix-running` while the workflow is active
- `ai-fix-needs-human` if the workflow refuses or stops safely
- `ai-fix-pr-opened` after a draft PR is created

Expected draft PR contents:

- bug fixed summary
- root cause
- fix
- validation
- scope control
- residual risk

## Human Review Expectations

The draft PR still requires a human to:

- verify the reproduced bug and the claimed root cause
- review the code diff
- assess residual risk
- decide whether to merge or close the PR

The workflow prepares work. It does not replace review authority.
