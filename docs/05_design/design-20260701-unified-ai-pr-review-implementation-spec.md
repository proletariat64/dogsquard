---
title: "Unified AI PR Review Implementation Spec"
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

# Unified AI PR Review Implementation Spec

## Source Requirement

Primary PRD: `docs/02_prd/prd-20260701-unified-ai-pr-review-ci.md`

This implementation spec turns the PRD into a buildable plan for one Dogsquard AI PR review workflow with two selectable providers:

- `claude-deepseek`
- `qoder`

## Implementation Decision

Keep one active workflow:

```text
.github/workflows/ai-pr-review.yml
```

Move the review logic into one Python runner:

```text
.github/workflows/scripts/ai_review_pr.py
```

Move prompt text out of workflow YAML:

```text
.github/workflows/prompts/pr-review-policy.md
.github/workflows/prompts/pr-review-output-contract.md
```

Keep one provider configuration home per provider:

```text
.github/claude/deepseek-settings.json
.github/qoder/settings.json
```

After the unified runner is in place, remove or fold the separate Qoder scaffold:

```text
.github/workflows/qoder-pr-review.yml
.github/workflows/qoder-pr-review/
```

## Review Authority Contract

Dogsquard keeps the existing AI review position:

- AI review is an advisory PR comment.
- AI model verdict does not approve, reject, or block a PR.
- `PR Quality Gate` remains the deterministic merge authority.
- The AI review job may fail only when the selected provider or runner cannot produce a valid review comment.

This means:

| Condition | AI comment | AI job result | Merge authority |
|---|---|---|---|
| Valid `PASS` review | posted | success | `PR Quality Gate` |
| Valid `NEEDS_ATTENTION` review | posted | success | `PR Quality Gate` |
| Valid `HIGH_RISK` review | posted | success | `PR Quality Gate` |
| Valid safe-file `SKIP` | posted | success | `PR Quality Gate` |
| Missing secret | failure comment if possible | fail | `PR Quality Gate` still separate |
| Empty diff | failure comment if possible | fail | `PR Quality Gate` still separate |
| Provider timeout/failure | failure comment if possible | fail | `PR Quality Gate` still separate |
| Invalid provider output | failure comment if possible | fail | `PR Quality Gate` still separate |

## Engine Selection Contract

Supported values:

```text
claude-deepseek
qoder
```

Selection precedence:

1. `workflow_dispatch` input `ai_review_engine`
2. repository variable `AI_REVIEW_ENGINE`
3. default `claude-deepseek`

Rules:

- The engine is single-select per run.
- Invalid engine value fails before provider invocation.
- There is no cross-provider fallback.
- Qoder failure must not call Claude.
- Claude failure must not call Qoder.

## Provider Configuration Contract

### Claude plus DeepSeek

Committed config:

```text
.github/claude/deepseek-settings.json
```

Workflow/runtime env should provide only runtime values:

```text
GITHUB_TOKEN
PR_NUMBER
ANTHROPIC_AUTH_TOKEN=${{ secrets.DEEPSEEK_AUTH_TOKEN }}
AI_REVIEW_ENGINE
```

Workflow YAML must not duplicate non-secret provider settings already present in `deepseek-settings.json`, such as:

```text
ANTHROPIC_BASE_URL
ANTHROPIC_MODEL
ANTHROPIC_DEFAULT_OPUS_MODEL
ANTHROPIC_DEFAULT_SONNET_MODEL
ANTHROPIC_DEFAULT_HAIKU_MODEL
ENABLE_TOOL_SEARCH
```

Claude invocation should use the settings file:

```bash
npx -y @anthropic-ai/claude-code \
  -p \
  --settings .github/claude/deepseek-settings.json \
  < .tmp/ai-review/prompt.md \
  > .tmp/ai-review/provider-output.md
```

Do not repeat `--model opus` if the model is already controlled by `deepseek-settings.json`.

### Qoder

Committed placeholder config:

```text
.github/qoder/settings.json
```

Runtime env should provide credentials and runtime inputs only:

```text
GITHUB_TOKEN
GH_TOKEN
PR_NUMBER
QODER_PERSONAL_ACCESS_TOKEN
AI_REVIEW_ENGINE
```

Qoder installation remains conditional on `AI_REVIEW_ENGINE == qoder`.

Qoder version must be explicit and checked after install:

```text
QODERCLI_VERSION
qodercli --version == QODERCLI_VERSION
```

No Qoder secret belongs in `.github/qoder/settings.json`.

## File Layout Target

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

Keep existing repo-level local files out of scope:

```text
AGENTS.md
CLAUDE.md
roster.md
```

These are currently local/untracked and must not become committed review policy by accident.

