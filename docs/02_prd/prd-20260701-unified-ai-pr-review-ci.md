---
title: "Unified AI PR Review CI"
doc_type: "prd"
status: "draft"
owner: "user"
source: "user"
created: "2026-07-01"
updated: "2026-07-01"
related_issue: ""
related_pr: ""
supersedes: ""
---

# Unified AI PR Review CI

## Purpose

Define one Dogsquard AI PR review workflow that can run either:

- Qoder CLI
- Claude Code through the existing DeepSeek-compatible configuration

The workflow should keep one review contract, one prompt policy, and one PR comment behavior instead of maintaining separate AI review implementations.

## Repo Context

Dogsquard already has GitHub Actions as the deterministic CI authority through `PR Quality Gate`. AI review should support PR review, but it must not replace deterministic checks.

Current repository state:

- `.github/workflows/ai-pr-review.yml` already runs Claude Code through DeepSeek and posts a stable Dogsquard AI review comment. Its prompt says not to approve, reject, or block the PR; deterministic CI remains the merge gate.
- `.github/workflows/ai-fix-bug.yml` also uses the same Claude Code plus DeepSeek setup for approved bug-fix draft PRs.
- `.github/claude/deepseek-settings.json` is not orphaned. It is referenced by the existing Claude workflows and should become the single source for Claude plus DeepSeek non-secret model/environment configuration.
- `.github/workflows/qoder-pr-review.yml` and `.github/workflows/qoder-pr-review/` introduce a separate Qoder CLI PR review path.
- The current Qoder scaffold has its own policy file, script, comment marker, model selection, and output contract.
- Root `AGENTS.md` and `CLAUDE.md` are currently local/untracked GitNexus files. They should not become the committed PR review policy unless explicitly approved.

## Problem Statement

Dogsquard now has two AI PR review directions:

1. the existing Claude Code plus DeepSeek workflow
2. the new Qoder CLI workflow scaffold

Keeping them separate will create prompt drift, duplicated PR context building, duplicated comment behavior, unclear engine selection, and unclear pass/fail authority.

Dogsquard needs one unified AI PR review workflow with provider-specific adapters behind it.

## Goals

- Provide one AI PR review workflow for Dogsquard PRs.
- Allow engine selection through explicit configuration or environment variable.
- Support at least these engine values:
  - `claude-deepseek`
  - `qoder`
- Move shared review policy and prompt text out of inline workflow YAML.
- Keep provider-specific invocation details in scripts, not in the product prompt.
- Use `.github/claude/deepseek-settings.json` as the only committed Claude plus DeepSeek settings file.
- Create `.github/qoder/settings.json` as the Qoder provider config placeholder.
- Avoid duplicating the same provider environment configuration in multiple YAML/JSON files.
- Produce one stable Dogsquard PR comment format regardless of engine.
- Record which engine and model were used when visible.
- Fail the selected AI review job clearly when required secrets, PR metadata, changed-file diff, provider invocation, or provider output are missing or invalid.
- Keep the AI review verdict advisory; preserve `PR Quality Gate` as the deterministic merge authority.

## Non-Goals

- Do not replace `PR Quality Gate`.
- Do not add auto-fix behavior to PR review.
- Do not introduce self-hosted runners.
- Do not change deployment or production workflows.
- Do not benchmark all model/provider quality in this PRD.
- Do not commit local-only `AGENTS.md`, `CLAUDE.md`, `roster.md`, or tool logs as part of this requirement.

## Initial Product Direction

Use one workflow entrypoint and one runner layer.

Preferred repository shape:

```text
.github/
  claude/
    deepseek-settings.json
  qoder/
    settings.json
  workflows/
    ai-pr-review.yml
    prompts/
      pr-review-policy.md
      pr-review-output-contract.md
    scripts/
      ai_review_pr.py
```

The workflow should choose an engine, build the same PR review context, load the same prompt/policy files, call the selected provider adapter, validate the output, and upsert one PR comment.

Initial safe default: keep the existing Claude Code plus DeepSeek path as the default unless `AI_REVIEW_ENGINE=qoder` is explicitly set. Qoder becomes selectable once token-only CI auth and output validation are proven.

## Provider Configuration Policy

Provider configuration should have one committed home per provider.

Claude plus DeepSeek:

