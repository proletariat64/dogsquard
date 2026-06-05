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

assert_equals() {
  local expected="$1"
  local actual="$2"
  [[ "$expected" == "$actual" ]] || fail "expected '$expected', got '$actual'"
}

make_mock_bin() {
  local dir="$1"

  cat > "$dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${MOCK_DIR:?}/gh.log"
printf 'gh %s\n' "$*" >> "$log_file"

case "${1:-}" in
  api)
    case "${2:-}" in
      repos/*/issues/*/comments\?per_page=100)
        cat "${MOCK_DIR}/comments.json"
        ;;
      repos/*/issues/*)
        cat "${MOCK_DIR}/issue.json"
        ;;
      repos/*/labels/*)
        printf '{}\n'
        ;;
      *)
        echo "unexpected gh api call: $*" >&2
        exit 1
        ;;
    esac
    ;;
  repo)
    cat "${MOCK_DIR}/repo.json"
    ;;
  pr)
    printf '[]\n'
    ;;
  issue)
    case "${2:-}" in
      comment)
        printf 'issue comment %s\n' "$*" >> "${MOCK_DIR}/issue-actions.log"
        ;;
      edit)
        printf 'issue edit %s\n' "$*" >> "${MOCK_DIR}/issue-actions.log"
        ;;
      *)
        echo "unexpected gh issue call: $*" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "unexpected gh call: $*" >&2
    exit 1
    ;;
esac
EOF

  cat > "$dir/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'git %s\n' "$*" >> "${MOCK_DIR:?}/git.log"

case "${1:-}" in
  fetch|checkout)
    exit 0
    ;;
  branch)
    if [[ "${2:-}" == "--show-current" ]]; then
      printf 'ai-fix/test-branch\n'
      exit 0
    fi
    ;;
esac

exit 0
EOF

  chmod +x "$dir/gh" "$dir/git"
}

run_prepare_case() {
  local case_dir="$1"
  local issue_json="$2"
  local comment_body="$3"

  mkdir -p "$case_dir/mockbin" "$case_dir/work"
  printf '%s\n' "$issue_json" > "$case_dir/issue.json"
  printf '[]\n' > "$case_dir/comments.json"
  printf '{"defaultBranchRef":{"name":"main"}}\n' > "$case_dir/repo.json"
  : > "$case_dir/gh.log"
  : > "$case_dir/git.log"
  : > "$case_dir/issue-actions.log"
  make_mock_bin "$case_dir/mockbin"

  (
    cd "$case_dir/work"
    PATH="$case_dir/mockbin:$PATH" \
    MOCK_DIR="$case_dir" \
    GITHUB_REPOSITORY="proletariat64/dogsquard" \
    GITHUB_EVENT_NAME="workflow_dispatch" \
    ISSUE_NUMBER_INPUT="123" \
    COMMENT_BODY_INPUT="$comment_body" \
    COMMENT_AUTHOR_ASSOCIATION_INPUT="OWNER" \
    GITHUB_OUTPUT="$case_dir/output.txt" \
    bash "$ROOT_DIR/scripts/ai-fix-bug.sh" prepare
  )
}

echo "AI fix bug workflow tests using $TMP_ROOT"

missing_bug_case="$TMP_ROOT/missing-bug"
run_prepare_case \
  "$missing_bug_case" \
  '{"state":"open","title":"Missing bug label","html_url":"https://example.test/issues/123","labels":[{"name":"ai-fix-candidate"}]}' \
  '/ai-fix-bug approved'
assert_contains "$missing_bug_case/output.txt" '^allowed=false$'
assert_contains "$missing_bug_case/work/.tmp/ai-fix/issue-comment.md" 'missing the required `bug` label'
assert_contains "$missing_bug_case/issue-actions.log" 'issue comment'
assert_not_contains "$missing_bug_case/git.log" 'git fetch'

missing_trigger_case="$TMP_ROOT/missing-trigger"
run_prepare_case \
  "$missing_trigger_case" \
  '{"state":"open","title":"Missing trigger","html_url":"https://example.test/issues/123","labels":[{"name":"bug"},{"name":"ai-fix-candidate"}]}' \
  'please help'
assert_contains "$missing_trigger_case/output.txt" '^allowed=false$'
assert_contains "$missing_trigger_case/work/.tmp/ai-fix/issue-comment.md" '/ai-fix-bug approved'
assert_contains "$missing_trigger_case/issue-actions.log" 'issue comment'
assert_not_contains "$missing_trigger_case/git.log" 'git checkout'

allowed_case="$TMP_ROOT/allowed"
run_prepare_case \
  "$allowed_case" \
  '{"state":"open","title":"Visible bug fix request","html_url":"https://example.test/issues/123","labels":[{"name":"bug"},{"name":"ai-fix-candidate"}]}' \
  '/ai-fix-bug approved'
assert_contains "$allowed_case/output.txt" '^allowed=true$'
assert_contains "$allowed_case/output.txt" '^branch_name=ai-fix/issue-123-visible-bug-fix-request$'
assert_contains "$allowed_case/git.log" 'git fetch'
assert_contains "$allowed_case/git.log" 'git checkout -B ai-fix/issue-123-visible-bug-fix-request origin/main'
assert_contains "$allowed_case/issue-actions.log" 'issue edit 123 --add-label ai-fix-running'
assert_contains "$allowed_case/work/.tmp/ai-fix/prompt.md" 'npx gitnexus impact --repo dogsquard <symbolName> --direction upstream'
assert_contains "$allowed_case/work/.tmp/ai-fix/prompt.md" '### GitNexus Impact'

echo "AI fix bug workflow tests passed."
