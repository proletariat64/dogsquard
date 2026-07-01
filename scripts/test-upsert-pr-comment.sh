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
  grep -qF -- "$pattern" "$file" || fail "expected '$pattern' in $file"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if grep -qF -- "$pattern" "$file"; then
    fail "unexpected '$pattern' in $file"
  fi
}

make_curl_mock() {
  local dir="$1"

  cat > "$dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

method="GET"
url=""
data_file=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -X)
      method="$2"
      shift 2
      ;;
    --data-binary)
      data_file="${2#@}"
      shift 2
      ;;
    http*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

printf '%s %s\n' "$method" "$url" >> "${MOCK_DIR:?}/curl.log"
if [[ -n "$data_file" ]]; then
  python3 - "$data_file" >> "${MOCK_DIR}/bodies.log" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
print(data["body"])
PY
fi

case "$url" in
  *"/issues/"*"/comments?per_page=100")
    cat "${MOCK_DIR}/comments.json"
    ;;
  *"/issues/comments/"*)
    printf '{}\n'
    ;;
  *"/issues/"*"/comments")
    printf '{}\n'
    ;;
  *)
    echo "unexpected curl URL: $url" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$dir/curl"
}

run_upsert_case() {
  local case_dir="$1"
  local comments_json="$2"

  mkdir -p "$case_dir/mockbin"
  printf '%s\n' "$comments_json" > "$case_dir/comments.json"
  printf 'new body\n<!-- dogsquard-ai-code-review -->\n' > "$case_dir/body.md"
  : > "$case_dir/curl.log"
  : > "$case_dir/bodies.log"
  make_curl_mock "$case_dir/mockbin"

  (
    cd "$ROOT_DIR"
    PATH="$case_dir/mockbin:$PATH" \
      MOCK_DIR="$case_dir" \
      GITHUB_REPOSITORY="proletariat64/dogsquard" \
      PR_NUMBER="42" \
      GITHUB_TOKEN="SECRET_VALUE" \
      bash "$ROOT_DIR/scripts/upsert-pr-comment.sh" \
        "<!-- dogsquard-ai-code-review -->" \
        "$case_dir/body.md" \
        > "$case_dir/stdout.txt" \
        2> "$case_dir/stderr.txt"
  )
}

echo "Upsert PR comment shell tests using $TMP_ROOT"

update_case="$TMP_ROOT/update"
run_upsert_case "$update_case" '[{"id": 101, "body": "old\n<!-- dogsquard-ai-code-review -->"}]'
assert_contains "$update_case/stdout.txt" "Updated PR comment 101."
assert_contains "$update_case/curl.log" "GET https://api.github.com/repos/proletariat64/dogsquard/issues/42/comments?per_page=100"
assert_contains "$update_case/curl.log" "PATCH https://api.github.com/repos/proletariat64/dogsquard/issues/comments/101"
assert_not_contains "$update_case/curl.log" "POST https://api.github.com/repos/proletariat64/dogsquard/issues/42/comments"
assert_contains "$update_case/bodies.log" "<!-- dogsquard-ai-code-review -->"
assert_not_contains "$update_case/stdout.txt" "SECRET_VALUE"
assert_not_contains "$update_case/stderr.txt" "SECRET_VALUE"
assert_not_contains "$update_case/curl.log" "SECRET_VALUE"

create_case="$TMP_ROOT/create"
run_upsert_case "$create_case" '[{"id": 202, "body": "unrelated"}]'
assert_contains "$create_case/stdout.txt" "Created PR comment."
assert_contains "$create_case/curl.log" "GET https://api.github.com/repos/proletariat64/dogsquard/issues/42/comments?per_page=100"
assert_contains "$create_case/curl.log" "POST https://api.github.com/repos/proletariat64/dogsquard/issues/42/comments"
assert_not_contains "$create_case/curl.log" "PATCH https://api.github.com/repos/proletariat64/dogsquard/issues/comments/202"
assert_contains "$create_case/bodies.log" "<!-- dogsquard-ai-code-review -->"
assert_not_contains "$create_case/stdout.txt" "SECRET_VALUE"
assert_not_contains "$create_case/stderr.txt" "SECRET_VALUE"
assert_not_contains "$create_case/curl.log" "SECRET_VALUE"

echo "Upsert PR comment shell tests passed."
