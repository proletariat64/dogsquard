#!/usr/bin/env bash
set -euo pipefail

# --- Constants ---

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="$(date +%Y%m%dT%H%M%S)"

ALLOWED_MODULES=(governance pr-quality dev-deploy example-app production-profile ai-pr-review)

ALLOWED_CONFIG_KEYS=(
  TARGET_DIR PROJECT_TYPE MODULES
  AI_REVIEW_ENABLED AI_REVIEW_ENGINE QODER_MODELS AI_REVIEW_APPLY_GITHUB_VARS
  RUN_CHECKS COMMIT_PUSH FORCE UNINSTALL
)

AI_MODULE_FILES=(
  .github/workflows/ai-pr-review.yml
  .github/workflows/scripts/ai_review_pr.py
  .github/workflows/prompts/pr-review-policy.md
  .github/workflows/prompts/pr-review-output-contract.md
  .github/claude/deepseek-settings.json
  .github/qoder/settings.json
  scripts/configure-ai-ci.sh
  scripts/upsert-pr-comment.sh
)

AI_EXECUTABLE_FILES=(
  scripts/configure-ai-ci.sh
  scripts/upsert-pr-comment.sh
)

DISABLED_SAFE_CONFIG='{
  "enabled": false,
  "engine": "claude-deepseek",
  "claude": {
    "provider": "deepseek"
  },
  "qoder": {
    "models": ["Qwen3.7-Max"],
    "implicit_auto_fallback": true
  }
}'

# --- Global State ---

mode_install=true
interactive=false
apply=false
force=false
run_checks=false
commit_push=false
uninstall=false

config_file=""
target_dir=""
project_type=""
modules=()

ai_enabled=""
ai_engine=""
ai_apply_github_vars=false
qoder_models=()

config_target_dir=""
config_project_type=""
config_modules=""
config_ai_enabled=""
config_ai_engine=""
config_qoder_models=""
config_ai_apply_github_vars=""
config_run_checks=""
config_commit_push=""
config_force=""
config_uninstall=""

cli_target_dir=false
cli_project_type=false
cli_modules=false
cli_ai_enabled=false
cli_ai_engine=false
cli_ai_apply_github_vars=false
cli_run_checks=false
cli_commit_push=false
cli_force=false
cli_uninstall=false

qoder_models_from_config=()
qoder_models_from_cli=()

plan_items_file=""
ledger_file=""
manifest_files=()
manifest_dirs=()
validation_succeeded=false

# --- Helper Functions ---

fail() {
  echo "FAIL: $*" >&2
  exit 2
}

warn() {
  echo "WARN: $*" >&2
}

validate_bool() {
  local name="$1" value="$2"
  case "$value" in
    true|false) ;;
    *) fail "$name must be true or false." ;;
  esac
}

file_sha256() {
  local path="$1"
  if [[ -f "$path" ]]; then
    sha256sum "$path" | awk '{print $1}'
  else
    echo "null"
  fi
}

in_array() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

prompt_yes_no() {
  local prompt="$1" default="$2" answer
  read -r -p "$prompt [$default]: " answer
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES|true|TRUE) echo "true" ;;
    n|N|no|NO|false|FALSE) echo "false" ;;
    *) fail "expected yes or no" ;;
  esac
}

prompt_choice() {
  local prompt="$1" default="$2" answer
  read -r -p "$prompt [$default]: " answer
  echo "${answer:-$default}"
}

# --- Usage ---

usage() {
  cat <<'USAGE'
Usage:
  ./install                                    Interactive menu mode
  ./install --menu                             Interactive menu mode
  ./install --help                             Show this help
  ./install --uninstall --repo <target>        Uninstall dry-run
  ./install --uninstall --repo <target> --apply  Uninstall apply

Non-interactive install:
  ./install --repo <target> --project-type <type> --modules <list> [--apply]

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
  - Uninstall without manifest fails safely.
USAGE
}

# --- Config File Parser ---

parse_config_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "config file not found: $file"

  local seen_keys=()
  local line_num=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))

    [[ -z "${line// /}" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    if [[ "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"

      key="${key%"${key##*[![:space:]]}"}"
      key="${key#"${key%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"
      value="${value#"${value%%[![:space:]]*}"}"

      in_array "$key" "${ALLOWED_CONFIG_KEYS[@]}" || fail "unknown config key at line $line_num: $key"
      in_array "$key" "${seen_keys[@]}" && fail "duplicate config key at line $line_num: $key"
      seen_keys+=("$key")

      case "${value,,}" in
        *sk_*|*secret*|*password*|*token=*|*ghp_*|*glpat-*|*pat-*)
          fail "config value at line $line_num looks like a secret. Config files must not contain secret values."
          ;;
      esac

      case "$key" in
        TARGET_DIR) config_target_dir="$value" ;;
        PROJECT_TYPE) config_project_type="$value" ;;
        MODULES) config_modules="$value" ;;
        AI_REVIEW_ENABLED) config_ai_enabled="$value" ;;
        AI_REVIEW_ENGINE) config_ai_engine="$value" ;;
        QODER_MODELS)
          config_qoder_models="$value"
          IFS=',' read -ra qoder_models_from_config <<< "$value"
          ;;
        AI_REVIEW_APPLY_GITHUB_VARS) config_ai_apply_github_vars="$value" ;;
        RUN_CHECKS) config_run_checks="$value" ;;
        COMMIT_PUSH) config_commit_push="$value" ;;
        FORCE) config_force="$value" ;;
        UNINSTALL) config_uninstall="$value" ;;
      esac
    else
      fail "invalid config syntax at line $line_num: $line"
    fi
  done < "$file"
}

# --- CLI Flag Parser ---