- Keep non-secret Claude/DeepSeek model and API-base configuration in `.github/claude/deepseek-settings.json`.
- Workflow YAML should call Claude Code with `--settings .github/claude/deepseek-settings.json`.
- Workflow YAML should not repeat the same `ANTHROPIC_*` model and base-url values already present in that JSON file.
- Workflow YAML may still inject runtime-only values such as tokens, PR number, GitHub token, engine selection, and temp paths.

Qoder:

- Reserve `.github/qoder/settings.json` for future Qoder CLI non-secret configuration.
- Do not commit Qoder secrets in this file. Use GitHub Secrets or runtime environment injection for credentials.
- The current Qoder-specific workflow directory should be folded into the unified runner when implementation starts.

## Review Authority And Provider Decisions

AI review keeps the original Dogsquard positioning:

- AI review is an advisory PR comment.
- AI review must not approve, reject, or block the PR by model judgment.
- `PR Quality Gate` remains the deterministic merge authority.
- The AI review job should still fail when the selected engine cannot produce a valid review, because fake-green AI review is worse than a visible missing review.

Provider behavior:

- The AI review channel is single-select per run.
- Do not fall back from Qoder to Claude or from Claude to Qoder.
- If the selected provider is unavailable, misconfigured, unauthorized, times out, or returns invalid output, fail the AI review job and post a clear failure comment when possible.

Comment behavior:

- Preserve the Dogsquard marker: `<!-- dogsquard-ai-code-review -->`.
- Do not introduce separate provider markers such as a Qoder-only marker in the final unified workflow.
- The comment title and sections should remain Dogsquard-branded, with engine/model details inside the body.

## Prompt Policy

Shared review rules should live in prompt files under `.github/workflows/prompts/`.

Workflow YAML should not contain the full review prompt.

The prompt should stay Dogsquard-first:

- keep Dogsquard repository purpose, template boundary, GitHub Actions safety, secrets safety, shell safety, and CI-risk review focus from the existing `ai-pr-review.yml` prompt
- keep the instruction that AI review does not approve, reject, or block the PR
- keep the Dogsquard comment marker and Dogsquard-branded output

Fold in the useful parts from the Qoder scaffold where they improve quality without changing Dogsquard positioning:

- explicit provider/engine/model reporting
- explicit acceptance check against PR intent
- explicit file-skip check for safe binary/document-only PRs
- clearer blocking-vs-non-blocking finding separation
- failure visibility when the selected provider cannot produce a valid review

Provider-specific adapters may add only the minimal wrapper needed for that provider, such as Qoder `/review` invocation text or Claude Code command input framing.

If Qoder requires an `AGENTS.md` policy file at repository root during the CI run, generate or copy it inside the runner workspace from the shared prompt source. Do not treat the user's local root `AGENTS.md` as the committed policy.

## Engine Selection

The engine should be selected explicitly and visibly.

Suggested precedence:

1. manual `workflow_dispatch` input
2. repository variable or workflow environment value
3. documented default engine

Invalid engine values should fail before calling any provider. The runner must not silently fall back to another provider.

## Acceptance Criteria

- One active AI PR review workflow can run either `claude-deepseek` or `qoder`.
- Both engines use the same shared review policy and output contract.
- The workflow posts or updates one stable Dogsquard PR review comment using `<!-- dogsquard-ai-code-review -->`.
- The output identifies engine and model when available.
- AI review verdict remains advisory and does not replace or override `PR Quality Gate`.
- Missing secret, missing PR number, empty diff, selected-provider failure, timeout, and invalid output fail the selected AI review job visibly.
- No cross-provider fallback occurs.
- Existing deterministic PR checks remain separate and unchanged.
- `.github/claude/deepseek-settings.json` is kept as the single committed Claude plus DeepSeek provider settings file.
- Existing workflow YAML no longer duplicates the same Claude/DeepSeek non-secret environment settings from `.github/claude/deepseek-settings.json`.
- `.github/qoder/settings.json` exists as the Qoder provider config placeholder and contains no secrets.
- The old separate Qoder scaffold is removed or folded into the unified workflow after the unified path is ready.
- Local/untracked `AGENTS.md` and `CLAUDE.md` are not accidentally committed as review policy.

## Settled Decisions

- AI review remains advisory by model judgment. `PR Quality Gate` remains the deterministic merge gate.
- The selected AI review provider must not fall back to another provider.
- The unified workflow preserves the Dogsquard comment marker: `<!-- dogsquard-ai-code-review -->`.
- The shared review prompt starts from the existing Dogsquard AI review prompt and folds in useful Qoder scaffold improvements only where they improve output quality and failure visibility.
