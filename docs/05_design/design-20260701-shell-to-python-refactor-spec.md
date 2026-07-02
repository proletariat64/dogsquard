---
title: "Shell-to-Python Refactor Spec"
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

# Shell-to-Python Refactor Spec

## Source Requirement

[[docs/02_prd/prd-20260701-install-scripts.md]]
[[docs/05_design/design-20260701-install-shell-spec.md]]
[[docs/05_design/design-20260701-ai-ci-configure-shell-spec.md]]

## Current Code Baseline

```text
scripts/install.sh              — 1541 lines, ~40 functions
scripts/configure-ai-ci.sh      — 602 lines, ~18 functions
scripts/test-install.sh         — 314 lines, 20 test cases
scripts/test-configure-ai-ci.sh — 216 lines, 3 test cases
install                         — 4-line root shim
Makefile                        — install-test, ai-review-test targets
```

## Settled Decisions

### 1. Follow ai_review_pr.py conventions
- stdlib only (json, os, re, subprocess, sys, pathlib, hashlib, shutil, tempfile, typing)
- No argparse — hand-rolled CLI dispatch in `main(argv) -> int`
- Custom exception class per module
- `log()` to stderr, stdout reserved for structured output
- Exit codes: 0 success, 1 runtime failure, 2 bad arguments
- `pathlib.Path` for all file operations
- PEP 604 type hints (`str | None`, `dict[str, Any]`)

### 2. No third-party dependencies
- Zero pip installs required
- All functionality via Python stdlib

### 3. Preserve CLI contracts exactly
- Same flags, same output messages, same exit codes
- Shell tests must continue to pass during transition
- Root `install` shim updated to call `python3 scripts/install.py`

### 4. Subprocess for external tools only
- `subprocess.run` for: git, gh, qodercli, bootstrap-project.sh, make, bash -n
- No `shell=True`
- Centralized `run_capture()` helper matching ai_review_pr.py pattern

### 5. Atomic file writes
- `tempfile.NamedTemporaryFile` + `os.replace` for settings.json and manifest

### 6. Secret redaction
- Port `redact_known_secrets()` from ai_review_pr.py
- Apply to all log output and user-facing strings

### 7. Keep shell scripts as deprecated references
- Do not delete install.sh or configure-ai-ci.sh
- Add deprecation comment at top of each

## New File Layout

```text
Add:    scripts/install.py
Add:    scripts/configure_ai_ci.py
Add:    tests/test_install.py
Add:    tests/test_configure_ai_ci.py
Add:    docs/05_design/design-20260701-shell-to-python-refactor-spec.md
Modify: install (root shim)
Modify: Makefile
```

## Command Contract

### Root Shim (install)
```bash
#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$script_dir/scripts/install.py" "$@"
```

### install.py CLI
```bash
./install --help
./install --menu
./install --config FILE --repo PATH --project-type TYPE --modules LIST
./install --apply --force --run-checks --commit-push
./install --uninstall --apply
```

### configure_ai_ci.py CLI
```bash
python3 scripts/configure_ai_ci.py --help
python3 scripts/configure_ai_ci.py --apply --enabled true --engine qoder --qoder-model MODEL
python3 scripts/configure_ai_ci.py --dry-run
python3 scripts/configure_ai_ci.py --apply-github-vars
```

## Module Architecture

### configure_ai_ci.py

```python
class ConfigureFailure(Exception): ...

def log(message: str) -> None: ...
def run_capture(cmd, ...) -> tuple[int, str, str]: ...
def load_settings(path: Path) -> dict[str, Any]: ...
def write_settings_atomic(path: Path, data: dict[str, Any]) -> None: ...
def list_qoder_models() -> list[str]: ...
def toggle_model(models: list[str], candidate: str) -> list[str]: ...
def select_models_interactively(available: list[str], selected: list[str]) -> list[str]: ...
def validate_models(models: list[str], available: list[str]) -> None: ...
def apply_github_variables(engine: str) -> None: ...
def commit_and_push(settings_file: Path) -> None: ...
def interactive_menu(current: dict) -> dict: ...
def parse_cli(argv: list[str]) -> dict: ...
def main(argv: list[str] | None = None) -> int: ...
```

### install.py