parse_cli_flags() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --menu)
        interactive=true
        shift
        ;;
      --config)
        [[ "$#" -ge 2 ]] || fail "--config requires a file path"
        config_file="$2"
        shift 2
        ;;
      --repo)
        [[ "$#" -ge 2 ]] || fail "--repo requires a path"
        target_dir="$2"
        cli_target_dir=true
        shift 2
        ;;
      --project-type)
        [[ "$#" -ge 2 ]] || fail "--project-type requires a value"
        project_type="$2"
        cli_project_type=true
        shift 2
        ;;
      --modules)
        [[ "$#" -ge 2 ]] || fail "--modules requires a comma-separated list"
        IFS=',' read -ra modules <<< "$2"
        cli_modules=true
        shift 2
        ;;
      --ai-enabled)
        [[ "$#" -ge 2 ]] || fail "--ai-enabled requires true or false"
        ai_enabled="$2"
        cli_ai_enabled=true
        shift 2
        ;;
      --ai-engine)
        [[ "$#" -ge 2 ]] || fail "--ai-engine requires a value"
        ai_engine="$2"
        cli_ai_engine=true
        shift 2
        ;;
      --qoder-model)
        [[ "$#" -ge 2 ]] || fail "--qoder-model requires a value"
        qoder_models_from_cli+=("$2")
        qoder_models+=("$2")
        shift 2
        ;;
      --ai-apply-github-vars)
        ai_apply_github_vars=true
        cli_ai_apply_github_vars=true
        shift
        ;;
      --apply)
        apply=true
        shift
        ;;
      --force)
        force=true
        cli_force=true
        shift
        ;;
      --run-checks)
        run_checks=true
        cli_run_checks=true
        shift
        ;;
      --no-run-checks)
        run_checks=false
        cli_run_checks=true
        shift
        ;;
      --commit-push)
        commit_push=true
        cli_commit_push=true
        shift
        ;;
      --uninstall)
        uninstall=true
        mode_install=false
        cli_uninstall=true
        shift
        ;;
      *)
        fail "unknown argument: $1"
        ;;
    esac
  done
}

# --- Merge Config + CLI ---

merge_config() {
  [[ -z "$config_target_dir" || "$cli_target_dir" == true ]] || target_dir="$config_target_dir"
  [[ -z "$config_project_type" || "$cli_project_type" == true ]] || project_type="$config_project_type"

  if [[ -n "$config_modules" && "$cli_modules" != true ]]; then
    IFS=',' read -ra modules <<< "$config_modules"
  fi

  if [[ -n "$config_ai_enabled" && "$cli_ai_enabled" != true ]]; then
    ai_enabled="$config_ai_enabled"
  fi
  if [[ -n "$config_ai_engine" && "$cli_ai_engine" != true ]]; then
    ai_engine="$config_ai_engine"
  fi

  if [[ "${#qoder_models_from_config[@]}" -gt 0 && "${#qoder_models_from_cli[@]}" -eq 0 ]]; then
    qoder_models=("${qoder_models_from_config[@]}")
  fi

  if [[ -n "$config_ai_apply_github_vars" && "$cli_ai_apply_github_vars" != true ]]; then
    [[ "$config_ai_apply_github_vars" == true ]] && ai_apply_github_vars=true
  fi
  if [[ -n "$config_run_checks" && "$cli_run_checks" != true ]]; then
    [[ "$config_run_checks" == true ]] && run_checks=true || run_checks=false
  fi
  if [[ -n "$config_commit_push" && "$cli_commit_push" != true ]]; then
    [[ "$config_commit_push" == true ]] && commit_push=true || commit_push=false
  fi
  if [[ -n "$config_force" && "$cli_force" != true ]]; then
    [[ "$config_force" == true ]] && force=true || force=false
  fi
  if [[ -n "$config_uninstall" && "$cli_uninstall" != true ]]; then
    [[ "$config_uninstall" == true ]] && uninstall=true && mode_install=false
  fi
}

# --- Input Validation ---

validate_inputs() {
  if [[ "$mode_install" == true ]]; then
    [[ -n "$target_dir" ]] || fail "--repo is required for install mode."
    [[ -n "$project_type" ]] || fail "--project-type is required for install mode."

    case "$project_type" in
      node|go-js|docs-only) ;;
      *) fail "PROJECT_TYPE must be node, go-js, or docs-only." ;;
    esac

    [[ "${#modules[@]}" -gt 0 ]] || fail "--modules is required for install mode."

    local has_bootstrap_base=false
    local module
    for module in "${modules[@]}"; do
      in_array "$module" "${ALLOWED_MODULES[@]}" || fail "unknown module: $module"
      case "$module" in
        governance|pr-quality) has_bootstrap_base=true ;;
      esac
    done

    for module in "${modules[@]}"; do
      case "$module" in
        dev-deploy|example-app|production-profile)
          $has_bootstrap_base || fail "module '$module' requires governance or pr-quality to be selected (bootstrap base required in MVP)."
          ;;
      esac
    done

    if [[ "$ai_apply_github_vars" == true && "$apply" != true ]]; then
      fail "--ai-apply-github-vars requires --apply."
    fi

    if in_array ai-pr-review "${modules[@]}"; then
      validate_ai_inputs
    fi
  fi

  if [[ -n "$target_dir" ]]; then
    if [[ -d "$target_dir" ]]; then
      target_dir="$(cd "$target_dir" && pwd)"
    elif [[ "$mode_install" == true ]]; then
      fail "target directory does not exist: $target_dir"
    fi

    [[ "$target_dir" != "$ROOT_DIR" ]] || fail "target directory must not be the Dogsquard repository itself."
  fi

  if [[ "$uninstall" == true ]]; then
    [[ -n "$target_dir" ]] || fail "--repo is required for uninstall mode."
    [[ -d "$target_dir" ]] || fail "target directory does not exist: $target_dir"
  fi
}

