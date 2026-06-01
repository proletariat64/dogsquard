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

assert_readme_preserved() {
  local target="$1"
  grep -q "Existing Project README" "$target/README.md" || fail "README was overwritten in $target"
}

echo "Bootstrap project tests using $TMP_ROOT"

docs_target="$TMP_ROOT/docs-only"
mkdir -p "$docs_target"
printf '# Existing Project README\n' > "$docs_target/README.md"

PROJECT_TYPE=docs-only TARGET_DIR="$docs_target" "$ROOT_DIR/scripts/bootstrap-project.sh"
assert_not_exists "$docs_target/Makefile"
assert_readme_preserved "$docs_target"

PROJECT_TYPE=docs-only TARGET_DIR="$docs_target" DRY_RUN=false "$ROOT_DIR/scripts/bootstrap-project.sh"
assert_file "$docs_target/Makefile"
assert_file "$docs_target/.github/workflows/pr-quality.yml"
assert_file "$docs_target/docs/00_inbox/.gitkeep"
assert_file "$docs_target/docs/01_brd/brd-20260530-project-operating-model.md"
assert_file "$docs_target/scripts/doc-check-local.sh"
assert_contains "$docs_target/.github/workflows/pr-quality.yml" "Docs Quality"
assert_contains "$docs_target/.gitignore" "^AGENTS.md$"
assert_contains "$docs_target/.gitignore" "^CLAUDE.md$"
assert_contains "$docs_target/.gitignore" "^roster.md$"
assert_not_exists "$docs_target/.github/workflows/deploy-dev.yml"
assert_readme_preserved "$docs_target"
(cd "$docs_target" && make doc-check >/dev/null)

node_target="$TMP_ROOT/node"
mkdir -p "$node_target/source" "$node_target/tests"
printf '# Existing Project README\n' > "$node_target/README.md"
cat > "$node_target/package.json" <<'JSON'
{
  "name": "node-target",
  "scripts": {
    "test": "node --test",
    "build": "node -e \"console.log('build ok')\""
  },
  "dependencies": {
    "sql.js": "^1.0.0"
  }
}
JSON
cat > "$node_target/.gitignore" <<'GITIGNORE'
data/*.db
node_modules/
GITIGNORE

PROJECT_TYPE=node TARGET_DIR="$node_target" DRY_RUN=false "$ROOT_DIR/scripts/bootstrap-project.sh"
assert_file "$node_target/Makefile"
assert_file "$node_target/.github/workflows/pr-quality.yml"
assert_file "$node_target/.github/workflows/deploy-dev.yml"
assert_file "$node_target/scripts/deploy-dev.sh"
assert_file "$node_target/docs/07_runbooks/runbook-dev-high-port-access.md"
assert_file "$node_target/.env.dogsquard-dev.example"
assert_file "$node_target/docs/02_prd/prd-20260530-document-governance.md"
assert_file "$node_target/data/.gitkeep"
assert_dir "$node_target/source"
assert_dir "$node_target/tests"
assert_not_exists "$node_target/backend"
assert_not_exists "$node_target/frontend"
assert_contains "$node_target/Makefile" "npm test"
assert_contains "$node_target/Makefile" "has-npm-script"
assert_contains "$node_target/.github/workflows/pr-quality.yml" "Node Quality"
assert_contains "$node_target/.gitignore" "^AGENTS.md$"
assert_contains "$node_target/.gitignore" "^CLAUDE.md$"
assert_contains "$node_target/.gitignore" "^roster.md$"
assert_contains "$node_target/.env.dogsquard-dev.example" "DEV_FRONTEND_PUBLIC_PORT=8173"
assert_contains "$node_target/.env.dogsquard-dev.example" "DEV_BACKEND_PUBLIC_PORT=8180"
assert_contains "$node_target/docs/07_runbooks/runbook-dev-high-port-access.md" "8000-8999"
assert_readme_preserved "$node_target"
(cd "$node_target" && make doc-check >/dev/null)
(cd "$node_target" && make lint > lint.out 2>&1)
assert_not_contains "$node_target/lint.out" "npm error"

node_no_deploy_target="$TMP_ROOT/node-no-deploy"
mkdir -p "$node_no_deploy_target"
printf '# Existing Project README\n' > "$node_no_deploy_target/README.md"
cat > "$node_no_deploy_target/package.json" <<'JSON'
{
  "name": "node-no-deploy-target",
  "scripts": {
    "test": "node --test"
  }
}
JSON
PROJECT_TYPE=node TARGET_DIR="$node_no_deploy_target" DRY_RUN=false INCLUDE_DEV_DEPLOY=false "$ROOT_DIR/scripts/bootstrap-project.sh"
assert_file "$node_no_deploy_target/Makefile"
assert_not_exists "$node_no_deploy_target/.github/workflows/deploy-dev.yml"
assert_not_exists "$node_no_deploy_target/.env.dogsquard-dev.example"

go_js_target="$TMP_ROOT/go-js"
mkdir -p "$go_js_target/backend" "$go_js_target/frontend"
printf '# Existing Project README\n' > "$go_js_target/README.md"
cat > "$go_js_target/backend/go.mod" <<'GOMOD'
module example.com/go-js-target

go 1.22
GOMOD
cat > "$go_js_target/frontend/package.json" <<'JSON'
{
  "name": "go-js-target-frontend",
  "scripts": {
    "build": "vite build"
  }
}
JSON

PROJECT_TYPE=go-js TARGET_DIR="$go_js_target" DRY_RUN=false "$ROOT_DIR/scripts/bootstrap-project.sh"
assert_file "$go_js_target/Makefile"
assert_file "$go_js_target/.github/workflows/pr-quality.yml"
assert_file "$go_js_target/.github/workflows/deploy-dev.yml"
assert_file "$go_js_target/docs/07_runbooks/runbook-dev-high-port-access.md"
assert_contains "$go_js_target/Makefile" "backend-test"
assert_contains "$go_js_target/.github/workflows/pr-quality.yml" "Go/JS Quality"
assert_readme_preserved "$go_js_target"

example_target="$TMP_ROOT/example"
mkdir -p "$example_target"
PROJECT_TYPE=go-js TARGET_DIR="$example_target" DRY_RUN=false INCLUDE_EXAMPLE_APP=true "$ROOT_DIR/scripts/bootstrap-project.sh"
assert_dir "$example_target/backend"
assert_dir "$example_target/frontend"
assert_not_exists "$example_target/frontend/node_modules"
assert_not_exists "$example_target/frontend/dist"

deploy_target="$TMP_ROOT/deploy"
mkdir -p "$deploy_target"
PROJECT_TYPE=docs-only TARGET_DIR="$deploy_target" DRY_RUN=false INCLUDE_DEV_DEPLOY=true "$ROOT_DIR/scripts/bootstrap-project.sh"
assert_file "$deploy_target/.github/workflows/deploy-dev.yml"
assert_file "$deploy_target/scripts/deploy-dev.sh"

echo "Bootstrap project tests passed."