```python
class InstallFailure(Exception): ...

def log(message: str) -> None: ...
def run_capture(cmd, ...) -> tuple[int, str, str]: ...
def file_sha256(path: Path) -> str | None: ...
def backup_file(target: Path, relative: str, timestamp: str) -> Path: ...
def ledger_entry(ledger_file: Path, ...) -> None: ...
def parse_config_file(path: Path) -> dict: ...
def parse_cli_flags(argv: list[str]) -> dict: ...
def merge_config(cli: dict, config: dict) -> dict: ...
def validate_inputs(state: dict) -> None: ...
def build_plan(state: dict) -> list[dict]: ...
def apply_bootstrap(state: dict, ledger_file: Path) -> None: ...
def apply_ai_pr_review(state: dict, ledger_file: Path) -> None: ...
def write_manifest(state: dict, ledger_file: Path) -> None: ...
def run_validation(target: Path) -> bool: ...
def commit_and_push(target: Path, ledger_file: Path) -> None: ...
def run_uninstall(target: Path, apply: bool) -> None: ...
def interactive_menu(state: dict) -> dict: ...
def main(argv: list[str] | None = None) -> int: ...
```

## Data Structures (unchanged from shell spec)

### Ledger Entry (JSONL)
```json
{
  "tool": "install.py",
  "module": "ai-pr-review",
  "operation": "copy_file",
  "action": "created",
  "path": ".github/ai-review/settings.json",
  "source": ".github/ai-review/settings.json",
  "existed_before": false,
  "force": false,
  "dry_run": false,
  "sha256_before": null,
  "sha256_after": "abc123...",
  "backup_path": null
}
```

### Manifest (JSON)
```json
{
  "schema_version": "1",
  "installed_at": "2026-...",
  "dogsquard_source": {"path": "...", "git_commit": "..."},
  "target": {"path": "...", "git_remote_origin": "...", "git_branch": "..."},
  "project_type": "node",
  "modules": ["governance", "pr-quality"],
  "options": {"force": false, "run_checks": false, "commit_push": false},
  "ai_review": {"configured": true, "enabled": true, "engine": "qoder", "qoder_models": ["Qwen3.7-Max"], "apply_github_vars": false},
  "files": [...],
  "directories": [...],
  "validation": {"run_checks": true, "commands": []}
}
```

### Settings (JSON)
```json
{
  "enabled": true,
  "engine": "qoder",
  "claude": {"provider": "deepseek"},
  "qoder": {"models": ["Qwen3.7-Max"], "implicit_auto_fallback": true}
}
```

## Test Plan

### test_configure_ai_ci.py (3+ cases)
1. Max-two model enforcement with interactive toggle
2. Model toggle ordering (stack-like push-to-front)
3. Secret handoff (no secret value in stdout/stderr)

### test_install.py (20 cases)
1. --help exits 0
2. Unknown flag fails
3. Unknown config key rejected
4. Dry-run writes nothing
5. Interactive tilde expansion
6. docs-only apply creates expected files
7. node dry-run
8. go-js dry-run
9. Existing file skip
10. Force overwrite with backup
11. Uninstall dry-run
12. Uninstall apply
13. Uninstall without manifest
14. ai-pr-review module copies correct files
15. ai-pr-review disabled safe config
16. Existing settings preserved
17. AI configure pass-through
18. Interactive Qoder model selection
19. Qoder model validation
20. --ai-apply-github-vars without --apply
21. Secret value rejection
22. --commit-push on main fails

## Local Validation Checklist

```bash
python3 -m py_compile scripts/install.py
python3 -m py_compile scripts/configure_ai_ci.py
python3 -m unittest tests/test_configure_ai_ci.py -v
python3 -m unittest tests/test_install.py -v
make release-check
```

## Acceptance Criteria

- All CLI flags produce identical behavior to shell versions
- All 20 + 3 test cases pass in Python
- `make release-check` passes with Python scripts
- Shell scripts marked deprecated but not deleted
- Zero third-party dependencies
- Secret values never appear in any output

## Non-goals

- Rewriting bootstrap-project.sh (remains shell)
- Adding pyproject.toml or package structure
- Supporting Windows (Linux/macOS only)
- Changing manifest or ledger schemas