validate_ai_inputs() {
  if [[ -n "$ai_enabled" ]]; then
    validate_bool "AI_REVIEW_ENABLED" "$ai_enabled"
  fi

  if [[ -n "$ai_engine" ]]; then
    case "$ai_engine" in
      claude-deepseek|qoder) ;;
      *) fail "AI_REVIEW_ENGINE must be claude-deepseek or qoder." ;;
    esac
  fi

  if [[ "$ai_engine" == "qoder" ]]; then
    [[ "${#qoder_models[@]}" -ge 1 ]] || fail "AI_REVIEW_ENGINE=qoder requires at least one --qoder-model."
    [[ "${#qoder_models[@]}" -le 2 ]] || fail "Qoder allows at most two --qoder-model values."

    local model
    for model in "${qoder_models[@]}"; do
      [[ -n "$model" ]] || fail "Qoder model cannot be empty."
      [[ "${model,,}" != "auto" ]] || fail "Auto is an implicit runner fallback and cannot be user-selected."
    done

    if [[ "${#qoder_models[@]}" -eq 2 && "${qoder_models[0]}" == "${qoder_models[1]}" ]]; then
      fail "Qoder models must be unique."
    fi
  fi

  if [[ "$ai_engine" == "claude-deepseek" && "${#qoder_models[@]}" -gt 0 ]]; then
    fail "AI_REVIEW_ENGINE=claude-deepseek must not include --qoder-model values."
  fi
}

# --- Ledger Operations ---

ledger_entry() {
  local operation="$1" action="$2" path="$3"
  local source="${4:-}" module="${5:-}"
  local existed_before="${6:-false}" sha256_before="${7:-null}" sha256_after="${8:-null}" backup_path="${9:-null}"

  [[ -n "${ledger_file:-}" && -n "${ledger_file}" ]] || return 0

  python3 -c "
import json, sys
entry = {
    'tool': 'install.sh',
    'module': sys.argv[1],
    'operation': sys.argv[2],
    'action': sys.argv[3],
    'path': sys.argv[4],
    'source': sys.argv[5] if sys.argv[5] else None,
    'existed_before': sys.argv[6] == 'true',
    'force': sys.argv[7] == 'true',
    'dry_run': sys.argv[8] == 'true',
    'sha256_before': sys.argv[9] if sys.argv[9] != 'null' else None,
    'sha256_after': sys.argv[10] if sys.argv[10] != 'null' else None,
    'backup_path': sys.argv[11] if sys.argv[11] != 'null' else None,
}
print(json.dumps(entry))
" "$module" "$operation" "$action" "$path" "$source" "$existed_before" "$force" \
  "$([ "$apply" = true ] && echo false || echo true)" "$sha256_before" "$sha256_after" "$backup_path" \
  >> "$ledger_file"
}

# --- Plan Builder ---

init_plan_workspace() {
  mkdir -p "$ROOT_DIR/.tmp/install"
  plan_items_file="$(mktemp)"
  ledger_file="$(mktemp)"
  trap 'rm -f "$plan_items_file" "$ledger_file"' EXIT
}

add_plan_item() {
  python3 -c "
import json, sys
item = {
    'id': sys.argv[1],
    'module': sys.argv[2],
    'kind': sys.argv[3],
    'action': sys.argv[4],
    'source': sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else None,
    'target': sys.argv[6] if len(sys.argv) > 6 and sys.argv[6] else None,
    'exists_before': sys.argv[7] == 'true' if len(sys.argv) > 7 else False,
    'requires_force': sys.argv[8] == 'true' if len(sys.argv) > 8 else False,
    'will_write': sys.argv[9] == 'true' if len(sys.argv) > 9 else False,
    'reason': sys.argv[10] if len(sys.argv) > 10 and sys.argv[10] else '',
}
print(json.dumps(item))
" "$@" >> "$plan_items_file"
}

plan_counter=0
next_plan_id() {
  plan_counter=$((plan_counter + 1))
  printf "plan-%04d" "$plan_counter"
}

build_plan() {
  echo
  echo "=== Dogsquard Install Plan ==="
  echo "Target:   $target_dir"
  echo "Mode:     $([ "$apply" = true ] && echo 'APPLY' || echo 'DRY-RUN')"
  echo "Force:    $force"

  if [[ "$mode_install" == true ]]; then
    echo "Type:     $project_type"
    echo "Modules:  ${modules[*]}"

    local needs_bootstrap=false
    local module
    for module in "${modules[@]}"; do
      case "$module" in
        governance|pr-quality|dev-deploy|example-app|production-profile)
          needs_bootstrap=true
          ;;
      esac
    done

    if [[ "$needs_bootstrap" == true ]]; then
      echo
      echo "--- Bootstrap Invocation ---"
      local include_dev_deploy=false include_example_app=false include_production_profile=false
      for module in "${modules[@]}"; do
        case "$module" in
          dev-deploy) include_dev_deploy=true ;;
          example-app) include_example_app=true ;;
          production-profile) include_production_profile=true ;;
        esac
      done
      echo "  PROJECT_TYPE=$project_type"
      echo "  TARGET_DIR=$target_dir"
      echo "  DRY_RUN=$([ "$apply" = true ] && echo false || echo true)"
      echo "  FORCE=$force"
      echo "  INCLUDE_DEV_DEPLOY=$include_dev_deploy"
      echo "  INCLUDE_EXAMPLE_APP=$include_example_app"
      echo "  INCLUDE_PRODUCTION_PROFILE=$include_production_profile"

      add_plan_item "$(next_plan_id)" "bootstrap" "command" "run" "" "" "false" "false" "$apply" "Bootstrap profile-aware installation"
    fi

    if in_array ai-pr-review "${modules[@]}"; then
      echo
      echo "--- AI PR Review Module ---"
      local file
      for file in "${AI_MODULE_FILES[@]}"; do
        local exists_before=false will_write=true action="create"
        [[ -e "$target_dir/$file" ]] && exists_before=true
        if [[ "$exists_before" == true && "$force" != true ]]; then
          action="skip"
          will_write=false
        elif [[ "$exists_before" == true && "$force" == true ]]; then
          action="overwrite"
        fi
        echo "  $action: $file"
        add_plan_item "$(next_plan_id)" "ai-pr-review" "file" "$action" "$file" "$file" "$exists_before" "$([ "$exists_before" = true ] && echo "$force" || echo false)" "$will_write" "AI PR review asset"
      done

      local settings_exists=false
      [[ -e "$target_dir/.github/ai-review/settings.json" ]] && settings_exists=true

      if [[ "$settings_exists" == true && "$force" != true && (-n "$ai_engine" || -n "$ai_enabled") ]]; then
        echo "  FAIL: target .github/ai-review/settings.json exists and --force is not set"
        add_plan_item "$(next_plan_id)" "ai-pr-review" "file" "fail" "" ".github/ai-review/settings.json" "true" "false" "false" "Existing settings conflict with requested config changes"
      elif [[ "$settings_exists" == true && "$force" != true ]]; then
        echo "  preserve: .github/ai-review/settings.json"
        add_plan_item "$(next_plan_id)" "ai-pr-review" "file" "preserve" "" ".github/ai-review/settings.json" "true" "false" "false" "Preserve existing AI review settings"
      elif [[ -n "$ai_engine" || -n "$ai_enabled" ]]; then
        echo "  configure: scripts/configure-ai-ci.sh (pass-through)"
        add_plan_item "$(next_plan_id)" "ai-pr-review" "command" "run" "" "scripts/configure-ai-ci.sh" "false" "false" "$apply" "AI configure pass-through"
      else
        echo "  write: .github/ai-review/settings.json (disabled safe config)"
        add_plan_item "$(next_plan_id)" "ai-pr-review" "file" "write" "" ".github/ai-review/settings.json" "false" "false" "$apply" "Disabled safe AI review config"
        echo "  NEXT: cd $target_dir && scripts/configure-ai-ci.sh"
      fi
    fi
  fi

  echo
  echo "--- Validation ---"
  if [[ "$run_checks" == true ]]; then
    echo "  git diff --check"
    echo "  bash -n scripts/*.sh"
    add_plan_item "$(next_plan_id)" "" "validation" "run" "" "" "false" "false" "$apply" "Target validation"
  else
    echo "  skipped (--no-run-checks)"
  fi

  echo
  echo "--- Commit/Push ---"
  if [[ "$commit_push" == true ]]; then
    echo "  commit and push target changes"
    add_plan_item "$(next_plan_id)" "" "commit" "run" "" "" "false" "false" "$apply" "Commit and push target changes"
  else
    echo "  skipped (use --commit-push to enable)"
  fi

  echo
  if [[ "$apply" != true ]]; then
    echo "Dry-run complete. Use --apply to write files."
  fi
}

