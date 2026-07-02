#!/usr/bin/env python3
import hashlib
import json
import os
import py_compile
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any

# Constants
ROOT_DIR = Path(__file__).resolve().parent.parent
TIMESTAMP = datetime.now().strftime("%Y%m%dT%H%M%S")
ALLOWED_MODULES = (
    "governance", "pr-quality", "dev-deploy",
    "example-app", "production-profile", "ai-pr-review",
)
ALLOWED_CONFIG_KEYS = {
    "TARGET_DIR", "PROJECT_TYPE", "MODULES",
    "AI_REVIEW_ENABLED", "AI_REVIEW_ENGINE", "QODER_MODELS",
    "AI_REVIEW_APPLY_GITHUB_VARS", "RUN_CHECKS", "COMMIT_PUSH",
    "FORCE", "UNINSTALL",
}
AI_MODULE_FILES = (
    ".github/workflows/ai-pr-review.yml",
    ".github/workflows/scripts/ai_review_pr.py",
    ".github/workflows/prompts/pr-review-policy.md",
    ".github/workflows/prompts/pr-review-output-contract.md",
    ".github/claude/deepseek-settings.json",
    ".github/qoder/settings.json",
    "scripts/configure-ai-ci.sh",
    "scripts/upsert-pr-comment.sh",
)
AI_EXECUTABLE_FILES = ("scripts/configure-ai-ci.sh", "scripts/upsert-pr-comment.sh")
DISABLED_SAFE_CONFIG = {
    "enabled": False, "engine": "claude-deepseek",
    "claude": {"provider": "deepseek"},
    "qoder": {"models": ["Qwen3.7-Max"], "implicit_auto_fallback": True},
}
SECRET_PATTERN = re.compile(r"(sk_|secret|password|token=|ghp_|glpat-|pat-)", re.IGNORECASE)
USAGE_TEXT = """\
Usage:
  install.py                                   Interactive menu mode
  install.py --menu                            Interactive menu mode
  install.py --help                            Show this help
  install.py --uninstall --repo <target>       Uninstall dry-run
  install.py --uninstall --repo <target> --apply  Uninstall apply

Non-interactive install:
  install.py --repo <target> --project-type <type> --modules <list> [--apply]

Options:
  --help                  Show this help and exit.
  --menu                  Run interactive menu mode.
  --config FILE           Read non-secret KEY=value config file.
  --repo PATH             Target repository path.
  --project-type TYPE     Project type: node, go-js, docs-only.
  --modules LIST          Comma-separated modules: governance, pr-quality,
                          dev-deploy, example-app, production-profile, ai-pr-review.
  --apply                 Write files to target. Default is dry-run.
  --force                 Overwrite existing target files with backup.
  --run-checks            Run validation after apply.
  --no-run-checks         Skip validation after apply.
  --commit-push           Stage, commit, and push target changes after validation.
  --uninstall             Remove all Dogsquard-managed assets from target.

AI PR Review pass-through flags:
  --ai-enabled true|false     Enable or disable AI review.
  --ai-engine ENGINE          claude-deepseek or qoder.
  --qoder-model NAME          Add one Qoder model. Repeat at most twice.
  --ai-apply-github-vars      With --apply, sync non-secret GitHub variables.

Config file:
  Simple KEY=value format. Allowed keys:
    TARGET_DIR, PROJECT_TYPE, MODULES, AI_REVIEW_ENABLED, AI_REVIEW_ENGINE,
    QODER_MODELS, AI_REVIEW_APPLY_GITHUB_VARS, RUN_CHECKS, COMMIT_PUSH,
    FORCE, UNINSTALL
  Unknown keys fail fast. CLI flags override config values.
  Secret values are rejected. Comments (#) and empty lines are allowed.

Behavior:
  - Dry-run is default. Use --apply or menu confirmation to write files.
  - Existing target files are preserved unless --force is set.
  - Overwritten files are backed up to .dogsquard/backups/ before modification.
  - Install writes .dogsquard/install-manifest.json for uninstall.
  - Uninstall is all-or-nothing; no module selection.
  - Uninstall without manifest fails safely."""


# Exception and helpers

class InstallFailure(Exception):
    pass

def log(message: str) -> None:
    print(message, file=sys.stderr)

def fail(message: str) -> None:
    raise InstallFailure(message)

def bad_arg(message: str) -> None:
    log(f"FAIL: {message}")
    raise SystemExit(2)

def warn(message: str) -> None:
    log(f"WARN: {message}")

def validate_bool(name: str, value: str) -> None:
    if value not in ("true", "false"):
        bad_arg(f"{name} must be true or false.")

def file_sha256(path: Path) -> str | None:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None

def run_capture(cmd: list[str] | str, *, input_text: str | None = None,
                 timeout_seconds: int | None = None, env: dict[str, str] | None = None,
                 cwd: Path | None = None) -> tuple[int, str, str]:
    try:
        p = subprocess.run(cmd, input=input_text, capture_output=True, text=True,
                           timeout=timeout_seconds, env=env, cwd=cwd, shell=isinstance(cmd, str))
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return 1, "", "command timed out"
    except FileNotFoundError:
        return 1, "", f"command not found: {cmd[0] if isinstance(cmd, list) else cmd}"

