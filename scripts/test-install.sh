#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "expected file missing: $1"
}

assert_dir() {
  [[ -d "$1" ]] || fail "expected directory missing: $1"
}

assert_not_exists() {
  [[ ! -e "$1" ]] || fail "unexpected path exists: $1"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  grep -qE "$pattern" "$file" || fail "expected pattern '$pattern' in $file"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if grep -qE "$pattern" "$file"; then
    fail "unexpected pattern '$pattern' in $file"
  fi
}

assert_exit_code() {
  local expected="$1"
  shift
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  [[ "$actual" -eq "$expected" ]] || fail "expected exit code $expected, got $actual for: $*"
}

make_qodercli_mock() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/qodercli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --list-models)
    printf 'MODEL\nGLM-5.2\nQwen3.7-Max\nKimi-K2\nAuto\n'
    ;;
  *)
    echo "unexpected qodercli call: $*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$dir/qodercli"
}

make_target_repo() {
  local target="$1"
  mkdir -p "$target"
  git -C "$target" init -q
  git -C "$target" config user.email "test@test.local"
  git -C "$target" config user.name "test"
  echo "# Target Repo" > "$target/README.md"
  git -C "$target" add -A
  git -C "$target" commit -q -m "init"
}

run_install() {
  local output
  output="$("$ROOT_DIR/install" "$@" 2>&1)" || true
  echo "$output"
}

echo "Install tests using $TMP_ROOT"

# Test 1: --help exits 0 and mentions dry-run, modules, AI flags, and uninstall
echo "Test 1: --help"
help_output="$("$ROOT_DIR/install" --help 2>&1)"
assert_exit_code 0 "$ROOT_DIR/install" --help
echo "$help_output" | grep -q "dry-run" || fail "help missing dry-run mention"
echo "$help_output" | grep -q "modules" || fail "help missing modules mention"
echo "$help_output" | grep -q "ai-engine" || fail "help missing AI flags mention"
echo "$help_output" | grep -q "uninstall" || fail "help missing uninstall mention"
echo "  PASS"

# Test 2: Unknown CLI flag fails
echo "Test 2: unknown flag"
output="$(run_install --bogus-flag)"
echo "$output" | grep -q "unknown argument" || fail "expected unknown argument error"
echo "  PASS"

# Test 3: Unknown config key fails
echo "Test 3: unknown config key"
cat > "$TMP_ROOT/bad-config.env" <<'EOF'
BOGUS_KEY=value
EOF
output="$(run_install --config "$TMP_ROOT/bad-config.env" --repo "$TMP_ROOT" --project-type node --modules governance)"
echo "$output" | grep -q "unknown config key" || fail "expected unknown config key error"
echo "  PASS"

# Test 4: Dry-run writes no target files
echo "Test 4: dry-run writes nothing"
target4="$TMP_ROOT/target-dryrun"
make_target_repo "$target4"
run_install --repo "$target4" --project-type docs-only --modules governance > /dev/null
assert_not_exists "$target4/Makefile"
assert_not_exists "$target4/.dogsquard"
assert_not_exists "$target4/scripts/doc-check-local.sh"
echo "  PASS"

# Test 4b: Interactive menu expands ~/ target paths
echo "Test 4b: interactive menu expands tilde target path"
home4b="$TMP_ROOT/home4b"
target4b="$home4b/dev/eden"
mkdir -p "$home4b/dev"
make_target_repo "$target4b"
output="$(
  printf '%s\n' '~/dev/eden' 'docs-only' '1' 'no' 'no' 'no' |
    HOME="$home4b" "$ROOT_DIR/install" --menu 2>&1
)"
echo "$output" | grep -q "Target:   $target4b" || fail "interactive tilde path was not expanded"
assert_not_exists "$target4b/.dogsquard"
echo "  PASS"