# --- Backup Policy ---

backup_file() {
  local target_path="$1" relative_path="$2"
  local backup_dir="$target_dir/.dogsquard/backups/$TIMESTAMP"
  local backup_path="$backup_dir/$relative_path"

  mkdir -p "$(dirname "$backup_path")" || fail "failed to create backup directory for $relative_path"
  cp "$target_path" "$backup_path" || fail "failed to backup $relative_path"

  local sha256_before
  sha256_before="$(file_sha256 "$target_path")"
  echo "$backup_path"
}

# --- Apply: Bootstrap-backed Modules ---

apply_bootstrap_modules() {
  local needs_bootstrap=false
  local module
  for module in "${modules[@]}"; do
    case "$module" in
      governance|pr-quality|dev-deploy|example-app|production-profile)
        needs_bootstrap=true
        ;;
    esac
  done

  [[ "$needs_bootstrap" == true ]] || return 0

  local include_dev_deploy=false include_example_app=false include_production_profile=false
  for module in "${modules[@]}"; do
    case "$module" in
      dev-deploy) include_dev_deploy=true ;;
      example-app) include_example_app=true ;;
      production-profile) include_production_profile=true ;;
    esac
  done

  echo
  echo "Running bootstrap..."

  PROJECT_TYPE="$project_type" \
  TARGET_DIR="$target_dir" \
  DRY_RUN="$([ "$apply" = true ] && echo false || echo true)" \
  FORCE="$force" \
  INCLUDE_DEV_DEPLOY="$include_dev_deploy" \
  INCLUDE_EXAMPLE_APP="$include_example_app" \
  INCLUDE_PRODUCTION_PROFILE="$include_production_profile" \
  DOGSQUARD_LEDGER_FILE="$ledger_file" \
  "$ROOT_DIR/scripts/bootstrap-project.sh"
}

# --- Apply: AI PR Review Module ---