def _read_input(prompt: str) -> str:
    try:
        return input(prompt)
    except (EOFError, KeyboardInterrupt):
        log("")
        fail("input required")
        return ""

def prompt_yes_no(prompt: str, default: str) -> bool:
    a = (_read_input(f"{prompt} [{default}]: ") or default).strip().lower()
    if a in ("y", "yes", "true"):
        return True
    if a in ("n", "no", "false"):
        return False
    bad_arg("expected yes or no")
    return False

def prompt_choice(prompt: str, default: str) -> str:
    return (_read_input(f"{prompt} [{default}]: ") or default).strip()

def expand_user_path(path_str: str) -> str:
    if path_str == "~" or path_str.startswith("~/"):
        home = os.environ.get("HOME", "")
        if not home:
            fail("HOME is required to expand ~ in path.")
        return home if path_str == "~" else os.path.join(home, path_str[2:])
    return path_str


def list_qoder_models() -> list[str]:
    result = subprocess.run(
        ["qodercli", "--list-models"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        fail("qodercli --list-models failed; qodercli is required to list Qoder models.")
    models = []
    for line in result.stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.upper() == "MODEL":
            continue
        if stripped.lower() == "auto":
            continue
        models.append(stripped)
    if not models:
        fail("qodercli --list-models returned no selectable models.")
    return models


def select_qoder_models_interactively(s: "InstallState") -> None:
    available = list_qoder_models()
    s.qoder_models = []
    while True:
        slots_left = 2 - len(s.qoder_models)
        log(f"\nAvailable Qoder models ({slots_left} available model slots left):")
        for i, model in enumerate(available):
            mark = "x" if model in s.qoder_models else " "
            log(f"  {i + 1:2d}) [{mark}] {model}")
        log("Enter a number to toggle a model. Press Enter or type done to continue.")
        answer = _read_input("Qoder model selection: ").strip()
        if not answer or answer.lower() == "done":
            if len(s.qoder_models) < 1:
                log("Select at least one Qoder model before continuing.")
                continue
            break
        if not answer.isdigit():
            log("Enter a model number, press Enter, or type done.")
            continue
        num = int(answer)
        if num < 1 or num > len(available):
            log("Model number out of range.")
            continue
        model = available[num - 1]
        if model in s.qoder_models:
            s.qoder_models.remove(model)
        else:
            if len(s.qoder_models) >= 2:
                log("No Qoder model slots left. Uncheck one model before selecting another.")
                continue
            s.qoder_models.append(model)


def _resolve_backup(target: Path, backup: str) -> Path:
    return Path(backup) if os.path.isabs(backup) else target / backup.lstrip("./")

def _git_out(cmd: list[str], cwd: Path) -> str:
    c, o, _ = run_capture(cmd, cwd=cwd)
    return o.strip() if c == 0 else ""

def print_ai_secret_names(engine: str) -> None:
    if engine == "claude-deepseek":
        log("\nRequired secret: DEEPSEEK_AUTH_TOKEN")
    elif engine == "qoder":
        log("\nRequired secret: QODER_PERSONAL_ACCESS_TOKEN")
    else:
        log("\nRequired secrets by engine:\n  claude-deepseek: DEEPSEEK_AUTH_TOKEN\n  qoder:           QODER_PERSONAL_ACCESS_TOKEN")


# Config file parser

def parse_config_file(file_path: Path) -> dict[str, str]:
    if not file_path.is_file():
        bad_arg(f"config file not found: {file_path}")
    config: dict[str, str] = {}
    seen: set[str] = set()
    for ln, raw in enumerate(file_path.read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^\s*([^=]+?)\s*=\s*(.*?)\s*$", line)
        if not m:
            bad_arg(f"invalid config syntax at line {ln}: {line}")
        key, value = m.group(1).strip(), m.group(2).strip()
        if key not in ALLOWED_CONFIG_KEYS:
            bad_arg(f"unknown config key at line {ln}: {key}")
        if key in seen:
            bad_arg(f"duplicate config key at line {ln}: {key}")
        seen.add(key)
        if SECRET_PATTERN.search(value.lower()):
            bad_arg(f"config value at line {ln} looks like a secret. Config files must not contain secret values.")
        config[key] = value
    return config


# State

class InstallState:
    def __init__(self) -> None:
        self.mode_install = True
        self.interactive = False
        self.apply = False
        self.force = False
        self.run_checks = False
        self.commit_push = False
        self.uninstall = False
        self.config_file = ""
        self.target_dir = ""
        self.project_type = ""
        self.modules: list[str] = []
        self.ai_enabled = ""
        self.ai_engine = ""
        self.ai_apply_github_vars = False
        self.qoder_models: list[str] = []
        self.config: dict[str, str] = {}
        self.cli_target_dir = False
        self.cli_project_type = False
        self.cli_modules = False
        self.cli_ai_enabled = False
        self.cli_ai_engine = False
        self.cli_ai_apply_github_vars = False
        self.cli_run_checks = False
        self.cli_commit_push = False
        self.cli_force = False
        self.cli_uninstall = False
        self.qoder_models_from_cli: list[str] = []
        self.ledger_file: Path | None = None
        self.validation_succeeded = False


# CLI parser

def parse_cli_flags(s: InstallState, args: list[str]) -> None:
    i = 0
    while i < len(args):
        a = args[i]
        def _nxt(label: str) -> str:
            nonlocal i
            if i + 1 >= len(args):
                bad_arg(f"{label} requires a value")
            i += 1
            return args[i]
        if a in ("--help", "-h"):
            log(USAGE_TEXT)
            raise SystemExit(0)
        elif a == "--menu":       s.interactive = True
        elif a == "--config":     s.config_file = _nxt("--config")
        elif a == "--repo":       s.target_dir = _nxt("--repo"); s.cli_target_dir = True
        elif a == "--project-type": s.project_type = _nxt("--project-type"); s.cli_project_type = True
        elif a == "--modules":    s.modules = [m.strip() for m in _nxt("--modules").split(",") if m.strip()]; s.cli_modules = True
        elif a == "--ai-enabled": s.ai_enabled = _nxt("--ai-enabled"); s.cli_ai_enabled = True
        elif a == "--ai-engine":  s.ai_engine = _nxt("--ai-engine"); s.cli_ai_engine = True
        elif a == "--qoder-model":
            mdl = _nxt("--qoder-model"); s.qoder_models_from_cli.append(mdl); s.qoder_models.append(mdl)
        elif a == "--ai-apply-github-vars": s.ai_apply_github_vars = True; s.cli_ai_apply_github_vars = True
        elif a == "--apply":      s.apply = True
        elif a == "--force":      s.force = True; s.cli_force = True
        elif a == "--run-checks": s.run_checks = True; s.cli_run_checks = True
        elif a == "--no-run-checks": s.run_checks = False; s.cli_run_checks = True
        elif a == "--commit-push": s.commit_push = True; s.cli_commit_push = True
        elif a == "--uninstall":  s.uninstall = True; s.mode_install = False; s.cli_uninstall = True
        else:
            bad_arg(f"unknown argument: {a}")
        i += 1


# Merge config + CLI (CLI wins)

def merge_config(s: InstallState) -> None:
    c = s.config
    if not c:
        return
    if "TARGET_DIR" in c and not s.cli_target_dir:
        s.target_dir = c["TARGET_DIR"]
    if "PROJECT_TYPE" in c and not s.cli_project_type:
        s.project_type = c["PROJECT_TYPE"]
    if "MODULES" in c and not s.cli_modules:
        s.modules = [m.strip() for m in c["MODULES"].split(",") if m.strip()]
    if "AI_REVIEW_ENABLED" in c and not s.cli_ai_enabled:
        s.ai_enabled = c["AI_REVIEW_ENABLED"]
    if "AI_REVIEW_ENGINE" in c and not s.cli_ai_engine:
        s.ai_engine = c["AI_REVIEW_ENGINE"]
    if "QODER_MODELS" in c and not s.qoder_models_from_cli:
        s.qoder_models = [m.strip() for m in c["QODER_MODELS"].split(",") if m.strip()]
    if "AI_REVIEW_APPLY_GITHUB_VARS" in c and not s.cli_ai_apply_github_vars:
        s.ai_apply_github_vars = c["AI_REVIEW_APPLY_GITHUB_VARS"] == "true"
    if "RUN_CHECKS" in c and not s.cli_run_checks:
        s.run_checks = c["RUN_CHECKS"] == "true"
    if "COMMIT_PUSH" in c and not s.cli_commit_push:
        s.commit_push = c["COMMIT_PUSH"] == "true"
    if "FORCE" in c and not s.cli_force:
        s.force = c["FORCE"] == "true"
    if "UNINSTALL" in c and not s.cli_uninstall and c["UNINSTALL"] == "true":
        s.uninstall = True; s.mode_install = False


# Input validation

def validate_ai_inputs(s: InstallState) -> None:
    if s.ai_enabled:
        validate_bool("AI_REVIEW_ENABLED", s.ai_enabled)
    if s.ai_engine and s.ai_engine not in ("claude-deepseek", "qoder"):
        bad_arg("AI_REVIEW_ENGINE must be claude-deepseek or qoder.")
    if s.ai_engine == "qoder":
        if len(s.qoder_models) < 1:
            bad_arg("AI_REVIEW_ENGINE=qoder requires at least one --qoder-model.")
        if len(s.qoder_models) > 2:
            bad_arg("Qoder allows at most two --qoder-model values.")
        for m in s.qoder_models:
            if not m:
                bad_arg("Qoder model cannot be empty.")
            if m.lower() == "auto":
                bad_arg("Auto is an implicit runner fallback and cannot be user-selected.")
        if len(s.qoder_models) == 2 and s.qoder_models[0] == s.qoder_models[1]:
            bad_arg("Qoder models must be unique.")
    if s.ai_engine == "claude-deepseek" and s.qoder_models:
        bad_arg("AI_REVIEW_ENGINE=claude-deepseek must not include --qoder-model values.")

def validate_inputs(s: InstallState) -> None:
    if s.mode_install:
        if not s.target_dir:
            bad_arg("--repo is required for install mode.")
        if not s.project_type:
            bad_arg("--project-type is required for install mode.")
        if s.project_type not in ("node", "go-js", "docs-only"):
            bad_arg("PROJECT_TYPE must be node, go-js, or docs-only.")
        if not s.modules:
            bad_arg("--modules is required for install mode.")
        has_base = any(m in ("governance", "pr-quality") for m in s.modules)
        for mod in s.modules:
            if mod not in ALLOWED_MODULES:
                bad_arg(f"unknown module: {mod}")
            if mod in ("dev-deploy", "example-app", "production-profile") and not has_base:
                bad_arg(f"module '{mod}' requires governance or pr-quality (bootstrap base required in MVP).")
        if s.ai_apply_github_vars and not s.apply:
            bad_arg("--ai-apply-github-vars requires --apply.")
        if "ai-pr-review" in s.modules:
            validate_ai_inputs(s)
    if s.target_dir:
        s.target_dir = expand_user_path(s.target_dir)
        tp = Path(s.target_dir)
        if tp.is_dir():
            s.target_dir = str(tp.resolve())
        elif s.mode_install:
            bad_arg(f"target directory does not exist: {s.target_dir}")
        if s.target_dir == str(ROOT_DIR):
            bad_arg("target directory must not be the Dogsquard repository itself.")
    if s.uninstall:
        if not s.target_dir:
            bad_arg("--repo is required for uninstall mode.")
        if not Path(s.target_dir).is_dir():
            bad_arg(f"target directory does not exist: {s.target_dir}")


# Ledger

def ledger_entry(s: InstallState, operation: str, action: str, path: str, *,
                 source: str = "", module: str = "", existed_before: bool = False,
                 sha256_before: str | None = None, sha256_after: str | None = None,
                 backup_path: str | None = None) -> None:
    if s.ledger_file is None:
        return
    entry = {
        "tool": "install.py", "module": module or None,
        "operation": operation, "action": action, "path": path,
        "source": source or None, "existed_before": existed_before,
        "force": s.force, "dry_run": not s.apply,
        "sha256_before": sha256_before, "sha256_after": sha256_after,
        "backup_path": backup_path,
    }
    with s.ledger_file.open("a") as f:
        f.write(json.dumps(entry) + "\n")


# Plan builder

def build_plan(s: InstallState) -> None:
    target = Path(s.target_dir)
    log(f"\n=== Dogsquard Install Plan ===\nTarget:   {s.target_dir}")
    log(f"Mode:     {'APPLY' if s.apply else 'DRY-RUN'}\nForce:    {str(s.force).lower()}")
    if s.mode_install:
        log(f"Type:     {s.project_type}\nModules:  {' '.join(s.modules)}")
        bmods = {"governance", "pr-quality", "dev-deploy", "example-app", "production-profile"}
        if any(m in bmods for m in s.modules):
            log("\n--- Bootstrap Invocation ---")
            log(f"  PROJECT_TYPE={s.project_type}  TARGET_DIR={s.target_dir}")
            log(f"  DRY_RUN={'false' if s.apply else 'true'}  FORCE={str(s.force).lower()}")
            log(f"  INCLUDE_DEV_DEPLOY={'dev-deploy' in s.modules}")
            log(f"  INCLUDE_EXAMPLE_APP={'example-app' in s.modules}")
            log(f"  INCLUDE_PRODUCTION_PROFILE={'production-profile' in s.modules}")
        if "ai-pr-review" in s.modules:
            log("\n--- AI PR Review Module ---")
            for fr in AI_MODULE_FILES:
                ex = (target / fr).exists()
                act = "skip" if ex and not s.force else ("overwrite" if ex else "create")
                log(f"  {act}: {fr}")
            se = (target / ".github/ai-review/settings.json").exists()
            hai = bool(s.ai_engine or s.ai_enabled)
            if se and not s.force and hai:
                log("  FAIL: .github/ai-review/settings.json exists and --force is not set")
            elif se and not s.force:
                log("  preserve: .github/ai-review/settings.json")
            elif hai:
                log("  configure: scripts/configure-ai-ci.sh (pass-through)")
            else:
                log("  write: .github/ai-review/settings.json (disabled safe config)")
                log(f"  NEXT: cd {s.target_dir} && scripts/configure-ai-ci.sh")
    log(f"\n--- Validation ---\n  {'git diff --check / bash -n' if s.run_checks else 'skipped'}")
    log(f"\n--- Commit/Push ---\n  {'commit and push' if s.commit_push else 'skipped'}")
    if not s.apply:
        log("\nDry-run complete. Use --apply to write files.")


# Backup

def backup_file(s: InstallState, target_path: Path, relative: str) -> str:
    bk = Path(s.target_dir) / ".dogsquard/backups" / TIMESTAMP / relative
    bk.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(str(target_path), str(bk))
    return str(bk)


# Apply: bootstrap modules

def apply_bootstrap_modules(s: InstallState) -> None:
    bmods = {"governance", "pr-quality", "dev-deploy", "example-app", "production-profile"}
    if not any(m in bmods for m in s.modules):
        return
    log("\nRunning bootstrap...")
    env = {**os.environ, "PROJECT_TYPE": s.project_type, "TARGET_DIR": s.target_dir,
           "DRY_RUN": str(not s.apply).lower(), "FORCE": str(s.force).lower(),
           "INCLUDE_DEV_DEPLOY": str("dev-deploy" in s.modules).lower(),
           "INCLUDE_EXAMPLE_APP": str("example-app" in s.modules).lower(),
           "INCLUDE_PRODUCTION_PROFILE": str("production-profile" in s.modules).lower()}
    if s.ledger_file:
        env["DOGSQUARD_LEDGER_FILE"] = str(s.ledger_file)
    code, out, err = run_capture([str(ROOT_DIR / "scripts/bootstrap-project.sh")], env=env, cwd=ROOT_DIR)
    for t in (out, err):
        if t.strip():
            log(t.rstrip())
    if code != 0:
        fail(f"bootstrap-project.sh exited with code {code}")


# Apply: AI PR review module

def _configure_args(s: InstallState) -> list[str]:
    a: list[str] = []
    if s.ai_enabled:
        a += ["--enabled", s.ai_enabled]
    if s.ai_engine:
        a += ["--engine", s.ai_engine]
    for m in s.qoder_models:
        a += ["--qoder-model", m]
    a.append("--apply")
    if s.ai_apply_github_vars:
        a.append("--apply-github-vars")
    return a

def apply_ai_pr_review(s: InstallState) -> None:
    if "ai-pr-review" not in s.modules:
        return
    target = Path(s.target_dir)
    log("\nInstalling AI PR review module...")
    # Copy module files
    for fr in AI_MODULE_FILES:
        dest, src = target / fr, ROOT_DIR / fr
        if not src.is_file():
            fail(f"source AI file missing: {fr}")
        if dest.exists() and not s.force:
            log(f"SKIP exists: {fr}")
            ledger_entry(s, "copy_file", "skipped", fr, source=fr, module="ai-pr-review", existed_before=True)
            continue
        sha_b: str | None = None
        bk: str | None = None
        if dest.exists() and s.force:
            sha_b = file_sha256(dest)
            bk = backup_file(s, dest, fr)
            log(f"BACKUP: {fr} -> {bk}")
            ledger_entry(s, "backup", "backup_created", fr, source=fr, module="ai-pr-review",
                         existed_before=True, sha256_before=sha_b, backup_path=bk)
        if s.apply:
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(str(src), str(dest))
            sha_a = file_sha256(dest)
            if fr in AI_EXECUTABLE_FILES:
                dest.chmod(dest.stat().st_mode | 0o111)
            log(f"CREATED: {fr}")
            ledger_entry(s, "copy_file", "overwritten" if sha_b else "created", fr,
                         source=fr, module="ai-pr-review", existed_before=sha_b is not None,
                         sha256_before=sha_b, sha256_after=sha_a, backup_path=bk)
        else:
            log(f"PLAN copy: {fr}")
    # Settings.json handling
    (target / ".github/workflows/prompts").mkdir(parents=True, exist_ok=True)
    sd = target / ".github/ai-review/settings.json"
    existed = sd.exists()
    hai = bool(s.ai_engine or s.ai_enabled)
    if existed and not s.force and hai:
        fail("target .github/ai-review/settings.json exists and --force is not set. Use --force to overwrite, or remove AI config flags to preserve.")
    if existed and not s.force:
        log("PRESERVE: .github/ai-review/settings.json (existing target config kept)")
        ledger_entry(s, "write_file", "preserved", ".github/ai-review/settings.json", module="ai-pr-review", existed_before=True)
        print_ai_secret_names(s.ai_engine)
        return
    if hai:
        ca = _configure_args(s)
        if s.apply:
            sbk: str | None = None
            if existed and s.force:
                sb = file_sha256(sd)
                sbk = backup_file(s, sd, ".github/ai-review/settings.json")
                log(f"BACKUP: .github/ai-review/settings.json -> {sbk}")
                ledger_entry(s, "backup", "backup_created", ".github/ai-review/settings.json",
                             module="ai-pr-review", existed_before=True, sha256_before=sb, backup_path=sbk)
            log(f"Running: scripts/configure-ai-ci.sh {' '.join(ca)}")
            code, out, err = run_capture(["bash", "scripts/configure-ai-ci.sh", *ca], cwd=target)
            for t in (out, err):
                if t.strip():
                    log(t.rstrip())
            if code != 0:
                fail(f"configure-ai-ci.sh exited with code {code}")
            ledger_entry(s, "write_file", "overwritten" if existed else "created",
                         ".github/ai-review/settings.json", module="ai-pr-review",
                         existed_before=existed, sha256_after=file_sha256(sd), backup_path=sbk)
        else:
            log(f"PLAN: cd {s.target_dir} && scripts/configure-ai-ci.sh {' '.join(ca)}")
    else:
        if s.apply:
            if not existed:
                sd.parent.mkdir(parents=True, exist_ok=True)
                sd.write_text(json.dumps(DISABLED_SAFE_CONFIG, indent=2) + "\n")
                log("CREATED: .github/ai-review/settings.json (disabled safe config)")
                ledger_entry(s, "write_file", "created", ".github/ai-review/settings.json",
                             module="ai-pr-review", sha256_after=file_sha256(sd))
            log(f"\nNext step: cd {s.target_dir} && scripts/configure-ai-ci.sh")
        else:
            log(f"PLAN: write disabled safe settings.json\nNEXT: cd {s.target_dir} && scripts/configure-ai-ci.sh")
    print_ai_secret_names(s.ai_engine)


# Manifest writer

def write_manifest(s: InstallState) -> None:
    if not s.apply:
        return
    target = Path(s.target_dir)
    (target / ".dogsquard").mkdir(parents=True, exist_ok=True)
    dc = _git_out(["git", "rev-parse", "HEAD"], ROOT_DIR) or "unknown"
    tr = _git_out(["git", "remote", "get-url", "origin"], target)
    tb = _git_out(["git", "rev-parse", "--abbrev-ref", "HEAD"], target)
    ai: Any = None
    if "ai-pr-review" in s.modules:
        ai = {"configured": bool(s.ai_engine), "enabled": s.ai_enabled == "true",
              "engine": s.ai_engine or None, "qoder_models": list(s.qoder_models),
              "apply_github_vars": s.ai_apply_github_vars}
    files: list[dict[str, Any]] = []
    if s.ledger_file and s.ledger_file.is_file():
        for line in s.ledger_file.read_text().splitlines():
            if not line.strip():
                continue
            e = json.loads(line)
            if e["operation"] in ("copy_file", "write_file") and e["action"] not in ("skipped", "preserved", "planned"):
                files.append({k: e.get(k) for k in ("path", "module", "action", "source", "sha256_before", "sha256_after", "backup_path")})
    manifest = {
        "schema_version": "1", "installed_at": datetime.now().isoformat(),
        "dogsquard_source": {"path": str(ROOT_DIR), "git_commit": dc},
        "target": {"path": s.target_dir, "git_remote_origin": tr or None, "git_branch": tb or None},
        "project_type": s.project_type, "modules": list(s.modules),
        "options": {"force": s.force, "run_checks": s.run_checks, "commit_push": s.commit_push},
        "ai_review": ai, "files": files,
        "directories": [{"path": ".dogsquard", "action": "created"}],
        "validation": {"run_checks": s.run_checks, "commands": []},
    }
    mp = target / ".dogsquard/install-manifest.json"
    tmp = mp.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(manifest, indent=2) + "\n")
    os.replace(str(tmp), str(mp))
    log(f"\nManifest written: {mp}")


# Validation

def _chk(cmd: list[str], label: str, cwd: Path | None = None) -> bool:
    log(f"  {label}")
    code, _, err = run_capture(cmd, cwd=cwd)
    if code != 0:
        warn(f"{label} failed")
        if err.strip():
            log(err.rstrip())
        return True
    return False

def run_validation(s: InstallState) -> bool:
    if not (s.run_checks and s.apply):
        return True
    target = Path(s.target_dir)
    log("\nRunning validation...")
    f = False
    f |= _chk(["git", "diff", "--check"], "git diff --check", cwd=target)
    sh = sorted((target / "scripts").glob("*.sh")) if (target / "scripts").is_dir() else []
    if sh:
        f |= _chk(["bash", "-n", *[str(x) for x in sh]], "bash -n scripts/*.sh", cwd=target)
    if "ai-pr-review" in s.modules:
        cs = target / "scripts/configure-ai-ci.sh"
        if cs.is_file():
            f |= _chk(["bash", "-n", str(cs)], "bash -n configure-ai-ci.sh")
        ap = target / ".github/workflows/scripts/ai_review_pr.py"
        if ap.is_file():
            log("  python3 -m py_compile ai_review_pr.py")
            try:
                py_compile.compile(str(ap), doraise=True)
            except py_compile.PyCompileError:
                warn("ai_review_pr.py compile check failed"); f = True
        for jf in (".github/ai-review/settings.json", ".github/qoder/settings.json", ".github/claude/deepseek-settings.json"):
            if (target / jf).is_file():
                f |= _chk([sys.executable, "-m", "json.tool", str(target / jf)], f"json.tool {jf}")
        sp = target / ".github/ai-review/settings.json"
        if ap.is_file() and sp.is_file():
            f |= _chk([sys.executable, str(ap), "--resolve-config"], "ai_review_pr.py --resolve-config", cwd=target)
    mk = target / "Makefile"
    if mk.is_file():
        f |= _chk(["make", "help"], "make help", cwd=target)
        if (target / "scripts/doc-check-local.sh").is_file():
            f |= _chk(["make", "doc-check"], "make doc-check", cwd=target)
        if (target / "scripts/doc-guard.sh").is_file():
            f |= _chk(["make", "doc-guard"], "make doc-guard", cwd=target)
    if f:
        log("\nValidation FAILED. Files were written but validation did not pass.")
    else:
        log("Validation passed.")
    s.validation_succeeded = not f
    return not f


# Commit/push

def commit_and_push(s: InstallState) -> None:
    if not (s.commit_push and s.apply):
        return
    target = Path(s.target_dir)
    log("\nCommit/Push...")
    c, _, _ = run_capture(["git", "rev-parse", "--is-inside-work-tree"], cwd=target)
    if c != 0:
        fail("target is not a git repository. Cannot commit/push.")
    if s.run_checks and not s.validation_succeeded:
        fail("validation did not pass. Commit/push requires successful validation.")
    branch = _git_out(["git", "rev-parse", "--abbrev-ref", "HEAD"], target)
    if branch in ("main", "master", ""):
        if s.interactive:
            branch = prompt_choice(f"Current branch is '{branch}'. Enter feature branch name", "feature/dogsquard-install")
            run_capture(["git", "checkout", "-b", branch], cwd=target)
        else:
            fail(f"current branch is '{branch}'. Create a feature branch first, or use --menu.")
    c, out, _ = run_capture(["git", "status", "--short"], cwd=target)
    if out.strip():
        log(f"Changes in target:\n{out.rstrip()}")
    staged: list[str] = []
    if (target / ".dogsquard/install-manifest.json").is_file():
        staged.append(".dogsquard/install-manifest.json")
    if s.ledger_file and s.ledger_file.is_file():
        for line in s.ledger_file.read_text().splitlines():
            if not line.strip():
                continue
            e = json.loads(line)
            if e["action"] not in ("skipped", "preserved", "planned"):
                staged.append(e["path"])
    for fp in staged:
        if (target / fp).exists():
            run_capture(["git", "add", "--", fp], cwd=target)
    c, _, _ = run_capture(["git", "diff", "--cached", "--quiet"], cwd=target)
    if c == 0:
        log("No target changes to commit."); return
    run_capture(["git", "commit", "-m", "Install Dogsquard modules"], cwd=target)
    c, _, _ = run_capture(["git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], cwd=target)
    if c == 0:
        run_capture(["git", "push"], cwd=target); log("Pushed to existing upstream.")
    else:
        run_capture(["git", "push", "-u", "origin", "HEAD"], cwd=target); log("Pushed and set upstream for current branch.")


# Uninstall

def _build_uninstall_plan(manifest: dict[str, Any], target: Path) -> list[tuple[str, str, str]]:
    plan: list[tuple[str, str, str]] = []
    for f in manifest.get("files", []):
        fp, act = target / f["path"], f["action"]
        if act in ("skipped", "preserved"):
            plan.append(("SKIP", f["path"], "pre-existing, not Dogsquard-managed")); continue
        if act in ("created", "overwritten"):
            if fp.is_file():
                cur, exp = file_sha256(fp), f.get("sha256_after")
                if exp and cur != exp:
                    plan.append(("FAIL", f["path"], f"checksum mismatch: current={cur[:12] if cur else 'none'} expected={exp[:12]}")); continue
            if act == "created":
                plan.append(("REMOVE", f["path"], f"sha256={f.get('sha256_after', 'unknown')}"))
            else:
                bk = f.get("backup_path", "")
                if bk and _resolve_backup(target, bk).is_file():
                    plan.append(("RESTORE", f["path"], f"from backup: {bk}"))
                else:
                    plan.append(("FAIL", f["path"], f"backup not found: {bk}"))
    return plan

def _execute_uninstall(manifest: dict[str, Any], target: Path) -> None:
    for f in manifest.get("files", []):
        fp, act = target / f["path"], f["action"]
        if act in ("skipped", "preserved"):
            continue
        if act == "created" and fp.is_file():
            cur, exp = file_sha256(fp), f.get("sha256_after")
            if exp and cur != exp:
                fail(f"checksum mismatch for {f['path']}, aborting")
            fp.unlink(); log(f"REMOVED: {f['path']}")
        elif act == "overwritten":
            bk = f.get("backup_path", "")
            if not bk:
                fail(f"backup not found: {f['path']}")
            bkp = _resolve_backup(target, bk)
            if not bkp.is_file():
                fail(f"backup not found for {f['path']}: {bk}")
            if fp.is_file():
                cur, exp = file_sha256(fp), f.get("sha256_after")
                if exp and cur != exp:
                    fail(f"checksum mismatch for {f['path']}, aborting restore")
            shutil.copy2(str(bkp), str(fp)); bkp.unlink()
            log(f"RESTORED: {f['path']} from {bk}")
    for d in manifest.get("directories", []):
        dp = target / d["path"]
        if dp.is_dir():
            try:
                dp.rmdir(); log(f"DIR_REMOVED: {d['path']}")
            except OSError:
                log(f"DIR_SKIP (not empty): {d['path']}")
    mp = target / ".dogsquard/install-manifest.json"
    if mp.is_file():
        mp.unlink(); log("REMOVED: .dogsquard/install-manifest.json")
    dd = target / ".dogsquard"
    if dd.is_dir():
        try:
            dd.rmdir(); log("DIR_REMOVED: .dogsquard")
        except OSError:
            log("DIR_SKIP (not empty): .dogsquard")
    log("\nUninstall complete.\nNote: GitHub secrets and variables were not modified.")
    log("  gh secret delete DEEPSEEK_AUTH_TOKEN\n  gh secret delete QODER_PERSONAL_ACCESS_TOKEN")
    log("  gh variable delete AI_REVIEW_ENGINE\n  gh variable delete AI_REVIEW_CONFIGURED")

def run_uninstall(s: InstallState) -> None:
    target = Path(s.target_dir)
    mp = target / ".dogsquard/install-manifest.json"
    if not mp.is_file():
        fail(f"no Dogsquard install manifest found at {mp}\nRefusing broad cleanup. Use manual review or a future audited fallback.")
    manifest = json.loads(mp.read_text())
    if manifest.get("schema_version") != "1":
        fail(f"unsupported manifest schema version: {manifest.get('schema_version')}")
    log(f"\n=== Dogsquard Uninstall Plan ===\nTarget: {s.target_dir}\nMode:   {'APPLY' if s.apply else 'DRY-RUN'}\n")
    plan = _build_uninstall_plan(manifest, target)
    for action, path, reason in plan:
        log(f"  {action}: {path} ({reason})")
    for d in manifest.get("directories", []):
        log(f"  DIR_REMOVE: {d['path']} (if empty)")
    log("  REMOVE: .dogsquard/install-manifest.json\n  DIR_REMOVE: .dogsquard (if empty)")
    has_fail = any(a == "FAIL" for a, _, _ in plan)
    if has_fail:
        log("\nUninstall plan has failures. Resolve manually before applying.")
        if s.apply:
            fail("uninstall plan has failures. Cannot apply.")
        log("\nDry-run complete. Resolve failures before applying."); return
    if not s.apply:
        log("\nDry-run complete. Use --apply to execute uninstall."); return
    log("Executing uninstall...")
    _execute_uninstall(manifest, target)


# Interactive menu

def interactive_menu(s: InstallState) -> None:
    log("=== Dogsquard Install Menu ===\n")
    if s.uninstall:
        if prompt_yes_no(f"Uninstall all Dogsquard-managed assets from {s.target_dir}?", "yes"):
            s.apply = True
        return
    s.target_dir = prompt_choice("Target repository path", s.target_dir or "")
    if not s.target_dir:
        bad_arg("target repository path is required.")
    s.target_dir = expand_user_path(s.target_dir)
    tp = Path(s.target_dir)
    if tp.is_dir():
        s.target_dir = str(tp.resolve())
    else:
        bad_arg(f"target directory does not exist: {s.target_dir}")
    s.project_type = prompt_choice("Project type (node/go-js/docs-only)", s.project_type or "docs-only")
    if s.project_type not in ("node", "go-js", "docs-only"):
        bad_arg(f"invalid project type: {s.project_type}")
    log("\nAvailable modules:")
    for i, mod in enumerate(ALLOWED_MODULES):
        log(f"  {i + 1}. {mod}")
    mi = _read_input("\nEnter module numbers (comma-separated, e.g. 1,2,6): ")
    s.modules = []
    for ns in mi.split(","):
        ns = ns.strip()
        if not ns:
            continue
        try:
            num = int(ns)
        except ValueError:
            bad_arg(f"invalid module number: {ns}")
        if num < 1 or num > len(ALLOWED_MODULES):
            bad_arg(f"invalid module number: {ns}")
        s.modules.append(ALLOWED_MODULES[num - 1])
    if not s.modules:
        bad_arg("at least one module must be selected.")
    if "ai-pr-review" in s.modules:
        log("")
        if prompt_yes_no("Configure AI PR review now?", "no"):
            s.ai_enabled = "true" if prompt_yes_no("Enable AI review?", "true") else "false"
            s.ai_engine = prompt_choice("Engine (claude-deepseek/qoder)", "qoder")
            if s.ai_engine not in ("claude-deepseek", "qoder"):
                bad_arg(f"invalid engine: {s.ai_engine}")
            if s.ai_engine == "qoder":
                s.qoder_models = []
                select_qoder_models_interactively(s)
    log("")
    s.run_checks = prompt_yes_no("Run validation after apply?", "yes")
    s.commit_push = prompt_yes_no("Commit and push after validation?", "no")
    log("")
    s.apply = prompt_yes_no("Apply changes to target?", "no")


# Main entry point

def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    s = InstallState()
    if not args:
        s.interactive = True
    try:
        parse_cli_flags(s, args)
        if s.config_file:
            s.config = parse_config_file(Path(s.config_file))
        merge_config(s)
        if s.interactive:
            interactive_menu(s)
        validate_inputs(s)
        tmp_dir = ROOT_DIR / ".tmp/install"
        tmp_dir.mkdir(parents=True, exist_ok=True)
        fd, lp = tempfile.mkstemp(prefix="ledger-", dir=str(tmp_dir))
        os.close(fd)
        s.ledger_file = Path(lp)
        try:
            if s.uninstall:
                run_uninstall(s); return 0
            build_plan(s)
            if not s.apply:
                return 0
            log("\nApplying install plan...")
            apply_bootstrap_modules(s)
            apply_ai_pr_review(s)
            write_manifest(s)
            run_validation(s)
            commit_and_push(s)
            log("\nInstall complete.")
            return 0
        finally:
            if s.ledger_file and s.ledger_file.is_file():
                s.ledger_file.unlink()
    except InstallFailure as exc:
        log(f"FAIL: {exc}"); return 1
    except SystemExit as exc:
        return exc.code if isinstance(exc.code, int) else 0

if __name__ == "__main__":
    raise SystemExit(main())
