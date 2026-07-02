#!/usr/bin/env python3
"""Port of configure-ai-ci.sh -- configure Dogsquard AI CI review settings."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
SETTINGS_FILE = Path(".github/ai-review/settings.json")

DEFAULT_SETTINGS: dict[str, Any] = {
    "enabled": True,
    "engine": "qoder",
    "claude": {"provider": "deepseek"},
    "qoder": {"models": ["Qwen3.7-Max"], "implicit_auto_fallback": True},
}

USAGE = """\
Usage:
  scripts/configure_ai_ci.py
  scripts/configure_ai_ci.py --dry-run
  scripts/configure_ai_ci.py --apply
  scripts/configure_ai_ci.py --apply --apply-github-vars
  scripts/configure_ai_ci.py --enabled true --engine qoder --qoder-model Qwen3.7-Max --qoder-model GLM-5.2 --apply
  scripts/configure_ai_ci.py --enabled true --engine claude-deepseek --claude-provider deepseek --apply
  scripts/configure_ai_ci.py --enabled false --apply

Options:
  --help                    Show this help.
  --dry-run                 Print generated config without writing files. Default.
  --apply                   Write .github/ai-review/settings.json atomically.
  --apply-github-vars       With --apply, set non-secret repo variables through gh.
  --enabled true|false      Enable or disable Dogsquard AI CI review.
  --engine ENGINE           claude-deepseek or qoder.
  --claude-provider NAME    Claude provider. MVP supports deepseek.
  --qoder-model NAME        Add one Qoder user-selected model. Repeat at most twice.

Interactive Qoder mode:
  Shows available models as a checkbox-style list. Enter a model number to
  toggle it, then press Enter or type done to continue. New selections move to
  the front of the runtime sequence. Auto is always implicit and not selectable.

Secrets:
  This script never reads, prints, or stores secret values.
  Interactive apply can optionally call gh secret set for the required secret.
  Claude+DeepSeek requires secret: DEEPSEEK_AUTH_TOKEN
  Qoder requires secret: QODER_PERSONAL_ACCESS_TOKEN