apply_ai_pr_review() {
  in_array ai-pr-review "${modules[@]}" || return 0

  echo
  echo "Installing AI PR review module..."

  local file
  for file in "${AI_MODULE_FILES[@]}"; do
    local dest="$target_dir/$file"
    local src="$ROOT_DIR/$file"

    [[ -f "$src" ]] || fail "source AI file missing: $file"

    if [[ -e "$dest" && "$force" != true ]]; then
      echo "SKIP exists: $file"
      ledger_entry "copy_file" "skipped" "$file" "$file" "ai-pr-review" "true" "null" "null"
      continue
    fi

    local sha256_before="null" backup_path="null"
    if [[ -e "$dest" && "$force" == true ]]; then
      sha256_before="$(file_sha256 "$dest")"
      backup_path="$(backup_file "$dest" "$file")"
      echo "BACKUP: $file -> $backup_path"
      ledger_entry "backup" "backup_created" "$file" "$file" "ai-pr-review" "true" "$sha256_before" "null" "$backup_path"
    fi

    if [[ "$apply" == true ]]; then
      mkdir -p "$(dirname "$dest")"
      cp "$src" "$dest"
      local sha256_after
      sha256_after="$(file_sha256 "$dest")"

      if in_array "$file" "${AI_EXECUTABLE_FILES[@]}"; then
        chmod +x "$dest"
      fi

      echo "CREATED: $file"
      ledger_entry "copy_file" "$([ "$sha256_before" = "null" ] && echo "created" || echo "overwritten")" "$file" "$file" "ai-pr-review" \
        "$([ "$sha256_before" != "null" ] && echo true || echo false)" "$sha256_before" "$sha256_after" "$backup_path"
    else
      echo "PLAN copy: $file"
    fi
  done

  mkdir -p "$target_dir/.github/workflows/prompts" 2>/dev/null || true

  local settings_dest="$target_dir/.github/ai-review/settings.json"
  local settings_existed=false
  [[ -e "$settings_dest" ]] && settings_existed=true

  if [[ "$settings_existed" == true && "$force" != true && (-n "$ai_engine" || -n "$ai_enabled") ]]; then
    fail "target .github/ai-review/settings.json exists and --force is not set. Use --force to overwrite, or remove AI config flags to preserve."
  fi

  if [[ "$settings_existed" == true && "$force" != true ]]; then
    echo "PRESERVE: .github/ai-review/settings.json (existing target config kept)"
    ledger_entry "write_file" "preserved" ".github/ai-review/settings.json" "" "ai-pr-review" "true" "null" "null"
    print_ai_secret_names
    return 0
  fi

  if [[ -n "$ai_engine" || -n "$ai_enabled" ]]; then
    if [[ "$apply" == true ]]; then
      local settings_backup_path="null"
      if [[ "$settings_existed" == true && "$force" == true ]]; then
        local sha256_before
        sha256_before="$(file_sha256 "$settings_dest")"
        local bk
        bk="$(backup_file "$settings_dest" ".github/ai-review/settings.json")"
        echo "BACKUP: .github/ai-review/settings.json -> $bk"
        settings_backup_path="$bk"
        ledger_entry "backup" "backup_created" ".github/ai-review/settings.json" "" "ai-pr-review" "true" "$sha256_before" "null" "$bk"
      fi

      local configure_args=()
      [[ -n "$ai_enabled" ]] && configure_args+=(--enabled "$ai_enabled")
      [[ -n "$ai_engine" ]] && configure_args+=(--engine "$ai_engine")
      local model
      for model in "${qoder_models[@]}"; do
        configure_args+=(--qoder-model "$model")
      done
      configure_args+=(--apply)
      [[ "$ai_apply_github_vars" == true ]] && configure_args+=(--apply-github-vars)

      echo "Running: scripts/configure-ai-ci.sh ${configure_args[*]}"
      (cd "$target_dir" && bash scripts/configure-ai-ci.sh "${configure_args[@]}")

      local sha256_after
      sha256_after="$(file_sha256 "$settings_dest")"
      ledger_entry "write_file" "$([ "$settings_existed" = true ] && echo "overwritten" || echo "created")" \
        ".github/ai-review/settings.json" "" "ai-pr-review" \
        "$settings_existed" "null" \
        "$sha256_after" "$settings_backup_path"
    else
      local configure_args=()
      [[ -n "$ai_enabled" ]] && configure_args+=(--enabled "$ai_enabled")
      [[ -n "$ai_engine" ]] && configure_args+=(--engine "$ai_engine")
      local model
      for model in "${qoder_models[@]}"; do
        configure_args+=(--qoder-model "$model")
      done
      configure_args+=(--apply)
      [[ "$ai_apply_github_vars" == true ]] && configure_args+=(--apply-github-vars)
      echo "PLAN: cd $target_dir && scripts/configure-ai-ci.sh ${configure_args[*]}"
    fi
  else
    if [[ "$apply" == true ]]; then
      if [[ "$settings_existed" != true ]]; then
        mkdir -p "$(dirname "$settings_dest")"
        echo "$DISABLED_SAFE_CONFIG" > "$settings_dest"
        local sha256_after
        sha256_after="$(file_sha256 "$settings_dest")"
        echo "CREATED: .github/ai-review/settings.json (disabled safe config)"
        ledger_entry "write_file" "created" ".github/ai-review/settings.json" "" "ai-pr-review" "false" "null" "$sha256_after"
      fi
      echo
      echo "Next step: cd $target_dir && scripts/configure-ai-ci.sh"
    else
      echo "PLAN: write disabled safe .github/ai-review/settings.json"
      echo "NEXT: cd $target_dir && scripts/configure-ai-ci.sh"
    fi
  fi

  print_ai_secret_names
}

print_ai_secret_names() {
  echo
  if [[ "$ai_engine" == "claude-deepseek" ]]; then
    echo "Required secret: DEEPSEEK_AUTH_TOKEN"
  elif [[ "$ai_engine" == "qoder" ]]; then
    echo "Required secret: QODER_PERSONAL_ACCESS_TOKEN"
  else
    echo "Required secrets by engine:"
    echo "  claude-deepseek: DEEPSEEK_AUTH_TOKEN"
    echo "  qoder:           QODER_PERSONAL_ACCESS_TOKEN"
  fi
}

# --- Manifest Writer ---

