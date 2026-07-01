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

assert_json_models() {
  local output_file="$1"
  shift
  python3 - "$output_file" "$@" <<'PY'
import json
import sys

path = sys.argv[1]
expected = sys.argv[2:]
text = open(path, encoding="utf-8").read()
marker = "Generated .github/ai-review/settings.json:\n"
start = text.index(marker) + len(marker)
end = text.index("\n\nRequired secret:", start)
data = json.loads(text[start:end])
actual = data["qoder"]["models"]
if actual != expected:
    raise SystemExit(f"expected models {expected!r}, got {actual!r}")
if data["qoder"]["implicit_auto_fallback"] is not True:
    raise SystemExit("implicit_auto_fallback must stay true")
PY
}

make_qodercli_mock() {
  local dir="$1"
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

run_configure_interactive() {
  local case_dir="$1"
  local input="$2"

  mkdir -p "$case_dir/mockbin"
  make_qodercli_mock "$case_dir/mockbin"
  copy_configure_fixture "$case_dir/work"
  (
    cd "$case_dir/work"
    PATH="$case_dir/mockbin:$PATH" \
      bash "$case_dir/work/scripts/configure-ai-ci.sh" \
      > "$case_dir/stdout.txt" \
      2> "$case_dir/stderr.txt" <<<"$input"
  )
}

copy_configure_fixture() {
  local fixture_dir="$1"

  mkdir -p "$fixture_dir/scripts" "$fixture_dir/.github/ai-review"
  cp "$ROOT_DIR/scripts/configure-ai-ci.sh" "$fixture_dir/scripts/configure-ai-ci.sh"
  chmod +x "$fixture_dir/scripts/configure-ai-ci.sh"
  cat > "$fixture_dir/.github/ai-review/settings.json" <<'JSON'
{
  "enabled": true,
  "engine": "qoder",
  "claude": {
    "provider": "deepseek"
  },
  "qoder": {
    "models": [
      "GLM-5.2",
      "Qwen3.7-Max"
    ],
    "implicit_auto_fallback": true
  }
}
JSON
}

make_activation_mocks() {
  local dir="$1"

  cat > "$dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  auth)
    [[ "${2:-}" == "status" ]] || exit 1
    ;;
  secret)
    case "${2:-}" in
      list)
        printf 'QODER_PERSONAL_ACCESS_TOKEN\t2026-07-01T00:00:00Z\n'
        ;;
      set)
        printf 'gh secret set args:'
        shift 2
        for arg in "$@"; do
          printf ' <%s>' "$arg"
        done
        printf '\n'
        ;;
      *)
        echo "unexpected gh secret call: $*" >&2
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

case "${1:-} ${2:-}" in
  "remote get-url")
    printf 'git@example.test:owner/repo.git\n'
    ;;
  *)
    echo "unexpected git call: $*" >&2
    exit 1
    ;;
esac
EOF

  chmod +x "$dir/gh" "$dir/git"
}

run_activation_case() {
  local case_dir="$1"

  mkdir -p "$case_dir/mockbin"
  make_qodercli_mock "$case_dir/mockbin"
  make_activation_mocks "$case_dir/mockbin"
  copy_configure_fixture "$case_dir/work"
  (
    cd "$case_dir/work"
    PATH="$case_dir/mockbin:$PATH" \
      bash "$case_dir/work/scripts/configure-ai-ci.sh" \
      > "$case_dir/stdout.txt" \
      2> "$case_dir/stderr.txt" <<'EOF'


done
yes
no
yes
no
EOF
  )
}

echo "Configure AI CI shell tests using $TMP_ROOT"

max_two_case="$TMP_ROOT/max-two"
run_configure_interactive "$max_two_case" $'\n\n3\ndone\nno\n'
assert_contains "$max_two_case/stderr.txt" "No Qoder model slots left. Uncheck one model before selecting another."
assert_contains "$max_two_case/stdout.txt" "Final runtime sequence: GLM-5.2,Qwen3.7-Max,auto"
assert_contains "$max_two_case/stdout.txt" "Runtime fallback sequence: GLM-5.2 Qwen3.7-Max Auto"
assert_json_models "$max_two_case/stdout.txt" "GLM-5.2" "Qwen3.7-Max"

toggle_case="$TMP_ROOT/toggle-order"
run_configure_interactive "$toggle_case" $'\n\n1\n3\n2\n2\ndone\nno\n'
assert_contains "$toggle_case/stdout.txt" "Final runtime sequence: Qwen3.7-Max,Kimi-K2,auto"
assert_contains "$toggle_case/stdout.txt" "Runtime fallback sequence: Qwen3.7-Max Kimi-K2 Auto"
assert_json_models "$toggle_case/stdout.txt" "Qwen3.7-Max" "Kimi-K2"

secret_case="$TMP_ROOT/secret"
run_activation_case "$secret_case"
assert_contains "$secret_case/stdout.txt" "QODER_PERSONAL_ACCESS_TOKEN status: exists"
assert_contains "$secret_case/stdout.txt" "gh secret set args: <QODER_PERSONAL_ACCESS_TOKEN>"
assert_contains "$secret_case/stdout.txt" "Updated GitHub secret: QODER_PERSONAL_ACCESS_TOKEN"
assert_not_contains "$secret_case/stdout.txt" "--body"
assert_not_contains "$secret_case/stdout.txt" "SECRET_VALUE"
assert_not_contains "$secret_case/stderr.txt" "SECRET_VALUE"

echo "Configure AI CI shell tests passed."