## Workflow Spec

`ai-pr-review.yml` should:

1. trigger on PR open/synchronize/reopen/ready-for-review and manual dispatch
2. expose optional manual `ai_review_engine` choice
3. set `AI_REVIEW_ENGINE` by input -> repo var -> default
4. checkout with `fetch-depth: 0`
5. setup Node because both Claude Code and Qoder CLI are Node-based
6. conditionally restore/install/cache `qodercli` only for Qoder runs
7. run `.github/workflows/scripts/ai_review_pr.py`
8. always upsert the Dogsquard PR comment if the runner produced `.tmp/ai-review/review.md`
9. fail the job when the runner exits non-zero

The workflow should keep the stable comment marker:

```text
<!-- dogsquard-ai-code-review -->
```

## Python Runner Spec

Path:

```text
.github/workflows/scripts/ai_review_pr.py
```

Responsibilities:

1. validate inputs and engine
2. collect PR metadata
3. collect changed file list
4. collect PR patch
5. fail if the changed file list or patch is unexpectedly empty
6. apply safe-file skip policy before provider invocation
7. build one Dogsquard prompt from shared prompt files plus PR context
8. invoke exactly one selected provider
9. validate provider output shape
10. normalize final comment to Dogsquard output format
11. redact known secrets from comments and logs
12. write `.tmp/ai-review/review.md`
13. return `0` for valid advisory comments, including `HIGH_RISK`
14. return non-zero for runner/provider failures

Recommended internal modules/functions:

```text
main()
load_config()
resolve_engine()
validate_env()
collect_pr_context()
changed_files()
should_skip_review()
build_prompt()
run_claude_deepseek()
run_qoder()
validate_review_output()
normalize_review_comment()
failure_comment()
redact_known_secrets()
```

## PR Context Contract

The runner should collect:

```text
number
title
body
baseRefName
headRefName
author
additions
deletions
changedFiles
url
changed file list
patch
```

Preferred source:

```bash
gh pr view "$PR_NUMBER" --json ...
gh pr diff "$PR_NUMBER" --patch
gh pr diff "$PR_NUMBER" --name-only
```

Fallback to `git diff origin/<base>...HEAD` is acceptable only if PR metadata is still present and the diff is non-empty.

## Safe File Skip Policy

The runner may skip provider invocation only when every changed file is a safe binary/document asset.

Safe skip extensions:

```text
png, jpg, jpeg, gif, webp, ico, bmp, tif, tiff
pdf
mp3, wav, mp4, mov, webm
woff, woff2, ttf, otf
```

Never skip:

```text
svg
archives such as zip, tar, tgz, gz, 7z, rar
source files
config files
workflow files
scripts
markdown docs
lockfiles
dependency manifests
AGENTS.md
CLAUDE.md
```

Skip output is a valid Dogsquard advisory comment and exits `0`.

## Prompt Files Spec

### `pr-review-policy.md`

Must preserve Dogsquard-first review focus:

- Dogsquard is a reusable bootstrap kit, not the business product.
- Review correctness, shell safety, GitHub Actions safety, secrets safety, CI risk, and Dogsquard template boundary violations.
- Do not invent files or behavior not present in the diff.
- Do not approve, reject, or block the PR.
- CI remains the merge gate.

Add useful Qoder-derived checks:

- security-sensitive input, token, cookie, key, and log handling
- failure paths must not report success
- provider/tool failure must be visible
- acceptance check against PR intent
- binary/document skip check

### `pr-review-output-contract.md`

Required output shape:

```markdown
## 🤖 Dogsquard AI Code Review

<!-- dogsquard-ai-code-review -->

### Verdict
PASS / NEEDS_ATTENTION / HIGH_RISK / SKIP

### What changed
- ...

### Must fix
- None.

### Should consider
- None.

### Test gaps
- None.

### Acceptance check
- ...

### File-skip check
- Skip used: yes/no.
- Reason: ...

### Dogsquard boundary check
- ...

### Engine details
- Engine: claude-deepseek / qoder
- Model: known value or unknown
```

Verdict rules:

- `PASS`: no concrete issue found
- `NEEDS_ATTENTION`: non-blocking concerns or gaps worth human attention
- `HIGH_RISK`: concrete correctness/security/CI/template-boundary risk found
- `SKIP`: provider invocation skipped because all changed files are safe binary/document assets

All verdicts are advisory by model judgment. They do not replace `PR Quality Gate`.

## Comment Upsert Contract

Use the existing Dogsquard comment marker:

```text
<!-- dogsquard-ai-code-review -->
```

Preferred implementation:

