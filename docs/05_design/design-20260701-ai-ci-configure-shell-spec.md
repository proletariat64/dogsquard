---
title: "AI CI Configure Shell Implementation Spec"
doc_type: "design"
status: "draft"
owner: "coding-agent"
source: "agent"
created: "2026-07-01"
updated: "2026-07-01"
related_issue: ""
related_pr: ""
supersedes: ""
---

# AI CI Configure Shell Implementation Spec

## Source Requirement

Primary PRD: `docs/02_prd/prd-20260701-unified-ai-pr-review-ci.md`

Feature section: `New Feature: AI CI Configure Shell`

This spec defines the implementation path for a command-line configuration helper that lets a user turn Dogsquard AI CI review on/off, choose the review engine, choose provider/model settings, and activate the resulting configuration without hand-editing workflow YAML.

## Current Code Baseline

Current unified AI PR review implementation already has these surfaces:

```text
.github/workflows/ai-pr-review.yml
.github/workflows/scripts/ai_review_pr.py
.github/workflows/prompts/pr-review-policy.md
.github/workflows/prompts/pr-review-output-contract.md
.github/claude/deepseek-settings.json
.github/qoder/settings.json
scripts/upsert-pr-comment.sh
```

Current useful behavior:

- one active `AI PR Review` workflow
- selectable engine values: `claude-deepseek`, `qoder`
- Qoder CLI installed only for Qoder runs
- `qodercli --version` checked against `QODERCLI_VERSION`
- Qoder model preference already exists in `.github/qoder/settings.json`
- runner writes `.tmp/ai-review/review.md`
- workflow posts or updates the stable Dogsquard comment marker
- provider failure writes a visible failure comment

Current gaps for this feature:

- no configuration shell exists
- AI CI on/off is not config-file controlled yet
- Qoder model config currently allows explicit `Auto` and more than two preference entries
- Qoder fallback currently does not retry another model after invalid Dogsquard output shape
- Claude provider selection is implicit rather than represented as a provider list
- live GitHub variable activation is not separated from local file changes

## Settled Decisions

### On/off Source Of Truth

AI CI on/off is controlled by a committed repository configuration file.

Do not treat GitHub repository variables as the canonical on/off source. Repository variables may be updated only as an optional compatibility/live-activation layer.

### Apply Semantics

Default apply behavior changes local files only.

Optional live activation may be added through explicit direct flags or interactive confirmations:

```bash
scripts/configure-ai-ci.sh --apply --apply-github-vars
```

The direct flag and the interactive activation prompt may set non-secret GitHub repository variables, but must never read, print, store, or commit secret values.

Interactive apply may optionally call `gh secret set SECRET_NAME` after showing the required secret name and current name-only status. GitHub CLI owns secure secret input and encryption; the script only passes the secret name.

Interactive apply may also offer to commit the generated config and push the current branch so GitHub Actions can actually load the committed file. This path must stage only `.github/ai-review/settings.json`, refuse when tracked working-tree changes are not limited to that file, and tell the user that `git push` sends the current branch.

### Qoder Fallback Scope

Qoder fallback is provider-local and includes:

- model unavailable
- model restricted
- model timeout
- provider invocation failure that is classified retryable
- invalid Dogsquard review output contract

Qoder fallback must not call Claude. Claude failure must not call Qoder.

### User Experience

Primary UX is interactive command-line menu.

Direct flags are allowed for repeatable automation and tests, but the normal human path should be menu-driven.

## New File Layout

Add a top-level AI review configuration file:

```text
.github/ai-review/settings.json
```

Keep provider-specific config files:

```text
.github/claude/deepseek-settings.json
.github/qoder/settings.json
```

Add the shell helper:

```text
scripts/configure-ai-ci.sh
```

Optional future wrapper integration:

```text
./install --configure-ai-ci
```

## Configuration Schema

Canonical file:

```json
{
  "enabled": true,
  "engine": "qoder",
  "claude": {
    "provider": "deepseek"
  },
  "qoder": {
    "models": ["Qwen3.7-Max", "GLM-5.2"],
    "implicit_auto_fallback": true
  }
}
```

### Default Behavior Boundary

There are two defaults and they serve different compatibility needs:

- Legacy runner missing-config default: if `.github/ai-review/settings.json` is absent, the runner must keep existing behavior by treating AI review as enabled and using `claude-deepseek`.
- Configure-script generated default: when `scripts/configure-ai-ci.sh` creates a new settings file, it should generate an enabled Qoder config with one real model, then rely on implicit `Auto` fallback at runtime.

The configure script default must not change the runner's no-file fallback. The runner fallback protects existing repositories that have not adopted the configure shell yet; the generated config represents an explicit new adoption choice.

### Required Fields

| Field | Type | Allowed values | Notes |
|---|---|---|---|
| `enabled` | boolean | `true`, `false` | Source of truth for AI CI on/off |
| `engine` | string | `claude-deepseek`, `qoder` | Active provider engine |
| `claude.provider` | string | `deepseek` | Initial Claude provider list has only DeepSeek |
| `qoder.models` | string array | one or two real Qoder model names | User-selected models only |
| `qoder.implicit_auto_fallback` | boolean | `true` | Must stay true for MVP |