write_manifest() {
  [[ "$apply" == true ]] || return 0

  local manifest_dir="$target_dir/.dogsquard"
  mkdir -p "$manifest_dir"

  local dogsquard_commit="unknown"
  if git -C "$ROOT_DIR" rev-parse HEAD >/dev/null 2>&1; then
    dogsquard_commit="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  fi

  local target_remote=""
  if git -C "$target_dir" remote get-url origin >/dev/null 2>&1; then
    target_remote="$(git -C "$target_dir" remote get-url origin)"
  fi

  local target_branch=""
  if git -C "$target_dir" rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    target_branch="$(git -C "$target_dir" rev-parse --abbrev-ref HEAD)"
  fi

  local modules_json
  modules_json="$(printf '%s\n' "${modules[@]}" | python3 -c "import json,sys; print(json.dumps([l.strip() for l in sys.stdin]))")"

  local ai_review_json='null'
  if in_array ai-pr-review "${modules[@]}"; then
    local py_configured="False" py_enabled="False" py_apply_vars="False" py_engine="None" py_models="[]"
    [[ -n "$ai_engine" ]] && py_configured="True"
    [[ "$ai_enabled" == true ]] && py_enabled="True"
    [[ "$ai_apply_github_vars" == true ]] && py_apply_vars="True"
    [[ -n "$ai_engine" ]] && py_engine="\"$ai_engine\""
    if [[ ${#qoder_models[@]} -gt 0 ]]; then
      py_models="$(printf '%s\n' "${qoder_models[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin]))')"
    fi
    ai_review_json="$(python3 -c "
import json
data = {
    'configured': $py_configured,
    'enabled': $py_enabled,
    'engine': $py_engine,
    'qoder_models': $py_models,
    'apply_github_vars': $py_apply_vars,
}
print(json.dumps(data))
")"
  fi

  local files_json="[]"
  if [[ -s "$ledger_file" ]]; then
    files_json="$(python3 -c "
import json, sys

files = []
for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    entry = json.loads(line)
    if entry['operation'] in ('copy_file', 'write_file') and entry['action'] not in ('skipped', 'preserved', 'planned'):
        files.append({
            'path': entry['path'],
            'module': entry.get('module', ''),
            'action': entry['action'],
            'source': entry.get('source'),
            'sha256_before': entry.get('sha256_before'),
            'sha256_after': entry.get('sha256_after'),
            'backup_path': entry.get('backup_path'),
        })
print(json.dumps(files))
" "$ledger_file")"
  fi

  local dirs_json='[{"path": ".dogsquard", "action": "created"}]'

  local install_ts
  install_ts="$(date -Iseconds)"

  python3 -c "
import json, sys

manifest = {
    'schema_version': '1',
    'installed_at': sys.argv[1],
    'dogsquard_source': {
        'path': sys.argv[2],
        'git_commit': sys.argv[3],
    },
    'target': {
        'path': sys.argv[4],
        'git_remote_origin': sys.argv[5] if sys.argv[5] else None,
        'git_branch': sys.argv[6] if sys.argv[6] else None,
    },
    'project_type': sys.argv[7],
    'modules': json.loads(sys.argv[8]),
    'options': {
        'force': sys.argv[9] == 'true',
        'run_checks': sys.argv[10] == 'true',
        'commit_push': sys.argv[11] == 'true',
    },
    'ai_review': json.loads(sys.argv[12]),
    'files': json.loads(sys.argv[13]),
    'directories': json.loads(sys.argv[14]),
    'validation': {
        'run_checks': sys.argv[10] == 'true',
        'commands': [],
    },
}

print(json.dumps(manifest, indent=2))
" "$install_ts" "$ROOT_DIR" "$dogsquard_commit" "$target_dir" "$target_remote" "$target_branch" \
  "$project_type" "$modules_json" "$force" "$run_checks" "$commit_push" "$ai_review_json" \
  "$files_json" "$dirs_json" > "$target_dir/.dogsquard/install-manifest.json.tmp"

  mv "$target_dir/.dogsquard/install-manifest.json.tmp" "$target_dir/.dogsquard/install-manifest.json"
  echo
  echo "Manifest written: $target_dir/.dogsquard/install-manifest.json"
}

# --- Validation Flow ---

run_validation() {
  [[ "$run_checks" == true && "$apply" == true ]] || return 0

  echo
  echo "Running validation..."

  local failed=false

  echo "  git diff --check"
  if ! git -C "$target_dir" diff --check 2>/dev/null; then
    warn "git diff --check found whitespace issues"
    failed=true
  fi

  local target_scripts=()
  if ls "$target_dir"/scripts/*.sh >/dev/null 2>&1; then
    echo "  bash -n scripts/*.sh"
    if ! (cd "$target_dir" && bash -n scripts/*.sh 2>&1); then
      warn "bash syntax check failed"
      failed=true
    fi
  fi

  if in_array ai-pr-review "${modules[@]}"; then
    if [[ -f "$target_dir/scripts/configure-ai-ci.sh" ]]; then
      echo "  bash -n scripts/configure-ai-ci.sh"
      if ! bash -n "$target_dir/scripts/configure-ai-ci.sh" 2>&1; then
        warn "configure-ai-ci.sh syntax check failed"
        failed=true
      fi
    fi

    if [[ -f "$target_dir/.github/workflows/scripts/ai_review_pr.py" ]]; then
      echo "  python3 -m py_compile ai_review_pr.py"
      if ! python3 -m py_compile "$target_dir/.github/workflows/scripts/ai_review_pr.py" 2>&1; then
        warn "ai_review_pr.py compile check failed"
        failed=true
      fi
    fi

    local json_file
    for json_file in .github/ai-review/settings.json .github/qoder/settings.json .github/claude/deepseek-settings.json; do
      if [[ -f "$target_dir/$json_file" ]]; then
        echo "  python3 -m json.tool $json_file"
        if ! python3 -m json.tool "$target_dir/$json_file" >/dev/null 2>&1; then
          warn "JSON validation failed: $json_file"
          failed=true
        fi
      fi
    done

    if [[ -f "$target_dir/.github/workflows/scripts/ai_review_pr.py" && -f "$target_dir/.github/ai-review/settings.json" ]]; then
      echo "  python3 ai_review_pr.py --resolve-config"
      if ! (cd "$target_dir" && python3 .github/workflows/scripts/ai_review_pr.py --resolve-config >/dev/null 2>&1); then
        warn "ai_review_pr.py --resolve-config failed"
        failed=true
      fi
    fi
  fi

  if [[ -f "$target_dir/Makefile" ]]; then
    echo "  make help"
    if ! make -C "$target_dir" help >/dev/null 2>&1; then
      warn "make help failed"
      failed=true
    fi

    if [[ -f "$target_dir/scripts/doc-check-local.sh" ]]; then
      echo "  make doc-check"
      if ! make -C "$target_dir" doc-check >/dev/null 2>&1; then
        warn "make doc-check failed"
        failed=true
      fi
    fi

    if [[ -f "$target_dir/scripts/doc-guard.sh" ]]; then
      echo "  make doc-guard"
      if ! make -C "$target_dir" doc-guard >/dev/null 2>&1; then
        warn "make doc-guard failed"
        failed=true
      fi
    fi
  fi

  if [[ "$failed" == true ]]; then
    echo
    echo "Validation FAILED. Review the warnings above."
    echo "Files were written but validation did not pass."
    echo "Commit/push is not recommended until validation passes."
    validation_succeeded=false
    return 1
  fi

  echo "Validation passed."
  validation_succeeded=true
}

# --- Commit/Push Flow ---

commit_and_push() {
  [[ "$commit_push" == true && "$apply" == true ]] || return 0

  echo
  echo "Commit/Push..."

  if ! git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "target is not a git repository. Cannot commit/push."
  fi

  if [[ "$run_checks" == true && "$validation_succeeded" != true ]]; then
    fail "validation did not pass. Commit/push requires successful validation."
  fi

  local branch
  branch="$(git -C "$target_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

  if [[ "$branch" == "main" || "$branch" == "master" || -z "$branch" ]]; then
    if [[ "$interactive" == true ]]; then
      local new_branch
      new_branch="$(prompt_choice "Current branch is '$branch'. Enter feature branch name" "feature/dogsquard-install")"
      git -C "$target_dir" checkout -b "$new_branch"
      branch="$new_branch"
    else
      fail "current branch is '$branch'. Create a feature branch first, or use --menu for interactive branch selection."
    fi
  fi

  echo "Changes in target:"
  git -C "$target_dir" status --short

  local staged_files=()

  if [[ -f "$target_dir/.dogsquard/install-manifest.json" ]]; then
    staged_files+=(".dogsquard/install-manifest.json")
  fi

  if [[ -s "$ledger_file" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local path
      path="$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['path'])")"
      local action
      action="$(echo "$line" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['action'])")"
      if [[ "$action" != "skipped" && "$action" != "preserved" && "$action" != "planned" ]]; then
        staged_files+=("$path")
      fi
    done < "$ledger_file"
  fi

  local file
  for file in "${staged_files[@]}"; do
    if [[ -e "$target_dir/$file" ]]; then
      git -C "$target_dir" add -- "$file"
    fi
  done

  if git -C "$target_dir" diff --cached --quiet; then
    echo "No target changes to commit."
    return 0
  fi

  git -C "$target_dir" commit -m "Install Dogsquard modules"

  if git -C "$target_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    git -C "$target_dir" push
    echo "Pushed to existing upstream."
  else
    git -C "$target_dir" push -u origin HEAD
    echo "Pushed and set upstream for current branch."
  fi
}

# --- Uninstall Flow ---

run_uninstall() {
  local manifest_path="$target_dir/.dogsquard/install-manifest.json"

  if [[ ! -f "$manifest_path" ]]; then
    fail "no Dogsquard install manifest found at $manifest_path
Refusing broad cleanup. Use manual review or a future audited fallback."
  fi

  local schema_version
  schema_version="$(python3 -c "import json; print(json.load(open('$manifest_path'))['schema_version'])")"
  [[ "$schema_version" == "1" ]] || fail "unsupported manifest schema version: $schema_version"

  echo
  echo "=== Dogsquard Uninstall Plan ==="
  echo "Target: $target_dir"
  echo "Mode:   $([ "$apply" = true ] && echo 'APPLY' || echo 'DRY-RUN')"
  echo

  local uninstall_plan
  uninstall_plan="$(python3 -c "
import json, sys, hashlib, os

manifest = json.load(open(sys.argv[1]))
target = sys.argv[2]
dry_run = sys.argv[3] == 'true'

plan = []
for f in manifest.get('files', []):
    path = os.path.join(target, f['path'])
    action = f['action']
    if action in ('skipped', 'preserved'):
        plan.append(('SKIP', f['path'], 'pre-existing file, not Dogsquard-managed'))
        continue
    if action in ('created', 'overwritten'):
        if os.path.isfile(path):
            current_sha = hashlib.sha256(open(path, 'rb').read()).hexdigest()
            expected_sha = f.get('sha256_after')
            if expected_sha and current_sha != expected_sha:
                plan.append(('FAIL', f['path'], f'checksum mismatch: current={current_sha[:12]} expected={expected_sha[:12]}'))
                continue
        if action == 'created':
            plan.append(('REMOVE', f['path'], f'sha256={f.get(\"sha256_after\", \"unknown\")}'))
        elif action == 'overwritten':
            backup = f.get('backup_path', '')
            if backup:
                backup_check = backup if os.path.isabs(backup) else os.path.join(target, backup.lstrip('./'))
                if os.path.isfile(backup_check):
                    plan.append(('RESTORE', f['path'], f'from backup: {backup}'))
                else:
                    plan.append(('FAIL', f['path'], f'backup not found: {backup}'))
            else:
                plan.append(('FAIL', f['path'], f'backup not found: {backup}'))

dirs = []
for d in manifest.get('directories', []):
    dirs.append(d['path'])

for action, path, reason in plan:
    print(f'  {action}: {path} ({reason})')

for d in dirs:
    print(f'  DIR_REMOVE: {d} (if empty)')

print(f'  REMOVE: .dogsquard/install-manifest.json')
print(f'  DIR_REMOVE: .dogsquard (if empty)')

has_failure = any(a == 'FAIL' for a, _, _ in plan)
if has_failure:
    print()
    print('Uninstall plan has failures. Resolve manually before applying.')
" "$manifest_path" "$target_dir" "$([ "$apply" = true ] && echo false || echo true)")"

  echo "$uninstall_plan"

  if echo "$uninstall_plan" | grep -q "FAIL:"; then
    if [[ "$apply" == true ]]; then
      fail "uninstall plan has failures. Cannot apply."
    fi
    echo
    echo "Dry-run complete. Resolve failures before applying."
    return 0
  fi

  echo
  if [[ "$apply" != true ]]; then
    echo "Dry-run complete. Use --apply to execute uninstall."
    return 0
  fi

  echo "Executing uninstall..."

  python3 -c "
import json, hashlib, os, shutil

manifest = json.load(open(sys.argv[1])) if 'sys' in dir() else None
" 2>/dev/null || true

  python3 - "$manifest_path" "$target_dir" <<'PY'
import json, hashlib, os, shutil, sys

manifest = json.load(open(sys.argv[1]))
target = sys.argv[2]

for f in manifest.get('files', []):
    path = os.path.join(target, f['path'])
    action = f['action']
    if action in ('skipped', 'preserved'):
        continue
    if action == 'created':
        if os.path.isfile(path):
            current = hashlib.sha256(open(path, 'rb').read()).hexdigest()
            expected = f.get('sha256_after')
            if expected and current != expected:
                print(f"FAIL: checksum mismatch for {f['path']}, skipping removal")
                sys.exit(1)
            os.remove(path)
            print(f"REMOVED: {f['path']}")
    elif action == 'overwritten':
        backup = f.get('backup_path', '')
        if backup:
            backup_full = backup if os.path.isabs(backup) else os.path.join(target, backup.lstrip('./'))
            if os.path.isfile(backup_full):
                if os.path.isfile(path):
                    current = hashlib.sha256(open(path, 'rb').read()).hexdigest()
                    expected = f.get('sha256_after')
                    if expected and current != expected:
                        print(f"FAIL: checksum mismatch for {f['path']}, skipping restore")
                        sys.exit(1)
                shutil.copy2(backup_full, path)
                os.remove(backup_full)
                print(f"RESTORED: {f['path']} from {backup}")
            else:
                print(f"FAIL: backup not found for {f['path']}: {backup}")
                sys.exit(1)

for d in manifest.get('directories', []):
    dirpath = os.path.join(target, d['path'])
    if os.path.isdir(dirpath):
        try:
            os.rmdir(dirpath)
            print(f"DIR_REMOVED: {d['path']}")
        except OSError:
            print(f"DIR_SKIP (not empty): {d['path']}")

manifest_path = os.path.join(target, '.dogsquard', 'install-manifest.json')
if os.path.isfile(manifest_path):
    os.remove(manifest_path)
    print("REMOVED: .dogsquard/install-manifest.json")

dogsquard_dir = os.path.join(target, '.dogsquard')
if os.path.isdir(dogsquard_dir):
    try:
        os.rmdir(dogsquard_dir)
        print("DIR_REMOVED: .dogsquard")
    except OSError:
        print("DIR_SKIP (not empty): .dogsquard")

print()
print("Uninstall complete.")
print("Note: GitHub secrets and variables were not modified.")
print("To clean up manually:")
print("  gh secret delete DEEPSEEK_AUTH_TOKEN  # if no longer needed")
print("  gh secret delete QODER_PERSONAL_ACCESS_TOKEN  # if no longer needed")
print("  gh variable delete AI_REVIEW_ENGINE  # if no longer needed")
print("  gh variable delete AI_REVIEW_CONFIGURED  # if no longer needed")
PY
}

# --- Interactive Menu ---

interactive_menu() {
  echo "=== Dogsquard Install Menu ==="
  echo

  if [[ "$uninstall" == true ]]; then
    local answer
    answer="$(prompt_yes_no "Uninstall all Dogsquard-managed assets from $target_dir?" "yes")"
    if [[ "$answer" == "true" ]]; then
      apply=true
    fi
    return 0
  fi

  local answer
  target_dir="$(prompt_choice "Target repository path" "${target_dir:-}")"
  [[ -n "$target_dir" ]] || fail "target repository path is required."

  if [[ -d "$target_dir" ]]; then
    target_dir="$(cd "$target_dir" && pwd)"
  else
    fail "target directory does not exist: $target_dir"
  fi

  project_type="$(prompt_choice "Project type (node/go-js/docs-only)" "${project_type:-docs-only}")"
  case "$project_type" in
    node|go-js|docs-only) ;;
    *) fail "invalid project type: $project_type" ;;
  esac

  echo
  echo "Available modules:"
  local i
  for i in "${!ALLOWED_MODULES[@]}"; do
    echo "  $((i + 1)). ${ALLOWED_MODULES[$i]}"
  done
  echo
  local module_input
  read -r -p "Enter module numbers (comma-separated, e.g. 1,2,6): " module_input
  modules=()
  IFS=',' read -ra module_nums <<< "$module_input"
  local num
  for num in "${module_nums[@]}"; do
    num="${num// /}"
    local idx=$((num - 1))
    if (( idx >= 0 && idx < ${#ALLOWED_MODULES[@]} )); then
      modules+=("${ALLOWED_MODULES[$idx]}")
    else
      fail "invalid module number: $num"
    fi
  done
  [[ "${#modules[@]}" -gt 0 ]] || fail "at least one module must be selected."

  if in_array ai-pr-review "${modules[@]}"; then
    echo
    local configure_ai
    configure_ai="$(prompt_yes_no "Configure AI PR review now?" "no")"
    if [[ "$configure_ai" == "true" ]]; then
      ai_enabled="$(prompt_yes_no "Enable AI review?" "true")"
      ai_engine="$(prompt_choice "Engine (claude-deepseek/qoder)" "qoder")"
      case "$ai_engine" in
        claude-deepseek|qoder) ;;
        *) fail "invalid engine: $ai_engine" ;;
      esac
      if [[ "$ai_engine" == "qoder" ]]; then
        qoder_models=()
        local model_input
        read -r -p "Qoder models (comma-separated, 1-2): " model_input
        IFS=',' read -ra qoder_models <<< "$model_input"
        [[ "${#qoder_models[@]}" -ge 1 ]] || fail "at least one Qoder model required."
        [[ "${#qoder_models[@]}" -le 2 ]] || fail "at most two Qoder models allowed."
      fi
    fi
  fi

  echo
  run_checks_bool="$(prompt_yes_no "Run validation after apply?" "yes")"
  [[ "$run_checks_bool" == "true" ]] && run_checks=true || run_checks=false

  commit_push_bool="$(prompt_yes_no "Commit and push after validation?" "no")"
  [[ "$commit_push_bool" == "true" ]] && commit_push=true || commit_push=false

  echo
  apply_bool="$(prompt_yes_no "Apply changes to target?" "no")"
  [[ "$apply_bool" == "true" ]] && apply=true || apply=false
}

# --- Main Entry Point ---

main() {
  if [[ "$#" -eq 0 ]]; then
    interactive=true
  fi

  parse_cli_flags "$@"

  if [[ -n "$config_file" ]]; then
    parse_config_file "$config_file"
  fi

  merge_config

  if [[ "$interactive" == true ]]; then
    interactive_menu
  fi

  validate_inputs

  init_plan_workspace

  if [[ "$uninstall" == true ]]; then
    run_uninstall
    return 0
  fi

  build_plan

  [[ "$apply" == true ]] || return 0

  echo
  echo "Applying install plan..."

  apply_bootstrap_modules
  apply_ai_pr_review
  write_manifest
  run_validation || true
  commit_and_push

  echo
  echo "Install complete."
}

main "$@"