# Test 5: docs-only bootstrap apply creates expected files + manifest
echo "Test 5: docs-only apply"
target5="$TMP_ROOT/target-docs"
make_target_repo "$target5"
run_install --repo "$target5" --project-type docs-only --modules governance,pr-quality --apply > /dev/null
assert_file "$target5/Makefile"
assert_file "$target5/.github/workflows/pr-quality.yml"
assert_file "$target5/scripts/doc-check-local.sh"
assert_file "$target5/scripts/doc-guard.sh"
assert_file "$target5/scripts/fake-implementation-guard.sh"
assert_dir "$target5/docs/00_inbox"
assert_dir "$target5/docs/07_runbooks"
assert_file "$target5/.dogsquard/install-manifest.json"
assert_contains "$target5/.dogsquard/install-manifest.json" '"schema_version": "1"'
assert_contains "$target5/.dogsquard/install-manifest.json" '"project_type": "docs-only"'
echo "  PASS"

# Test 6: node dry-run shows bootstrap invocation
echo "Test 6: node dry-run"
target6="$TMP_ROOT/target-node"
make_target_repo "$target6"
output="$(run_install --repo "$target6" --project-type node --modules governance,pr-quality)"
echo "$output" | grep -q "PROJECT_TYPE=node" || fail "node dry-run missing PROJECT_TYPE"
echo "$output" | grep -q "Bootstrap Invocation" || fail "node dry-run missing bootstrap invocation"
echo "  PASS"

# Test 7: go-js dry-run shows bootstrap invocation
echo "Test 7: go-js dry-run"
target7="$TMP_ROOT/target-gojs"
make_target_repo "$target7"
output="$(run_install --repo "$target7" --project-type go-js --modules governance,pr-quality)"
echo "$output" | grep -q "PROJECT_TYPE=go-js" || fail "go-js dry-run missing PROJECT_TYPE"
echo "$output" | grep -q "Bootstrap Invocation" || fail "go-js dry-run missing bootstrap invocation"
echo "  PASS"

# Test 8: Existing file skipped without --force, recorded as skipped
echo "Test 8: existing file skip"
target8="$TMP_ROOT/target-skip"
make_target_repo "$target8"
mkdir -p "$target8/scripts"
echo "# custom" > "$target8/scripts/doc-check-local.sh"
original_sha="$(sha256sum "$target8/scripts/doc-check-local.sh" | awk '{print $1}')"
run_install --repo "$target8" --project-type docs-only --modules governance,pr-quality --apply > /dev/null
current_sha="$(sha256sum "$target8/scripts/doc-check-local.sh" | awk '{print $1}')"
[[ "$original_sha" == "$current_sha" ]] || fail "existing file was overwritten"
echo "  PASS"

# Test 9: Existing file with --force is backed up and recorded as overwritten
echo "Test 9: force overwrite with backup"
target9="$TMP_ROOT/target-force"
make_target_repo "$target9"
mkdir -p "$target9/scripts"
echo "# custom configure" > "$target9/scripts/configure-ai-ci.sh"
original_sha="$(sha256sum "$target9/scripts/configure-ai-ci.sh" | awk '{print $1}')"
run_install --repo "$target9" --project-type docs-only --modules ai-pr-review --apply --force > /dev/null
current_sha="$(sha256sum "$target9/scripts/configure-ai-ci.sh" | awk '{print $1}')"
[[ "$original_sha" != "$current_sha" ]] || fail "AI file was not overwritten with --force"
assert_dir "$target9/.dogsquard/backups"
backup_found=false
while IFS= read -r -d '' backup; do
  if [[ "$(basename "$backup")" == "configure-ai-ci.sh" ]]; then
    backup_found=true
    break
  fi
done < <(find "$target9/.dogsquard/backups" -type f -print0 2>/dev/null)
[[ "$backup_found" == true ]] || fail "backup of configure-ai-ci.sh not found in .dogsquard/backups"
echo "  PASS"