### Qoder Model Rules

- The user must choose at least one Qoder model.
- The user may choose at most two Qoder models.
- `Auto` is not a valid user-selected model.
- `Auto` is always appended by the runner as the final implicit fallback.
- User selection order is stack-like: every newly selected model is pushed to the front.
- Example sequence:
  - initial fallback: `[Auto]`
  - select `GLM-5.2`: `[GLM-5.2, Auto]`
  - select `Qwen3.7-Max`: `[Qwen3.7-Max, GLM-5.2, Auto]`

The runner should attempt the final sequence from left to right.

## Provider Registry

The configure shell should use a small built-in provider registry for MVP.

```text
Claude providers:
- deepseek
```

DeepSeek provider metadata:

```text
engine: claude-deepseek
settings_file: .github/claude/deepseek-settings.json
required_secret: DEEPSEEK_AUTH_TOKEN
```

Qoder provider metadata:

```text
engine: qoder
settings_file: .github/qoder/settings.json
required_secret: QODER_PERSONAL_ACCESS_TOKEN
model_source: qodercli --list-models
```

Provider registry values are non-secret. They can live in the shell script for MVP. Extract to JSON only when more providers exist.

## Command Contract

### Interactive Menu

```bash
scripts/configure-ai-ci.sh
```

Menu flow:

1. Load existing `.github/ai-review/settings.json`, or default config if missing.
2. Ask whether AI CI is enabled.
3. Ask engine:
   - Claude Code + DeepSeek
   - Qoder
4. If Claude:
   - show provider list
   - allow selecting `deepseek`
   - show required secret name `DEEPSEEK_AUTH_TOKEN`
5. If Qoder:
   - call `qodercli --list-models` when available
   - hide `Auto` from user-selectable model choices
   - let user choose one or two models
   - show final fallback sequence with implicit `Auto`
6. Show affected files and generated JSON.
7. Ask whether to apply.
8. If not applying, exit with dry-run result only.

### Non-interactive Flags

MVP direct flags:

```bash
scripts/configure-ai-ci.sh --dry-run
scripts/configure-ai-ci.sh --apply
scripts/configure-ai-ci.sh --apply --apply-github-vars
scripts/configure-ai-ci.sh --enabled true --engine qoder --qoder-model Qwen3.7-Max --qoder-model GLM-5.2 --apply
scripts/configure-ai-ci.sh --enabled true --engine claude-deepseek --claude-provider deepseek --apply
scripts/configure-ai-ci.sh --enabled false --apply
```

Rules:

- dry-run is default unless `--apply` is present
- direct flags must validate the same rules as the menu
- invalid model count fails before writing files
- unknown provider or engine fails before writing files
- `--apply-github-vars` is invalid unless `--apply` is also present

## GitHub Variable Activation

Default apply writes only local files.

With `--apply-github-vars`, the script may set non-secret repository variables through `gh variable set`.

Allowed variables:

```text
AI_REVIEW_ENGINE
```

Optional informational variable:

```text
AI_REVIEW_CONFIGURED=true
```

`AI_REVIEW_CONFIGURED=true` means the repository has been configured by the helper. It is not the enabled/disabled source of truth.

Do not set a repository variable for on/off as the source of truth. On/off remains controlled by `.github/ai-review/settings.json`.

The direct `--apply-github-vars` path may perform variable updates only when:

- target repo remote can be resolved
- `gh auth status` is usable
- user passed `--apply-github-vars`
- no secret value is requested

Interactive mode may perform the same variable update only after an explicit yes/no prompt.

For secrets, the script may show the required secret name, check whether that secret name exists through `gh secret list`, and optionally call `gh secret set SECRET_NAME` only after explicit user confirmation. The script must not read, print, store, or commit the secret value.

For Git activation, the script may print manual commands or, after explicit confirmation, run the narrow commit/push path described in Apply Semantics.

## Runner Changes

Update `.github/workflows/scripts/ai_review_pr.py`.

### Load Config

Add:

```text
load_ai_review_settings()
resolve_enabled(settings)
resolve_engine(settings)
resolve_claude_provider(settings)
resolve_qoder_model_sequence(settings)
```

### Enabled Behavior

If `enabled` is `false`:

- write `.tmp/ai-review/review.md`
- produce a clear Dogsquard comment or neutral skip body stating AI CI review is disabled by config
- exit `0`

This keeps the workflow behavior visible and avoids fake failure when the user deliberately turns AI CI off.

### Engine Precedence

Recommended runner precedence:

1. workflow-dispatch input env, only when non-empty and explicitly supplied
2. `.github/ai-review/settings.json`
3. legacy `AI_REVIEW_ENGINE` repo variable/env
4. default `claude-deepseek`

The config file is the normal source of truth. Manual dispatch may override for one run.

If `.github/ai-review/settings.json` is missing, the final fallback remains legacy-compatible `claude-deepseek`. Once the configure shell writes the file, the runner should honor the file exactly and should not apply the missing-config fallback over it.

