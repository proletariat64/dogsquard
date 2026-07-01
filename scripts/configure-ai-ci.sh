#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
settings_file=".github/ai-review/settings.json"

usage() {
  cat <<'USAGE'
Usage:
  scripts/configure-ai-ci.sh
  scripts/configure-ai-ci.sh --dry-run
  scripts/configure-ai-ci.sh --apply
  scripts/configure-ai-ci.sh --apply --apply-github-vars
  scripts/configure-ai-ci.sh --enabled true --engine qoder --qoder-model Qwen3.7-Max --qoder-model GLM-5.2 --apply
  scripts/configure-ai-ci.sh --enabled true --engine claude-deepseek --claude-provider deepseek --apply
  scripts/configure-ai-ci.sh --enabled false --apply

Options:
  --help                    Show this help.
  --dry-run                 Print generated config without writing files. Default.
  --apply                   Write .github/ai-review/settings.json atomically.
  --apply-github-vars       With --apply, set non-secret repo variables through gh.
  --enabled true|false      Enable or disable Dogsquard AI CI review.
  --engine ENGINE           claude-deepseek or qoder.
  --claude-provider NAME    Claude provider. MVP supports deepseek.
  --qoder-model NAME        Add one Qoder user-selected model. Repeat at most twice.

Secrets:
  This script never reads, prints, creates, or stores secret values.
  Claude+DeepSeek requires secret: DEEPSEEK_AUTH_TOKEN
  Qoder requires secret: QODER_PERSONAL_ACCESS_TOKEN
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

cd "$repo_root"

apply=false
apply_github_vars=false
enabled=""
engine=""
claude_provider=""
qoder_models=()
interactive=true
engine_flag_set=false
qoder_model_flag_count=0

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --dry-run)
      apply=false
      interactive=false
      shift
      ;;
    --apply)
      apply=true
      interactive=false
      shift
      ;;
    --apply-github-vars)
      apply_github_vars=true
      interactive=false
      shift
      ;;
    --enabled)
      [[ "$#" -ge 2 ]] || die "--enabled requires true or false"
      enabled="$2"
      interactive=false
      shift 2
      ;;
    --engine)
      [[ "$#" -ge 2 ]] || die "--engine requires a value"
      engine="$2"
      engine_flag_set=true
      interactive=false
      shift 2
      ;;
    --claude-provider)
      [[ "$#" -ge 2 ]] || die "--claude-provider requires a value"
      claude_provider="$2"
      interactive=false
      shift 2
      ;;
    --qoder-model)
      [[ "$#" -ge 2 ]] || die "--qoder-model requires a value"
      qoder_models+=("$2")
      qoder_model_flag_count=$((qoder_model_flag_count + 1))
      interactive=false
      shift 2
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

if [[ "$apply_github_vars" == true && "$apply" != true ]]; then
  die "--apply-github-vars requires --apply"
fi

current_json() {
  python3 - "$settings_file" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
default = {
    "enabled": True,
    "engine": "claude-deepseek",
    "claude": {"provider": "deepseek"},
    "qoder": {"models": ["Qwen3.7-Max"], "implicit_auto_fallback": True},
}
if path.is_file():
    with path.open(encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise SystemExit(f"{path} must contain a JSON object")
else:
    data = default
print(json.dumps(data))
PY
}

json_get() {
  local expr="$1"
  CURRENT_JSON="$current" python3 - "$expr" <<'PY'
import json
import os
import sys

data = json.loads(os.environ["CURRENT_JSON"])
expr = sys.argv[1]
value = data
for part in expr.split("."):
    value = value.get(part, {}) if isinstance(value, dict) else {}
if isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, list):
    for item in value:
        print(item)
elif value not in ({}, None):
    print(value)
PY
}

list_qoder_models() {
  command -v qodercli >/dev/null 2>&1 || die "qodercli is required to list Qoder models"
  qodercli --list-models | awk 'NF && toupper($0) != "MODEL" && tolower($0) != "auto" { print $0 }'
}

validate_qoder_models_available() {
  local model
  local available
  available="$(list_qoder_models)"
  for model in "${qoder_models[@]}"; do
    if ! grep -Fxq "$model" <<<"$available"; then
      die "Qoder model is not available from qodercli --list-models: $model"
    fi
  done
}

prompt_yes_no() {
  local prompt="$1"
  local default="$2"
  local answer
  read -r -p "$prompt [$default]: " answer
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES|true|TRUE) echo "true" ;;
    n|N|no|NO|false|FALSE) echo "false" ;;
    *) die "expected yes or no" ;;
  esac
}

prompt_choice() {
  local prompt="$1"
  local default="$2"
  local answer
  read -r -p "$prompt [$default]: " answer
  echo "${answer:-$default}"
}