- Keep using `scripts/upsert-pr-comment.sh` unless the Python runner needs native API posting for failure-path reliability.
- The runner must always write `.tmp/ai-review/review.md` before returning non-zero when possible.
- The workflow comment step should use `if: always()` so provider failures still update the PR comment.

## Failure Comment Contract

Failure comments must be Dogsquard-branded and concise:

```markdown
## 🤖 Dogsquard AI Code Review

<!-- dogsquard-ai-code-review -->

### Verdict
NEEDS_ATTENTION

### What changed
- AI review could not complete.

### Must fix
- Selected provider failed before a valid review was produced: <redacted reason>.

### Should consider
- Check provider secret, selected engine, CLI installation, and PR diff availability.

### Test gaps
- AI review was not completed for this run.

### Acceptance check
- Not evaluated because AI review failed before completion.

### File-skip check
- Skip used: no.

### Dogsquard boundary check
- Not evaluated because AI review failed before completion.

### Engine details
- Engine: <selected engine>
- Model: unknown
```

The failure comment is advisory text, but the AI review job exits non-zero because the review process failed.

## Migration Plan

### Phase 1: Extract Existing Prompt

- Create `pr-review-policy.md` from the current inline Dogsquard prompt.
- Create `pr-review-output-contract.md` with the unified output format.
- Keep the existing workflow behavior while moving prompt text out of YAML.

Verification:

```bash
make doc-check
bash -n scripts/upsert-pr-comment.sh
```

### Phase 2: Add Unified Runner For Current Claude Path

- Add `.github/workflows/scripts/ai_review_pr.py`.
- Move PR context collection from YAML into Python.
- Keep `claude-deepseek` as default.
- Remove duplicated Claude/DeepSeek non-secret env from `ai-pr-review.yml`.
- Use `.github/claude/deepseek-settings.json` as the single Claude provider settings source.

Verification:

```bash
python3 -m py_compile .github/workflows/scripts/ai_review_pr.py
make doc-check
bash -n scripts/upsert-pr-comment.sh
```

### Phase 3: Fold Qoder Provider Into The Runner

- Add Qoder provider invocation behind `AI_REVIEW_ENGINE=qoder`.
- Add conditional Qoder CLI install/cache/version-check in the workflow.
- Use `.github/qoder/settings.json` as the future non-secret Qoder config home.
- Preserve the Dogsquard output contract and comment marker.
- Remove cross-provider fallback logic.

Verification:

```bash
python3 -m py_compile .github/workflows/scripts/ai_review_pr.py
python3 -m json.tool .github/qoder/settings.json >/dev/null
make doc-check
```

### Phase 4: Remove Separate Qoder Scaffold

- Delete `.github/workflows/qoder-pr-review.yml` after equivalent behavior exists in the unified workflow.
- Delete `.github/workflows/qoder-pr-review/` after its useful policy and skip rules are represented in the shared prompt/runner.
- Confirm no separate Qoder comment marker remains.

Verification:

```bash
rg "qoder-pr-review:v1|Qoder PR Review" .github docs
make doc-check
```

### Phase 5: CI Trial

- Open or update a PR using the default `claude-deepseek` engine.
- Confirm one Dogsquard AI review comment is created or updated.
- Manually dispatch the workflow with `ai_review_engine=qoder` after Qoder secret and CLI install are ready.
- Confirm Qoder uses the same Dogsquard comment marker and output contract.

Success criteria:

- one active AI PR review workflow
- one Dogsquard comment marker
- no duplicated Claude/DeepSeek non-secret env in YAML
- no provider fallback
- no fake-green AI review when provider output is missing or invalid

## Local Validation Checklist

Before handoff:

```bash
python3 -m py_compile .github/workflows/scripts/ai_review_pr.py
python3 -m json.tool .github/qoder/settings.json >/dev/null
bash -n scripts/upsert-pr-comment.sh
make doc-check
make doc-guard
git diff --check
```

If `make doc-check` fails because of unrelated pre-existing untracked docs, report the unrelated file separately and do not hide it by changing scope.

## Open Implementation Choices

These choices can be finalized during coding without changing the PRD:

1. Whether Python posts comments directly or keeps `scripts/upsert-pr-comment.sh` as the comment writer.
2. Whether local dry-run fixtures are implemented as a script flag or a small test file.
3. Whether Qoder model selection is fixed through `settings.json` or discovered dynamically once the config schema is known.

Hard constraints that must not change:

- Dogsquard marker stays `<!-- dogsquard-ai-code-review -->`.
- Provider is single-select; no fallback.
- AI model verdict is advisory.
- Provider/runner failure is visible and fails the AI review job.
- `PR Quality Gate` remains the deterministic merge authority.