### Qoder Fallback With Invalid Output

Refactor Qoder execution so validation is inside the model loop:

1. build model sequence from settings, then append `Auto`
2. run Qoder with first model
3. if invocation fails with retryable failure, try next model
4. if invocation succeeds but Dogsquard output contract validation fails, try next model
5. if all models fail, write one failure comment listing redacted per-model failure reasons
6. report actual model used when a model succeeds

Invalid output fallback applies only inside Qoder. It must not call Claude.

### Qoder Model Sequence

The final sequence should be generated from `.github/ai-review/settings.json`, not from user-selectable `Auto`.

Example:

```json
{
  "qoder": {
    "models": ["Qwen3.7-Max", "GLM-5.2"],
    "implicit_auto_fallback": true
  }
}
```

Runtime sequence:

```text
Qwen3.7-Max -> GLM-5.2 -> Auto
```

## Workflow Changes

Keep `.github/workflows/ai-pr-review.yml` as the only active AI PR review workflow.

Minimum workflow changes:

- keep existing `workflow_dispatch` input for one-run engine override
- continue passing `AI_REVIEW_ENGINE` for compatibility
- let Python runner read `.github/ai-review/settings.json`
- gate workflow setup steps from the shared runner resolver output, especially `enabled` and `engine`, instead of duplicating final resolution in YAML
- do not add separate Qoder or Claude workflows
- do not remove `PR Quality Gate`

## Shell Implementation Notes

`scripts/configure-ai-ci.sh` should be Bash with small Python snippets only when JSON writing is needed.

Recommended approach:

- Bash handles menu, flags, and command orchestration.
- Python one-liner or here-doc validates and writes JSON atomically.
- Use a temporary file plus `mv` to avoid partial config writes.
- Use `git diff -- .github/ai-review/settings.json .github/qoder/settings.json` to show reviewable changes.

The script should avoid dependencies beyond:

- Bash
- Python 3
- `gh` only when `--apply-github-vars` is used
- `qodercli` only when listing live Qoder models

If `qodercli --list-models` fails, direct Qoder configuration should fail unless a future `--allow-manual-model` flag is explicitly added.

## UAT Plan

Use a throwaway target repository, not Dogsquard itself.

```text
UAT_TARGET_DIR=/path/to/uat-target-repo
UAT_REMOTE_URL=https://github.com/<owner>/<repo>
UAT_REPOSITORY=<owner>/<repo>
```

Known prepared secrets in the target repo:

```text
DEEPSEEK_AUTH_TOKEN
QODER_PERSONAL_ACCESS_TOKEN
```

UAT cases:

1. Configure Qoder enabled with one model.
2. Configure Qoder enabled with two models and implicit `Auto` fallback.
3. Reject Qoder config with zero models.
4. Reject Qoder config with three models.
5. Reject Qoder config if user tries to select `Auto` manually.
6. Configure Claude+DeepSeek and print required `DEEPSEEK_AUTH_TOKEN` without printing secret value.
7. Disable AI CI and verify runner exits successfully with explicit disabled output.
8. Use `--apply-github-vars` and verify only non-secret repo variables are touched.
9. Run a real GitHub Actions PR review with Qoder.
10. Run Claude+DeepSeek if desired; explicit credit/balance failure is acceptable only if visible and non-green.

## Acceptance Criteria

- `scripts/configure-ai-ci.sh --help` documents menu and direct flags.
- Running `scripts/configure-ai-ci.sh` starts an interactive menu.
- Dry-run is default and writes no files.
- `--apply` writes `.github/ai-review/settings.json` atomically.
- AI CI on/off is read from `.github/ai-review/settings.json`.
- Qoder accepts one or two user-selected models and appends implicit `Auto` at runtime.
- Qoder rejects zero models, more than two models, and user-selected `Auto`.
- Qoder retries next model on retryable invocation failure and invalid output contract.
- Claude provider list contains `deepseek` and reports required secret name.
- `--apply-github-vars` is explicit and never handles secret values.
- Interactive GitHub secret setup is explicit, name-only before confirmation, and delegates value input/encryption to `gh secret set`.
- Deterministic `PR Quality Gate` remains unchanged.
- Existing AI review comment marker remains `<!-- dogsquard-ai-code-review -->`.
- No cross-provider fallback is introduced.

## Local Validation Checklist

Before handoff:

```bash
bash -n scripts/configure-ai-ci.sh
python3 -m py_compile .github/workflows/scripts/ai_review_pr.py
python3 -m json.tool .github/ai-review/settings.json >/dev/null
python3 -m json.tool .github/qoder/settings.json >/dev/null
python3 -m json.tool .github/claude/deepseek-settings.json >/dev/null
make doc-check
make doc-guard
git diff --check
```

If config is tested with temporary values, restore intended defaults before handoff.

## Non-goals

- Do not read, print, store, or commit GitHub secret values.
- Do not create separate provider-specific workflows.
- Do not use repository variables as the on/off source of truth.
- Do not delete `PR Quality Gate` when disabling AI CI.
- Do not support partial provider installation here; that belongs to the install script feature.