# Test 10: Uninstall dry-run prints all created files
echo "Test 10: uninstall dry-run"
target10="$TMP_ROOT/target-uninstall-dry"
make_target_repo "$target10"
run_install --repo "$target10" --project-type docs-only --modules governance,pr-quality --apply > /dev/null
output="$(run_install --uninstall --repo "$target10")"
echo "$output" | grep -q "Uninstall Plan" || fail "uninstall dry-run missing plan header"
echo "$output" | grep -q "REMOVE" || fail "uninstall dry-run missing REMOVE entries"
echo "  PASS"

# Test 11: Uninstall apply removes created files, preserves skipped pre-existing
echo "Test 11: uninstall apply"
target11="$TMP_ROOT/target-uninstall-apply"
make_target_repo "$target11"
echo "# pre-existing README" > "$target11/README.md"
git -C "$target11" add -A && git -C "$target11" commit -q -m "pre-existing"
run_install --repo "$target11" --project-type docs-only --modules governance,pr-quality --apply > /dev/null
assert_file "$target11/Makefile"
assert_file "$target11/scripts/doc-check-local.sh"
run_install --uninstall --repo "$target11" --apply > /dev/null
assert_not_exists "$target11/Makefile"
assert_not_exists "$target11/scripts/doc-check-local.sh"
assert_file "$target11/README.md"
assert_contains "$target11/README.md" "pre-existing"
echo "  PASS"

# Test 12: Uninstall refuses when manifest is missing
echo "Test 12: uninstall without manifest"
target12="$TMP_ROOT/target-no-manifest"
make_target_repo "$target12"
output="$(run_install --uninstall --repo "$target12")"
echo "$output" | grep -q "no Dogsquard install manifest" || fail "expected manifest missing error"
echo "  PASS"

# Test 13: ai-pr-review copies one unified workflow
echo "Test 13: ai-pr-review install"
mockbin="$TMP_ROOT/mockbin"
make_qodercli_mock "$mockbin"
target13="$TMP_ROOT/target-ai"
make_target_repo "$target13"
PATH="$mockbin:$PATH" run_install --repo "$target13" --project-type docs-only --modules ai-pr-review --apply > /dev/null
assert_file "$target13/.github/workflows/ai-pr-review.yml"
assert_file "$target13/.github/workflows/scripts/ai_review_pr.py"
assert_file "$target13/scripts/configure-ai-ci.sh"
assert_file "$target13/scripts/upsert-pr-comment.sh"
assert_file "$target13/.github/claude/deepseek-settings.json"
assert_file "$target13/.github/qoder/settings.json"
assert_not_exists "$target13/.github/workflows/ai-fix-bug.yml"
echo "  PASS"

# Test 14: ai-pr-review no-input creates disabled safe config
echo "Test 14: ai-pr-review disabled safe config"
target14="$TMP_ROOT/target-ai-disabled"
make_target_repo "$target14"
run_install --repo "$target14" --project-type docs-only --modules ai-pr-review --apply > /dev/null
assert_file "$target14/.github/ai-review/settings.json"
assert_contains "$target14/.github/ai-review/settings.json" '"enabled": false'
echo "  PASS"

# Test 15: Existing target settings preserved without --force
echo "Test 15: existing settings preserved"
target15="$TMP_ROOT/target-ai-preserve"
make_target_repo "$target15"
mkdir -p "$target15/.github/ai-review"
echo '{"enabled": true, "engine": "qoder", "claude": {"provider": "deepseek"}, "qoder": {"models": ["GLM-5.2"], "implicit_auto_fallback": true}}' > "$target15/.github/ai-review/settings.json"
run_install --repo "$target15" --project-type docs-only --modules ai-pr-review --apply > /dev/null
assert_contains "$target15/.github/ai-review/settings.json" '"enabled": true'
assert_contains "$target15/.github/ai-review/settings.json" '"GLM-5.2"'
echo "  PASS"