"""


class ConfigureFailure(Exception):
    pass


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


def run_capture(
    cmd: list[str],
    *,
    input_text: str | None = None,
    timeout_seconds: int | None = None,
    env: dict[str, str] | None = None,
) -> tuple[int, str, str]:
    try:
        result = subprocess.run(
            cmd,
            input=input_text,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout_seconds,
            env=env,
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired as exc:
        stdout = (
            exc.stdout or ""
        ).decode("utf-8", errors="replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        stderr = (
            exc.stderr or ""
        ).decode("utf-8", errors="replace") if isinstance(exc.stderr, bytes) else (exc.stderr or "")
        detail = f"Command timed out after {timeout_seconds} seconds."
        return 124, stdout, f"{stderr.strip()}\n{detail}".strip()


def die(msg: str) -> None:
    raise ConfigureFailure(msg)


# ---------------------------------------------------------------------------
# Settings I/O
# ---------------------------------------------------------------------------

def load_current_settings(settings_path: Path) -> dict[str, Any]:
    """Read existing settings or return defaults."""
    default = json.loads(json.dumps(DEFAULT_SETTINGS))
    if not settings_path.is_file():
        return default
    with settings_path.open(encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        die(f"{settings_path} must contain a JSON object")
    return data


def json_get(data: dict[str, Any], expr: str) -> Any:
    """Retrieve a dotted-path value from *data*, mirroring the bash helper."""
    value: Any = data
    for part in expr.split("."):
        value = value.get(part, {}) if isinstance(value, dict) else {}
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, list):
        return list(value)
    if value in ({}, None):
        return ""
    return str(value)


def write_settings_atomic(settings_path: Path, generated_json: str) -> None:
    """Write *generated_json* to *settings_path* via tempfile + os.replace."""
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    data = json.loads(generated_json)
    with tempfile.NamedTemporaryFile(
        "w",
        encoding="utf-8",
        dir=str(settings_path.parent),
        prefix=f"{settings_path.name}.",
        delete=False,
    ) as f:
        json.dump(data, f, indent=2)
        f.write("\n")
        staging = Path(f.name)
    os.replace(staging, settings_path)


# ---------------------------------------------------------------------------
# Qoder model helpers
# ---------------------------------------------------------------------------

def list_qoder_models() -> list[str]:
    if not shutil.which("qodercli"):
        die("qodercli is required to list Qoder models")
    code, stdout, stderr = run_capture(["qodercli", "--list-models"])
    if code != 0:
        die(f"qodercli --list-models failed: {stderr.strip()}")
    models: list[str] = []
    for line in stdout.splitlines():
        stripped = line.strip()
        if stripped and stripped.upper() != "MODEL" and stripped.lower() != "auto":
            models.append(stripped)
    return models


def join_models_with_auto(qoder_models: list[str]) -> str:
    if qoder_models:
        return ",".join(qoder_models) + ",auto"
    return "auto"


def join_models_arrow(qoder_models: list[str]) -> str:
    if qoder_models:
        return " -> ".join(qoder_models) + " -> Auto"
    return "Auto"


def qoder_model_is_selected(qoder_models: list[str], candidate: str) -> bool:
    return candidate in qoder_models


def toggle_qoder_model(qoder_models: list[str], selected: str) -> list[str]:
    """Toggle *selected* in *qoder_models*, respecting the 2-slot limit."""
    if qoder_model_is_selected(qoder_models, selected):
        return [m for m in qoder_models if m != selected]
    if len(qoder_models) >= 2:
        log("No Qoder model slots left. Uncheck one model before selecting another.")
        return list(qoder_models)
    return [selected] + qoder_models


def render_qoder_model_menu(
    available_models: list[str], qoder_models: list[str]
) -> None:
    slots_left = 2 - len(qoder_models)
    print()
    print(
        f"Available Qoder models [{join_models_with_auto(qoder_models)}] "
        f"{slots_left} available model slots left:"
    )
    for index, model in enumerate(available_models):
        mark = "x" if qoder_model_is_selected(qoder_models, model) else " "
        print(f"  {index + 1:2d}) [{mark}] {model}")
    print("Enter a number to toggle a model. Press Enter or type done to continue.")


def select_qoder_models_interactively(qoder_models: list[str]) -> list[str]:
    available_models = list_qoder_models()
    if not available_models:
        die("qodercli --list-models returned no selectable models")

    while True:
        render_qoder_model_menu(available_models, qoder_models)
        try:
            answer = input("Qoder model selection: ")
        except (EOFError, KeyboardInterrupt):
            print(file=sys.stderr)
            die("Interrupted.")
        stripped = answer.strip()
        if stripped in ("", "done", "Done", "DONE"):
            if len(qoder_models) < 1:
                log("Select at least one Qoder model before continuing.")
                continue
            break
        if not stripped.isdigit():
            log("Enter a model number, press Enter, or type done.")
            continue
        answer_num = int(stripped)
        if answer_num < 1 or answer_num > len(available_models):
            log("Model number out of range.")
            continue
        model = available_models[answer_num - 1]
        qoder_models = toggle_qoder_model(qoder_models, model)
    return qoder_models


def validate_qoder_models_available(qoder_models: list[str]) -> None:
    available = list_qoder_models()
    for model in qoder_models:
        if model not in available:
            die(f"Qoder model is not available from qodercli --list-models: {model}")


# ---------------------------------------------------------------------------
# GitHub / git helpers
# ---------------------------------------------------------------------------

def ensure_gh_ready() -> None:
    if not shutil.which("gh"):
        die("gh is required for GitHub activation")
    code, _, _ = run_capture(["gh", "auth", "status"])
    if code != 0:
        die("gh is not authenticated")
    code, _, _ = run_capture(["git", "remote", "get-url", "origin"])
    if code != 0:
        die("git remote origin is required")


def apply_github_variables(engine: str) -> None:
    ensure_gh_ready()
    code, _, stderr = run_capture(
        ["gh", "variable", "set", "AI_REVIEW_ENGINE", "--body", engine]
    )
    if code != 0:
        die(f"gh variable set AI_REVIEW_ENGINE failed: {stderr.strip()}")
    code, _, stderr = run_capture(
        ["gh", "variable", "set", "AI_REVIEW_CONFIGURED", "--body", "true"]
    )
    if code != 0:
        die(f"gh variable set AI_REVIEW_CONFIGURED failed: {stderr.strip()}")
    print(
        "Updated non-secret GitHub repository variables: "
        "AI_REVIEW_ENGINE, AI_REVIEW_CONFIGURED"
    )


def print_manual_activation_commands(settings_file: str) -> None:
    print("To activate this config in GitHub Actions manually, run:")
    print(f"  git add {settings_file}")
    print('  git commit -m "Update AI review config"')
    print("  git push")


def tracked_config_change_is_isolated(settings_file: str) -> bool:
    _code1, stdout1, _ = run_capture(["git", "diff", "--name-only"])
    _code2, stdout2, _ = run_capture(["git", "diff", "--cached", "--name-only"])
    for line in (stdout1 + stdout2).splitlines():
        name = line.strip()
        if name and name != settings_file:
            return False
    return True


def commit_and_push_config(settings_file: str) -> None:
    code, _, _ = run_capture(["git", "rev-parse", "--is-inside-work-tree"])
    if code != 0:
        print("Skipped commit/push because this directory is not inside a git repository.")
        print_manual_activation_commands(settings_file)
        return

    code, _, _ = run_capture(["git", "remote", "get-url", "origin"])
    if code != 0:
        print("Skipped commit/push because this repository has no origin remote.")
        print_manual_activation_commands(settings_file)
        return

    code_unstaged, _, _ = run_capture(["git", "diff", "--quiet", "--", settings_file])
    code_staged, _, _ = run_capture(
        ["git", "diff", "--cached", "--quiet", "--", settings_file]
    )
    if code_unstaged == 0 and code_staged == 0:
        print("No config changes to commit.")
        return

    if not tracked_config_change_is_isolated(settings_file):
        print(
            f"Skipped automatic commit because tracked local changes "
            f"are not limited to {settings_file}."
        )
        print("Review your worktree, then commit the config intentionally.")
        print_manual_activation_commands(settings_file)
        return

    run_capture(["git", "add", "--", settings_file])
    code, _, _ = run_capture(["git", "diff", "--cached", "--quiet", "--", settings_file])
    if code == 0:
        print("No config changes to commit.")
        return

    code, _, stderr = run_capture(["git", "commit", "-m", "Update AI review config"])
    if code != 0:
        die(f"git commit failed: {stderr.strip()}")

    code, stdout, _ = run_capture(
        ["git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"]
    )
    if code == 0:
        upstream = stdout.strip()
        code, _, stderr = run_capture(["git", "push"])
        if code != 0:
            die(f"git push failed: {stderr.strip()}")
        print(
            f"Pushed config to {upstream}. GitHub Actions will use it on the "
            f"next workflow run for this branch."
        )
    else:
        code, _, stderr = run_capture(["git", "push", "-u", "origin", "HEAD"])
        if code != 0:
            die(f"git push failed: {stderr.strip()}")
        print(
            "Pushed config and set upstream for the current branch. "
            "GitHub Actions will use it on the next workflow run for this branch."
        )


def github_secret_exists(secret_name: str) -> bool:
    code, stdout, _ = run_capture(["gh", "secret", "list"])
    if code != 0:
        return False
    for line in stdout.splitlines():
        parts = line.split()
        if parts and parts[0] == secret_name:
            return True
    return False


def print_secret_status(secret_name: str) -> bool:
    if not shutil.which("gh"):
        print(f"{secret_name} status: unknown (gh is not installed)")
        return False
    code, _, _ = run_capture(["gh", "auth", "status"])
    if code != 0:
        print(f"{secret_name} status: unknown (gh is not authenticated)")
        return False
    if github_secret_exists(secret_name):
        print(f"{secret_name} status: exists")
        return True
    print(f"{secret_name} status: missing")
    return False


# ---------------------------------------------------------------------------
# Interactive prompts
# ---------------------------------------------------------------------------

def prompt_yes_no(prompt: str, default: str) -> bool:
    try:
        answer = input(f"{prompt} [{default}]: ")
    except (EOFError, KeyboardInterrupt):
        print(file=sys.stderr)
        die("Interrupted.")
    answer = answer.strip() or default
    lower = answer.lower()
    if lower in ("y", "yes", "true"):
        return True
    if lower in ("n", "no", "false"):
        return False
    die("expected yes or no")
    return False  # unreachable -- die always raises


def prompt_choice(prompt: str, default: str) -> str:
    try:
        answer = input(f"{prompt} [{default}]: ")
    except (EOFError, KeyboardInterrupt):
        print(file=sys.stderr)
        die("Interrupted.")
    return answer.strip() or default


def prompt_github_activation(engine: str, settings_file: str) -> None:
    if engine == "claude-deepseek":
        secret_name = "DEEPSEEK_AUTH_TOKEN"
    else:
        secret_name = "QODER_PERSONAL_ACCESS_TOKEN"

    print()
    print("GitHub repository variables are optional compatibility hints.")
    print(
        f"This sets AI_REVIEW_ENGINE={engine} and "
        f"AI_REVIEW_CONFIGURED=true in GitHub."
    )
    print(
        "AI_REVIEW_CONFIGURED means this repo was configured; "
        "it is not the enabled/disabled switch."
    )
    print(
        f"It does not commit or push {settings_file}; "
        f"the config file remains the source of truth."
    )
    should_apply_vars = prompt_yes_no(
        "Sync these non-secret GitHub variables now?", "no"
    )
    if should_apply_vars:
        apply_github_variables(engine)
    else:
        print("Skipped GitHub repository variable update.")

    print()
    print_secret_status(secret_name)
    should_set_secret = prompt_yes_no(
        f"Set or update {secret_name} now?", "no"
    )
    if should_set_secret:
        ensure_gh_ready()
        code, _, stderr = run_capture(["gh", "secret", "set", secret_name])
        if code != 0:
            die(f"gh secret set failed: {stderr.strip()}")
        print(f"Updated GitHub secret: {secret_name}")
    else:
        print("Skipped GitHub secret update.")

    print()
    print(
        f"To make GitHub Actions use {settings_file}, "
        f"the file must be committed and pushed."
    )
    print(
        f"This only stages {settings_file}, "
        f"but git push sends the current branch to GitHub."
    )
    should_commit_push = prompt_yes_no(
        "Commit this config and push the current branch now?", "no"
    )
    if should_commit_push:
        commit_and_push_config(settings_file)
    else:
        print("Skipped commit/push.")
        print_manual_activation_commands(settings_file)


def interactive_menu(
    current: dict[str, Any],
    qoder_models: list[str],
) -> tuple[str, str, str, list[str], bool]:
    """Run the interactive configuration menu.

    Returns (enabled, engine, claude_provider, qoder_models, apply).
    """
    print("Dogsquard AI CI configuration")
    print()

    enabled_str = json_get(current, "enabled")
    enabled_answer = prompt_yes_no("Enable AI CI review?", enabled_str)
    enabled = "true" if enabled_answer else "false"

    engine_default = json_get(current, "engine")
    engine = prompt_choice("Engine (claude-deepseek/qoder)", engine_default)

    claude_provider = json_get(current, "claude.provider")
    if engine == "claude-deepseek":
        print("Claude providers:")
        print("  - deepseek (requires secret DEEPSEEK_AUTH_TOKEN)")
        claude_provider = prompt_choice("Claude provider", claude_provider)
    elif engine == "qoder":
        if not qoder_models:
            existing = json_get(current, "qoder.models")
            if isinstance(existing, list):
                qoder_models = list(existing)
        qoder_models = select_qoder_models_interactively(qoder_models)
        print(f"Final runtime sequence: {join_models_with_auto(qoder_models)}")
    else:
        die(f"invalid engine: {engine}")

    print()
    print("This command is dry-run unless you answer apply here.")
    should_apply = prompt_yes_no("Apply local file changes?", "no")

    return enabled, engine, claude_provider, qoder_models, should_apply


# ---------------------------------------------------------------------------
# JSON generation
# ---------------------------------------------------------------------------

def generate_settings_json(
    enabled: str,
    engine: str,
    claude_provider: str,
    qoder_models: list[str],
) -> str:
    models = [m for m in qoder_models if m]
    data: dict[str, Any] = {
        "enabled": enabled == "true",
        "engine": engine,
        "claude": {"provider": claude_provider},
        "qoder": {"models": models, "implicit_auto_fallback": True},
    }
    return json.dumps(data, indent=2, sort_keys=False)


# ---------------------------------------------------------------------------
# CLI argument parsing
# ---------------------------------------------------------------------------

def parse_args(
    args: list[str],
) -> dict[str, Any]:
    state: dict[str, Any] = {
        "apply": False,
        "apply_github_vars": False,
        "enabled": "",
        "engine": "",
        "claude_provider": "",
        "qoder_models": [],
        "interactive": True,
        "engine_flag_set": False,
        "qoder_model_flag_count": 0,
    }

    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("--help", "-h"):
            print(USAGE)
            state["_exit"] = 0
            return state
        elif arg == "--dry-run":
            state["apply"] = False
            state["interactive"] = False
        elif arg == "--apply":
            state["apply"] = True
            state["interactive"] = False
        elif arg == "--apply-github-vars":
            state["apply_github_vars"] = True
            state["interactive"] = False
        elif arg == "--enabled":
            if i + 1 >= len(args):
                log("ERROR: --enabled requires true or false")
                state["_exit"] = 2
                return state
            state["enabled"] = args[i + 1]
            state["interactive"] = False
            i += 1
        elif arg == "--engine":
            if i + 1 >= len(args):
                log("ERROR: --engine requires a value")
                state["_exit"] = 2
                return state
            state["engine"] = args[i + 1]
            state["engine_flag_set"] = True
            state["interactive"] = False
            i += 1
        elif arg == "--claude-provider":
            if i + 1 >= len(args):
                log("ERROR: --claude-provider requires a value")
                state["_exit"] = 2
                return state
            state["claude_provider"] = args[i + 1]
            state["interactive"] = False
            i += 1
        elif arg == "--qoder-model":
            if i + 1 >= len(args):
                log("ERROR: --qoder-model requires a value")
                state["_exit"] = 2
                return state
            state["qoder_models"].append(args[i + 1])
            state["qoder_model_flag_count"] += 1
            state["interactive"] = False
            i += 1
        else:
            log(f"ERROR: unknown argument: {arg}")
            state["_exit"] = 2
            return state
        i += 1

    return state


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    os.chdir(REPO_ROOT)

    state = parse_args(args)
    if "_exit" in state:
        return state["_exit"]

    apply: bool = state["apply"]
    apply_github_vars: bool = state["apply_github_vars"]
    enabled: str = state["enabled"]
    engine: str = state["engine"]
    claude_provider: str = state["claude_provider"]
    qoder_models: list[str] = state["qoder_models"]
    interactive: bool = state["interactive"]
    engine_flag_set: bool = state["engine_flag_set"]
    qoder_model_flag_count: int = state["qoder_model_flag_count"]

    if apply_github_vars and not apply:
        log("ERROR: --apply-github-vars requires --apply")
        return 2

    settings_path = SETTINGS_FILE
    try:
        current = load_current_settings(settings_path)
    except ConfigureFailure as exc:
        log(f"ERROR: {exc}")
        return 2

    try:
        # ---- interactive menu ------------------------------------------
        if interactive:
            (enabled, engine, claude_provider, qoder_models, apply) = (
                interactive_menu(current, qoder_models)
            )

        # ---- fill defaults from current config -------------------------
        if not enabled:
            enabled = json_get(current, "enabled")
        if not engine:
            engine = json_get(current, "engine")
        if not claude_provider:
            claude_provider = json_get(current, "claude.provider")
        if not qoder_models:
            existing = json_get(current, "qoder.models")
            if isinstance(existing, list):
                qoder_models = list(existing)

        # ---- validation ------------------------------------------------
        if enabled not in ("true", "false"):
            die("--enabled must be true or false")

        if engine not in ("claude-deepseek", "qoder"):
            die("--engine must be claude-deepseek or qoder")

        if claude_provider != "deepseek":
            die("--claude-provider must be deepseek")

        if engine == "qoder":
            if (
                not interactive
                and engine_flag_set
                and qoder_model_flag_count == 0
            ):
                die("explicit --engine qoder requires at least one --qoder-model")
            if len(qoder_models) < 1:
                die("Qoder requires at least one --qoder-model")
            if len(qoder_models) > 2:
                die("Qoder allows at most two --qoder-model values")
            for model in qoder_models:
                if not model:
                    die("Qoder model cannot be empty")
                if model.lower() == "auto":
                    die("Auto is an implicit fallback and cannot be selected")
            if len(qoder_models) == 2 and qoder_models[0] == qoder_models[1]:
                die("Qoder models must be unique")
            validate_qoder_models_available(qoder_models)

        # ---- generate JSON ---------------------------------------------
        generated_json = generate_settings_json(
            enabled, engine, claude_provider, qoder_models
        )

        # ---- print summary ---------------------------------------------
        settings_file_str = str(settings_path)
        print("Affected files:")
        print(f"  - {settings_file_str}")
        if apply_github_vars:
            print(
                "  - GitHub repository variables: "
                "AI_REVIEW_ENGINE, AI_REVIEW_CONFIGURED"
            )
        print()
        print(f"Generated {settings_file_str}:")
        print(generated_json)
        print()
        if engine == "claude-deepseek":
            print("Required secret: DEEPSEEK_AUTH_TOKEN")
        else:
            print("Required secret: QODER_PERSONAL_ACCESS_TOKEN")
            print(
                f"Runtime fallback sequence: "
                f"{' '.join(qoder_models)} Auto"
            )

        # ---- dry-run gate ----------------------------------------------
        if not apply:
            print()
            print("Dry-run only. No files written.")
            return 0

        # ---- write settings file ---------------------------------------
        write_settings_atomic(settings_path, generated_json)

        print()
        print(f"Wrote {settings_file_str}")
        print(f"Configured AI CI: enabled={enabled} engine={engine}")
        if engine == "qoder":
            print(
                f"Configured Qoder fallback sequence: "
                f"{join_models_arrow(qoder_models)}"
            )
        print(
            "GitHub Actions will use this config after the file is "
            "committed and pushed."
        )
        print(
            f"Run `git diff -- {settings_file_str}` to review the "
            f"exact file diff."
        )

        # ---- GitHub variable sync / activation prompts -----------------
        if apply_github_vars:
            apply_github_variables(engine)
        elif interactive:
            prompt_github_activation(engine, settings_file_str)

        return 0

    except ConfigureFailure as exc:
        log(f"ERROR: {exc}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