interactive_menu() {
  echo "Dogsquard AI CI configuration"
  echo
  enabled="$(prompt_yes_no "Enable AI CI review?" "$(json_get enabled)")"
  engine="$(prompt_choice "Engine (claude-deepseek/qoder)" "$(json_get engine)")"

  if [[ "$engine" == "claude-deepseek" ]]; then
    echo "Claude providers:"
    echo "  - deepseek (requires secret DEEPSEEK_AUTH_TOKEN)"
    claude_provider="$(prompt_choice "Claude provider" "$(json_get claude.provider)")"
  elif [[ "$engine" == "qoder" ]]; then
    echo "Available Qoder models:"
    list_qoder_models | sed 's/^/  - /'
    qoder_models=()
    local first second
    read -r -p "Primary Qoder model: " first
    [[ -n "$first" ]] || die "primary Qoder model is required"
    qoder_models+=("$first")
    read -r -p "Fallback Qoder model (optional, blank for none): " second
    [[ -z "$second" ]] || qoder_models+=("$second")
    echo "Final runtime sequence: ${qoder_models[*]} Auto"
  else
    die "invalid engine: $engine"
  fi

  echo
  echo "This command is dry-run unless you answer apply here."
  local should_apply
  should_apply="$(prompt_yes_no "Apply local file changes?" "no")"
  [[ "$should_apply" == "true" ]] && apply=true || apply=false
}

current="$(current_json)"
if [[ "$interactive" == true ]]; then
  interactive_menu
fi

enabled="${enabled:-$(json_get enabled)}"
engine="${engine:-$(json_get engine)}"
claude_provider="${claude_provider:-$(json_get claude.provider)}"
if [[ "${#qoder_models[@]}" -eq 0 ]]; then
  while IFS= read -r model; do
    [[ -n "$model" ]] && qoder_models+=("$model")
  done < <(json_get qoder.models)
fi

case "$enabled" in
  true|false) ;;
  *) die "--enabled must be true or false" ;;
esac

case "$engine" in
  claude-deepseek) ;;
  qoder) ;;
  *) die "--engine must be claude-deepseek or qoder" ;;
esac

[[ "$claude_provider" == "deepseek" ]] || die "--claude-provider must be deepseek"

if [[ "$engine" == "qoder" ]]; then
  if [[ "$interactive" != true && "$engine_flag_set" == true && "$qoder_model_flag_count" -eq 0 ]]; then
    die "explicit --engine qoder requires at least one --qoder-model"
  fi
  [[ "${#qoder_models[@]}" -ge 1 ]] || die "Qoder requires at least one --qoder-model"
  [[ "${#qoder_models[@]}" -le 2 ]] || die "Qoder allows at most two --qoder-model values"
  for model in "${qoder_models[@]}"; do
    [[ -n "$model" ]] || die "Qoder model cannot be empty"
    [[ "${model,,}" != "auto" ]] || die "Auto is an implicit fallback and cannot be selected"
  done
  if [[ "${#qoder_models[@]}" -eq 2 && "${qoder_models[0]}" == "${qoder_models[1]}" ]]; then
    die "Qoder models must be unique"
  fi
  validate_qoder_models_available
fi

models_env="$(printf '%s\n' "${qoder_models[@]}")"
generated_json="$(
  ENABLED="$enabled" \
  ENGINE="$engine" \
  CLAUDE_PROVIDER="$claude_provider" \
  QODER_MODELS="$models_env" \
  python3 <<'PY'
import json
import os

models = [line for line in os.environ["QODER_MODELS"].splitlines() if line]
data = {
    "enabled": os.environ["ENABLED"] == "true",
    "engine": os.environ["ENGINE"],
    "claude": {"provider": os.environ["CLAUDE_PROVIDER"]},
    "qoder": {"models": models, "implicit_auto_fallback": True},
}
print(json.dumps(data, indent=2, sort_keys=False))
PY
)"

echo "Affected files:"
echo "  - $settings_file"
if [[ "$apply_github_vars" == true ]]; then
  echo "  - GitHub repository variables: AI_REVIEW_ENGINE, AI_REVIEW_CONFIGURED"
fi
echo
echo "Generated $settings_file:"
echo "$generated_json"
echo
if [[ "$engine" == "claude-deepseek" ]]; then
  echo "Required secret: DEEPSEEK_AUTH_TOKEN"
else
  echo "Required secret: QODER_PERSONAL_ACCESS_TOKEN"
  echo "Runtime fallback sequence: ${qoder_models[*]} Auto"
fi

if [[ "$apply" != true ]]; then
  echo
  echo "Dry-run only. No files written."
  exit 0
fi

mkdir -p "$(dirname "$settings_file")"
SETTINGS_FILE="$settings_file" GENERATED_JSON="$generated_json" python3 <<'PY'
import json
import os
import tempfile
from pathlib import Path

path = Path(os.environ["SETTINGS_FILE"])
data = json.loads(os.environ["GENERATED_JSON"])
with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, prefix=f"{path.name}.", delete=False) as f:
    json.dump(data, f, indent=2)
    f.write("\n")
    staging = Path(f.name)
staging.replace(path)
PY

echo
echo "Wrote $settings_file"
git diff -- "$settings_file" .github/qoder/settings.json || true

if [[ "$apply_github_vars" == true ]]; then
  command -v gh >/dev/null 2>&1 || die "gh is required for --apply-github-vars"
  gh auth status >/dev/null
  git remote get-url origin >/dev/null
  gh variable set AI_REVIEW_ENGINE --body "$engine"
  gh variable set AI_REVIEW_CONFIGURED --body "true"
  echo "Updated non-secret GitHub repository variables."
fi