# Test 16: AI configure pass-through invokes configure helper
echo "Test 16: AI configure pass-through"
target16="$TMP_ROOT/target-ai-passthrough"
make_target_repo "$target16"
output="$(PATH="$mockbin:$PATH" run_install --repo "$target16" --project-type docs-only --modules ai-pr-review --ai-enabled true --ai-engine qoder --qoder-model Qwen3.7-Max --qoder-model GLM-5.2 --apply)"
assert_file "$target16/.github/ai-review/settings.json"
assert_contains "$target16/.github/ai-review/settings.json" '"enabled": true'
assert_contains "$target16/.github/ai-review/settings.json" '"engine": "qoder"'
echo "  PASS"

# Test 16b: Interactive AI configure accepts Qoder model numbers
echo "Test 16b: interactive Qoder model number selection"
target16b="$TMP_ROOT/target-ai-interactive-model"
make_target_repo "$target16b"
output="$(
  printf '%s\n' "$target16b" 'docs-only' '6' 'yes' 'true' 'qoder' '2' 'done' 'no' 'no' 'yes' |
    PATH="$mockbin:$PATH" "$ROOT_DIR/install" --menu 2>&1
)"
assert_file "$target16b/.github/ai-review/settings.json"
assert_contains "$target16b/.github/ai-review/settings.json" '"Qwen3.7-Max"'
assert_not_contains "$target16b/.github/ai-review/settings.json" '"2"'
echo "  PASS"

# Test 17: Qoder config rejects zero models, >2, duplicates, Auto
echo "Test 17: Qoder model validation"
output="$(run_install --repo "$TMP_ROOT" --project-type docs-only --modules ai-pr-review --ai-engine qoder)"
echo "$output" | grep -q "at least one" || fail "expected zero-model rejection"

output="$(run_install --repo "$TMP_ROOT" --project-type docs-only --modules ai-pr-review --ai-engine qoder --qoder-model A --qoder-model B --qoder-model C)"
echo "$output" | grep -q "at most two" || fail "expected >2 model rejection"

output="$(run_install --repo "$TMP_ROOT" --project-type docs-only --modules ai-pr-review --ai-engine qoder --qoder-model X --qoder-model X)"
echo "$output" | grep -q "unique" || fail "expected duplicate model rejection"

output="$(run_install --repo "$TMP_ROOT" --project-type docs-only --modules ai-pr-review --ai-engine qoder --qoder-model Auto)"
echo "$output" | grep -q "Auto" || fail "expected Auto rejection"
echo "  PASS"

# Test 18: --ai-apply-github-vars without --apply fails
echo "Test 18: --ai-apply-github-vars without --apply"
output="$(run_install --repo "$TMP_ROOT" --project-type docs-only --modules ai-pr-review --ai-apply-github-vars)"
echo "$output" | grep -q "requires --apply" || fail "expected --ai-apply-github-vars requires --apply error"
echo "  PASS"

# Test 19: Secret-looking values in config are rejected
echo "Test 19: secret value rejection"
cat > "$TMP_ROOT/secret-config.env" <<'EOF'
TARGET_DIR=/tmp/test
PROJECT_TYPE=node
MODULES=governance
AI_REVIEW_ENGINE=ghp_s3cr3t_t0k3n_value
EOF
output="$(run_install --config "$TMP_ROOT/secret-config.env")"
echo "$output" | grep -q "secret" || fail "expected secret value rejection"
echo "  PASS"

# Test 20: --commit-push on main fails in non-interactive mode
echo "Test 20: commit-push on main fails"
target20="$TMP_ROOT/target-main-branch"
make_target_repo "$target20"
output="$(run_install --repo "$target20" --project-type docs-only --modules governance --apply --commit-push 2>&1)" || true
echo "$output" | grep -qi "main\|feature branch" || fail "expected main branch rejection for commit-push"
echo "  PASS"

echo
echo "Install tests passed."
