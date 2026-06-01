#!/usr/bin/env bash
set -euo pipefail

PROJECT_TYPE="${PROJECT_TYPE:-}"
TARGET_DIR="${TARGET_DIR:-${1:-}}"
DRY_RUN="${DRY_RUN:-true}"
FORCE="${FORCE:-false}"
CREATE_TARGET="${CREATE_TARGET:-false}"
INCLUDE_EXAMPLE_APP="${INCLUDE_EXAMPLE_APP:-false}"
INCLUDE_DEV_DEPLOY_INPUT="${INCLUDE_DEV_DEPLOY:-}"
INCLUDE_PRODUCTION_PROFILE="${INCLUDE_PRODUCTION_PROFILE:-false}"

usage() {
  cat <<'USAGE'
Usage:
  PROJECT_TYPE=node TARGET_DIR=../target scripts/bootstrap-project.sh
  PROJECT_TYPE=go-js TARGET_DIR=../target scripts/bootstrap-project.sh
  PROJECT_TYPE=docs-only TARGET_DIR=../target scripts/bootstrap-project.sh

Defaults:
  DRY_RUN=true
  FORCE=false
  CREATE_TARGET=false
  INCLUDE_EXAMPLE_APP=false
  INCLUDE_DEV_DEPLOY=true for PROJECT_TYPE=node and PROJECT_TYPE=go-js
  INCLUDE_DEV_DEPLOY=false for PROJECT_TYPE=docs-only
  INCLUDE_PRODUCTION_PROFILE=false

Examples:
  PROJECT_TYPE=node TARGET_DIR=../app scripts/bootstrap-project.sh
  PROJECT_TYPE=node TARGET_DIR=../app DRY_RUN=false scripts/bootstrap-project.sh
  PROJECT_TYPE=node TARGET_DIR=../app DRY_RUN=false FORCE=true scripts/bootstrap-project.sh
  PROJECT_TYPE=node TARGET_DIR=../app DRY_RUN=false INCLUDE_DEV_DEPLOY=false scripts/bootstrap-project.sh
  PROJECT_TYPE=node TARGET_DIR=../app DRY_RUN=false INCLUDE_PRODUCTION_PROFILE=true scripts/bootstrap-project.sh
  PROJECT_TYPE=go-js TARGET_DIR=../app DRY_RUN=false INCLUDE_EXAMPLE_APP=true scripts/bootstrap-project.sh
  PROJECT_TYPE=docs-only TARGET_DIR=../app DRY_RUN=false INCLUDE_DEV_DEPLOY=true scripts/bootstrap-project.sh
USAGE
}

fail() {
  echo "FAIL: $*" >&2
  exit 2
}

validate_bool() {
  local name="$1"
  local value="$2"
  case "$value" in
    true|false) ;;
    *) fail "$name must be true or false." ;;
  esac
}

[[ -n "$PROJECT_TYPE" ]] || { usage; fail "PROJECT_TYPE is required."; }
[[ -n "$TARGET_DIR" ]] || { usage; fail "TARGET_DIR is required."; }

case "$PROJECT_TYPE" in
  node|go-js|docs-only) ;;
  *) fail "PROJECT_TYPE must be node, go-js, or docs-only." ;;
esac

if [[ -z "$INCLUDE_DEV_DEPLOY_INPUT" ]]; then
  case "$PROJECT_TYPE" in
    node|go-js) INCLUDE_DEV_DEPLOY="true" ;;
    docs-only) INCLUDE_DEV_DEPLOY="false" ;;
  esac
else
  INCLUDE_DEV_DEPLOY="$INCLUDE_DEV_DEPLOY_INPUT"
fi

validate_bool DRY_RUN "$DRY_RUN"
validate_bool FORCE "$FORCE"
validate_bool CREATE_TARGET "$CREATE_TARGET"
validate_bool INCLUDE_EXAMPLE_APP "$INCLUDE_EXAMPLE_APP"
validate_bool INCLUDE_DEV_DEPLOY "$INCLUDE_DEV_DEPLOY"
validate_bool INCLUDE_PRODUCTION_PROFILE "$INCLUDE_PRODUCTION_PROFILE"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -d "$TARGET_DIR" ]]; then
  if [[ "$CREATE_TARGET" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "PLAN mkdir -p $TARGET_DIR"
    else
      mkdir -p "$TARGET_DIR"
    fi
  else
    fail "TARGET_DIR must exist unless CREATE_TARGET=true: $TARGET_DIR"
  fi
fi

if [[ "$DRY_RUN" == "false" && ! -d "$TARGET_DIR" ]]; then
  fail "TARGET_DIR was not created: $TARGET_DIR"
fi

if [[ -d "$TARGET_DIR" ]]; then
  TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
fi

if [[ "$TARGET_DIR" == "$ROOT_DIR" ]]; then
  fail "TARGET_DIR must not be the Dogsquard repository itself."
fi

echo "Dogsquard profile-aware bootstrap"
echo "PROJECT_TYPE=$PROJECT_TYPE"
echo "TARGET_DIR=$TARGET_DIR"
echo "DRY_RUN=$DRY_RUN"
echo "FORCE=$FORCE"
echo "CREATE_TARGET=$CREATE_TARGET"
echo "INCLUDE_EXAMPLE_APP=$INCLUDE_EXAMPLE_APP"
echo "INCLUDE_DEV_DEPLOY=$INCLUDE_DEV_DEPLOY"
echo "INCLUDE_PRODUCTION_PROFILE=$INCLUDE_PRODUCTION_PROFILE"
echo

plan() {
  echo "PLAN $*"
}

ensure_dir() {
  local dir="$1"
  if [[ "$DRY_RUN" == "true" ]]; then
    plan "mkdir -p $dir"
  else
    mkdir -p "$TARGET_DIR/$dir"
  fi
}

touch_file() {
  local dest="$1"
  if [[ -e "$TARGET_DIR/$dest" && "$FORCE" != "true" ]]; then
    echo "SKIP exists: $dest"
    return
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    plan "touch $dest"
  else
    mkdir -p "$(dirname "$TARGET_DIR/$dest")"
    : > "$TARGET_DIR/$dest"
  fi
}

copy_file() {
  local src="$1"
  local dest="$2"

  [[ -f "$ROOT_DIR/$src" ]] || fail "source file missing: $src"

  if [[ -e "$TARGET_DIR/$dest" && "$FORCE" != "true" ]]; then
    echo "SKIP exists: $dest"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    plan "copy file: $src -> $dest"
  else
    mkdir -p "$(dirname "$TARGET_DIR/$dest")"
    cp "$ROOT_DIR/$src" "$TARGET_DIR/$dest"
  fi
}

copy_dir() {
  local src="$1"
  local dest="$2"

  [[ -d "$ROOT_DIR/$src" ]] || fail "source directory missing: $src"

  if [[ -e "$TARGET_DIR/$dest" && "$FORCE" != "true" ]]; then
    echo "SKIP exists: $dest"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    plan "copy directory: $src -> $dest"
  else
    mkdir -p "$(dirname "$TARGET_DIR/$dest")"
    rm -rf "$TARGET_DIR/$dest"
    mkdir -p "$TARGET_DIR/$dest"
    tar \
      --exclude='.git' \
      --exclude='.claude' \
      --exclude='node_modules' \
      --exclude='dist' \
      --exclude='playwright-report' \
      --exclude='test-results' \
      --exclude='.env.local' \
      --exclude='*.local' \
      -C "$ROOT_DIR/$src" \
      -cf - . | tar -C "$TARGET_DIR/$dest" -xf -
  fi
}

write_file() {
  local dest="$1"
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp"

  if [[ -e "$TARGET_DIR/$dest" && "$FORCE" != "true" ]]; then
    echo "SKIP exists: $dest"
    rm -f "$tmp"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    plan "write file: $dest"
  else
    mkdir -p "$(dirname "$TARGET_DIR/$dest")"
    cp "$tmp" "$TARGET_DIR/$dest"
  fi
  rm -f "$tmp"
}

create_docs_structure() {
  local dirs=(
    docs/00_inbox
    docs/01_brd
    docs/02_prd
    docs/03_bdd
    docs/04_adr
    docs/05_design
    docs/06_testing
    docs/07_runbooks
    docs/08_releases
    docs/90_archive
  )

  local dir
  for dir in "${dirs[@]}"; do
    ensure_dir "$dir"
    touch_file "$dir/.gitkeep"
  done
}

copy_governance_scripts() {
  local files=(
    scripts/agent-doc-review.sh
    scripts/doc-check-local.sh
    scripts/doc-guard.sh
    scripts/lib-doc-rules.sh
  )

  local file
  for file in "${files[@]}"; do
    copy_file "$file" "$file"
  done
}

copy_core_governance_docs() {
  local files=(
    docs/01_brd/brd-20260530-project-operating-model.md
    docs/02_prd/prd-20260530-document-governance.md
    docs/03_bdd/bdd-20260530-document-governance.md
    docs/04_adr/0001-use-github-actions-as-ci-authority.md
    docs/05_design/design-20260530-agent-charter.md
  )

  local file
  for file in "${files[@]}"; do
    copy_file "$file" "$file"
  done
}

copy_github_templates() {
  copy_file .github/pull_request_template.md .github/pull_request_template.md
  copy_file .github/ISSUE_TEMPLATE/feature.yml .github/ISSUE_TEMPLATE/feature.yml
  copy_file .github/ISSUE_TEMPLATE/bug.yml .github/ISSUE_TEMPLATE/bug.yml
  copy_file .github/ISSUE_TEMPLATE/task.yml .github/ISSUE_TEMPLATE/task.yml
}

write_starter_readme_if_missing() {
  write_file README.md <<'README'
# Project Initialized with Dogsquard

This repository uses Dogsquard governance for docs, local checks, issue templates, PR templates, and PR quality gates.

## Local Validation

```bash
make help
make doc-check
make doc-guard
make release-check
```

Keep project-specific source, tests, and product docs in their existing locations.
README
}

write_starter_changelog_if_missing() {
  write_file CHANGELOG.md <<'CHANGELOG'
# Changelog

## Unreleased

### Added

- Initialized repository governance from Dogsquard.
CHANGELOG
}

write_gitignore_if_missing() {
  write_file .gitignore <<'GITIGNORE'
.claude/
AGENTS.md
CLAUDE.md
roster.md
*.local
.env.local
dist/
node_modules/
frontend/dist/
frontend/node_modules/
frontend/playwright-report/
frontend/test-results/
GITIGNORE
}

ensure_local_private_ignores() {
  if [[ ! -f "$TARGET_DIR/.gitignore" ]]; then
    write_gitignore_if_missing
    return
  fi

  local entries=(
    ".claude/"
    "AGENTS.md"
    "CLAUDE.md"
    "roster.md"
  )
  local missing=()

  local entry
  for entry in "${entries[@]}"; do
    if grep -Fxq "$entry" "$TARGET_DIR/.gitignore"; then
      echo "SKIP .gitignore already contains: $entry"
    else
      missing+=("$entry")
    fi
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    plan "preserve existing .gitignore and append Dogsquard local/private agent file section"
    for entry in "${missing[@]}"; do
      plan "append to .gitignore: $entry"
    done
    return
  fi

  {
    printf '\n# Dogsquard local/private agent files\n'
    printf '%s\n' "${missing[@]}"
  } >> "$TARGET_DIR/.gitignore"
}

write_docs_only_makefile() {
  write_file Makefile <<'MAKEFILE'
SHELL := /bin/bash

.PHONY: help doc-check doc-guard agent-docs lint test release-check

help:
	@echo "Available commands:"
	@echo "  make help          Show this help"
	@echo "  make doc-check     Run local documentation checks"
	@echo "  make doc-guard     Run Doc Watch Guard report"
	@echo "  make agent-docs    Print a safe agent documentation review prompt"
	@echo "  make lint          Run docs-only lint placeholder"
	@echo "  make test          Run docs-only test placeholder"
	@echo "  make release-check Run documentation release checks"

doc-check:
	@./scripts/doc-check-local.sh

doc-guard:
	@./scripts/doc-guard.sh

agent-docs:
	@./scripts/agent-doc-review.sh

lint:
	@echo "No app lint configured for docs-only profile."

test:
	@echo "No app tests configured for docs-only profile."

release-check: doc-check doc-guard lint test
MAKEFILE
}

write_node_makefile() {
  write_file Makefile <<'MAKEFILE'
SHELL := /bin/bash

.PHONY: help install build test lint doc-check doc-guard agent-docs has-npm-script release-check

help:
	@echo "Available commands:"
	@echo "  make help          Show this help"
	@echo "  make install       Install Node dependencies"
	@echo "  make build         Run npm build when configured"
	@echo "  make test          Run npm test"
	@echo "  make lint          Run npm lint when configured"
	@echo "  make doc-check     Run local documentation checks"
	@echo "  make doc-guard     Run Doc Watch Guard report"
	@echo "  make agent-docs    Print a safe agent documentation review prompt"
	@echo "  make release-check Run docs, lint, test, and build checks"

install:
	@if [[ -f package-lock.json ]]; then npm ci; else npm install; fi

has-npm-script:
	@node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts[process.env.SCRIPT] ? 0 : 1)"

build:
	@set -euo pipefail; \
	if SCRIPT=build $(MAKE) --no-print-directory has-npm-script >/dev/null 2>&1; then \
		npm run build; \
	else \
		echo "No npm build script configured; skipping build."; \
	fi

test:
	@set -euo pipefail; \
	if SCRIPT=test $(MAKE) --no-print-directory has-npm-script >/dev/null 2>&1; then \
		npm test; \
	else \
		echo "No npm test script configured; skipping tests."; \
	fi

lint:
	@set -euo pipefail; \
	if SCRIPT=lint $(MAKE) --no-print-directory has-npm-script >/dev/null 2>&1; then \
		npm run lint; \
	else \
		echo "No npm lint script configured; using build as validation fallback."; \
		if SCRIPT=build $(MAKE) --no-print-directory has-npm-script >/dev/null 2>&1; then npm run build; else echo "No npm build fallback configured; skipping lint."; fi; \
	fi

doc-check:
	@./scripts/doc-check-local.sh

doc-guard:
	@./scripts/doc-guard.sh

agent-docs:
	@./scripts/agent-doc-review.sh

release-check: doc-check doc-guard lint test build
MAKEFILE
}

write_go_js_makefile() {
  write_file Makefile <<'MAKEFILE'
SHELL := /bin/bash

.PHONY: help test lint backend-test frontend-build doc-check doc-guard agent-docs release-check

help:
	@echo "Available commands:"
	@echo "  make help           Show this help"
	@echo "  make test           Run backend/frontend tests when present"
	@echo "  make lint           Run backend/frontend lint checks when present"
	@echo "  make backend-test   Run Go backend tests"
	@echo "  make frontend-build Install frontend dependencies and build"
	@echo "  make doc-check      Run local documentation checks"
	@echo "  make doc-guard      Run Doc Watch Guard report"
	@echo "  make agent-docs     Print a safe agent documentation review prompt"
	@echo "  make release-check  Run docs, lint, test, and frontend build checks"

test: backend-test
	@set -euo pipefail; \
	if [[ -d frontend && -f frontend/package.json ]] && grep -q '"test"' frontend/package.json; then \
		(cd frontend && npm test); \
	else \
		echo "No frontend test script configured; skipping frontend tests."; \
	fi

lint:
	@set -euo pipefail; \
	if [[ -d backend ]] && find backend -name '*.go' -type f | grep -q .; then \
		files="$$(find backend -name '*.go' -type f)"; \
		unformatted="$$(gofmt -l $$files)"; \
		if [[ -n "$$unformatted" ]]; then echo "gofmt required for:"; echo "$$unformatted"; exit 1; fi; \
		(cd backend && go vet ./...); \
	fi; \
	if [[ -d frontend && -f frontend/package.json ]] && grep -q '"lint"' frontend/package.json; then \
		(cd frontend && npm run lint); \
	else \
		echo "No frontend lint script configured; skipping frontend lint."; \
	fi

backend-test:
	@if [[ -d backend && -f backend/go.mod ]]; then \
		cd backend && go test ./...; \
	else \
		echo "No backend/go.mod found; skipping Go backend tests."; \
	fi

frontend-build:
	@if [[ -d frontend && -f frontend/package.json ]]; then \
		cd frontend && npm install && npm run build; \
	else \
		echo "No frontend/package.json found; skipping frontend build."; \
	fi

doc-check:
	@./scripts/doc-check-local.sh

doc-guard:
	@./scripts/doc-guard.sh

agent-docs:
	@./scripts/agent-doc-review.sh

release-check: doc-check doc-guard lint test frontend-build
MAKEFILE
}

write_docs_only_workflow() {
  write_file .github/workflows/pr-quality.yml <<'WORKFLOW'
name: PR Quality Gate

on:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  shell-check:
    name: Shell Check
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Bash syntax check
        run: bash -n scripts/*.sh

  repository-hygiene:
    name: Repository Hygiene
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Whitespace check
        run: git diff --check
      - name: Check local-only files
        run: |
          test ! -d .claude
          test ! -f AGENTS.md
          test ! -f CLAUDE.md
          test ! -f roster.md
          test ! -f .env.local

  docs-quality:
    name: Docs Quality
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Documentation checks
        run: |
          make doc-check
          make doc-guard
          make release-check

  pr-quality-summary:
    name: PR Quality Summary
    runs-on: ubuntu-24.04
    needs:
      - shell-check
      - repository-hygiene
      - docs-quality
    if: always()
    steps:
      - name: Summary
        run: |
          test "${{ needs.shell-check.result }}" = "success"
          test "${{ needs.repository-hygiene.result }}" = "success"
          test "${{ needs.docs-quality.result }}" = "success"
WORKFLOW
}

write_node_workflow() {
  write_file .github/workflows/pr-quality.yml <<'WORKFLOW'
name: PR Quality Gate

on:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  shell-check:
    name: Shell Check
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Bash syntax check
        run: bash -n scripts/*.sh

  repository-hygiene:
    name: Repository Hygiene
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Whitespace check
        run: git diff --check
      - name: Check local-only files
        run: |
          test ! -d .claude
          test ! -f AGENTS.md
          test ! -f CLAUDE.md
          test ! -f roster.md
          test ! -f .env.local
          test ! -d node_modules
          test ! -d dist

  node-quality:
    name: Node Quality
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      - name: Install dependencies
        run: |
          if [ -f package-lock.json ]; then
            npm ci
          else
            npm install
          fi
      - name: Local quality checks
        run: |
          make help
          make doc-check
          make doc-guard
          make release-check

  pr-quality-summary:
    name: PR Quality Summary
    runs-on: ubuntu-24.04
    needs:
      - shell-check
      - repository-hygiene
      - node-quality
    if: always()
    steps:
      - name: Summary
        run: |
          test "${{ needs.shell-check.result }}" = "success"
          test "${{ needs.repository-hygiene.result }}" = "success"
          test "${{ needs.node-quality.result }}" = "success"
WORKFLOW
}

write_go_js_workflow() {
  write_file .github/workflows/pr-quality.yml <<'WORKFLOW'
name: PR Quality Gate

on:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  shell-check:
    name: Shell Check
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Bash syntax check
        run: bash -n scripts/*.sh

  repository-hygiene:
    name: Repository Hygiene
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Whitespace check
        run: git diff --check
      - name: Check local-only files
        run: |
          test ! -d .claude
          test ! -f AGENTS.md
          test ! -f CLAUDE.md
          test ! -f roster.md
          test ! -f .env.local
          test ! -d node_modules
          test ! -d frontend/node_modules
          test ! -d frontend/dist

  go-js-quality:
    name: Go/JS Quality
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        if: hashFiles('backend/go.mod') != ''
        with:
          go-version-file: backend/go.mod
      - uses: actions/setup-node@v4
        if: hashFiles('frontend/package.json') != ''
        with:
          node-version: "20"
      - name: Local quality checks
        run: |
          make help
          make doc-check
          make doc-guard
          make release-check

  pr-quality-summary:
    name: PR Quality Summary
    runs-on: ubuntu-24.04
    needs:
      - shell-check
      - repository-hygiene
      - go-js-quality
    if: always()
    steps:
      - name: Summary
        run: |
          test "${{ needs.shell-check.result }}" = "success"
          test "${{ needs.repository-hygiene.result }}" = "success"
          test "${{ needs.go-js-quality.result }}" = "success"
WORKFLOW
}

maybe_create_node_data_gitkeep() {
  [[ "$PROJECT_TYPE" == "node" ]] || return

  local should_create=false
  if [[ -d "$TARGET_DIR/data" ]]; then
    should_create=true
  elif [[ -f "$TARGET_DIR/.gitignore" ]] && grep -qE '(^|/)data(/|\*)' "$TARGET_DIR/.gitignore"; then
    should_create=true
  elif [[ -f "$TARGET_DIR/package.json" ]] && grep -q '"sql.js"' "$TARGET_DIR/package.json"; then
    should_create=true
  fi

  if [[ "$should_create" == "true" ]]; then
    ensure_dir data
    touch_file data/.gitkeep
  else
    echo "SKIP node data placeholder: no data directory or runtime-data signal detected."
  fi
}

copy_optional_example_app() {
  if [[ "$INCLUDE_EXAMPLE_APP" == "true" ]]; then
    echo
    echo "Optional example app:"
    copy_dir backend backend
    copy_dir frontend frontend
    copy_file scripts/e2e-smoke.sh scripts/e2e-smoke.sh
    copy_file scripts/smoke-api.sh scripts/smoke-api.sh
  else
    echo
    echo "SKIP optional example app: set INCLUDE_EXAMPLE_APP=true to copy backend/ and frontend/."
  fi
}

copy_optional_dev_deploy() {
  if [[ "$INCLUDE_DEV_DEPLOY" == "true" ]]; then
    echo
    echo "Dev deploy assets:"
    copy_file .github/workflows/deploy-dev.yml .github/workflows/deploy-dev.yml
    copy_file scripts/deploy-dev.sh scripts/deploy-dev.sh
    copy_file scripts/package-release.sh scripts/package-release.sh
    copy_file scripts/remote-deploy.sh scripts/remote-deploy.sh
    copy_file scripts/remote-runtime.sh scripts/remote-runtime.sh
    copy_file scripts/runtime-dev.sh scripts/runtime-dev.sh
    copy_file scripts/server-preflight.sh scripts/server-preflight.sh
    write_dev_high_port_env
    write_dev_high_port_runbook
  else
    echo
    echo "SKIP dev deploy assets: INCLUDE_DEV_DEPLOY=false."
  fi
}

write_dev_high_port_env() {
  write_file .env.dogsquard-dev.example <<'ENV'
# Dogsquard dev access defaults.
# These values are examples only; keep real secrets in GitHub environment secrets.

DEV_HOST=cn.ant
DEV_DEPLOY_ROOT=~/apps/dogsquard-dev
DEV_FRONTEND_PUBLIC_PORT=8173
DEV_BACKEND_PUBLIC_PORT=8180
DEV_FRONTEND_INTERNAL_PORT=14173
DEV_BACKEND_INTERNAL_PORT=18080
DEV_PUBLIC_ACCESS_MODE=high-port
ENV
}

write_dev_high_port_runbook() {
  write_file docs/07_runbooks/runbook-dev-high-port-access.md <<'RUNBOOK'
---
title: "Dev High-port Access"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Dev High-port Access

## Purpose

Document the default Dogsquard dev access shape generated for applicable bootstrap profiles.

## Current Dev Target

- Dev host: `cn.ant`
- Firewall allows: `80`, `22`, `443`, `8000-8999`, and ICMP.
- Frontend public/dev candidate port: `8173`
- Backend public/dev candidate port: `8180`

## Scope

High-port access is for dev validation only.

Do not use this as production deployment.
Do not target `us.hermes`.
Do not claim `proletariat.icu` `/` or `/api`.
Do not commit secrets.

## Future Route Option

A future HTTP-only dev route may use a path under `dev.proletariat.icu/xxxx` on `cn.ant`, after explicit routing design.

## Production Separation

Production deployment remains separate and requires explicit approval before implementation.
RUNBOOK
}

copy_optional_production_profile() {
  if [[ "$INCLUDE_PRODUCTION_PROFILE" == "true" ]]; then
    echo
    echo "Production profile scaffold:"
    write_production_profile_env
    write_production_profile_guard
    write_production_profile_runbook
    write_production_profile_test_plan
  else
    echo
    echo "SKIP production profile scaffold: set INCLUDE_PRODUCTION_PROFILE=true to generate planning-only production templates."
  fi
}

write_production_profile_env() {
  write_file .env.dogsquard-production.example <<'ENV'
# Dogsquard production profile scaffold.
# This file contains placeholder names only. Do not commit real secrets.
# Production implementation and route activation require separate explicit approval.

PRODUCTION_PROFILE_ENABLED=false
PROD_APP_NAME=REPLACE_ME
PROD_REPO_NAME=REPLACE_WITH_REPO_NAME
PROD_HOST=us.hermes
PROD_USER_SECRET_NAME=PROD_USER
PROD_SSH_KEY_SECRET_NAME=PROD_SSH_KEY
PROD_DEPLOY_ROOT=REQUIRES_EXPLICIT_APPROVAL
PROD_DOMAIN=proletariat.icu
PROD_FRONTEND_ROUTE=/REPLACE_WITH_REPO_NAME/
PROD_BACKEND_ROUTE=/REPLACE_WITH_REPO_NAME/api
PROD_ROUTE=REQUIRES_ROUTE_APPROVAL
PROD_BACKEND_PORT=REQUIRES_EXPLICIT_APPROVAL
PROD_FRONTEND_PORT=REQUIRES_EXPLICIT_APPROVAL
PROD_GITHUB_ENVIRONMENT=production
PROD_ROLLBACK_RELEASE_ID=REQUIRES_EXPLICIT_RELEASE_ID

# Protected targets and route boundaries.
# Current approved production planning target is us.hermes, but production
# implementation still requires separate explicit approval.
APPROVED_PRODUCTION_HOST=us.hermes
APPROVED_PRODUCTION_DOMAIN=proletariat.icu
APPROVED_FRONTEND_ROUTE=/{reponame}/
APPROVED_BACKEND_ROUTE=/{reponame}/api
PROTECTED_PRODUCTION_HOSTS=43.130.49.185
PROTECTED_PRODUCTION_DOMAINS=proletariat.icu,www.proletariat.icu
PROTECTED_PRODUCTION_ROUTES=/,/api
ENV
}

write_production_profile_guard() {
  write_file scripts/production-profile-guard.sh <<'GUARD'
#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 2
}

PROD_HOST="${PROD_HOST:-}"
PROD_DOMAIN="${PROD_DOMAIN:-}"
PROD_ROUTE="${PROD_ROUTE:-}"
PROD_REPO_NAME="${PROD_REPO_NAME:-}"

[[ -n "$PROD_HOST" ]] || fail "PROD_HOST is required for production planning validation."
[[ -n "$PROD_DOMAIN" ]] || fail "PROD_DOMAIN is required for production planning validation."
[[ -n "$PROD_ROUTE" ]] || fail "PROD_ROUTE is required for production planning validation."

case "$PROD_HOST" in
  43.130.49.185)
    fail "raw protected production IP is not allowed as a production target: $PROD_HOST"
    ;;
  us.hermes)
    echo "INFO: us.hermes selected; repo-scoped route guard is required."
    ;;
esac

case "$PROD_ROUTE" in
  /|/api|/api/*)
    fail "protected production route is not allowed: $PROD_ROUTE"
    ;;
esac

case "$PROD_DOMAIN" in
  www.proletariat.icu)
    fail "www.proletariat.icu is reserved for existing multica routes and is not allowed for generated production profile planning."
    ;;
  proletariat.icu)
    [[ -n "$PROD_REPO_NAME" ]] || fail "PROD_REPO_NAME is required for repo-scoped proletariat.icu routes."
    [[ "$PROD_REPO_NAME" != "REPLACE_WITH_REPO_NAME" ]] || fail "PROD_REPO_NAME must be replaced before route validation."
    case "$PROD_ROUTE" in
      "/$PROD_REPO_NAME"|"/$PROD_REPO_NAME/"|"/$PROD_REPO_NAME/api"|"/$PROD_REPO_NAME/api/"|"/$PROD_REPO_NAME/api/"*)
        ;;
      *)
        fail "proletariat.icu production routes must stay under /${PROD_REPO_NAME}/ or /${PROD_REPO_NAME}/api: $PROD_ROUTE"
        ;;
    esac
    ;;
esac

echo "PASS: production profile guard accepted current placeholder values."
echo "No deployment, server change, reverse proxy change, or route activation was performed."
GUARD

  if [[ "$DRY_RUN" == "true" ]]; then
    plan "chmod +x scripts/production-profile-guard.sh"
  elif [[ -f "$TARGET_DIR/scripts/production-profile-guard.sh" ]]; then
    chmod +x "$TARGET_DIR/scripts/production-profile-guard.sh"
  fi
}

write_production_profile_runbook() {
  write_file docs/07_runbooks/runbook-production-profile.md <<'RUNBOOK'
---
title: "Production Profile Scaffold"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-06-01"
updated: "2026-06-01"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Purpose

Document the scaffold-only production profile generated by Dogsquard.

This profile prepares production planning assets for an adopted app. It does not add a production deploy workflow, change servers, edit reverse proxies, or expose a public route.

Current approved production planning target:

- host: `us.hermes`
- frontend route shape: `https://proletariat.icu/{reponame}/`
- backend route shape: `https://proletariat.icu/{reponame}/api`

This route strategy is approval for planning and scaffold validation only. Production implementation still requires separate explicit approval.

# Scope

Generated assets:

- `.env.dogsquard-production.example`
- `scripts/production-profile-guard.sh`
- `docs/07_runbooks/runbook-production-profile.md`
- `docs/06_testing/test-production-profile.md`

# Required Approval Before Implementation

Production implementation requires separate explicit approval for:

- target app
- production host
- route or domain
- GitHub production environment
- rollback strategy
- diagnostics policy

# Protected Targets

Do not target without later explicit implementation approval:

- `43.130.49.185`
- `www.proletariat.icu`
- `/`
- `/api`
- existing multica containers
- existing reverse proxy configuration

# Guard Check

The generated guard validates candidate production values without deploying:

```bash
PROD_HOST=us.hermes \
PROD_DOMAIN=proletariat.icu \
PROD_REPO_NAME=dogpdteamreport \
PROD_ROUTE=/dogpdteamreport \
scripts/production-profile-guard.sh
```

The guard must fail for raw protected IPs, `www.proletariat.icu`, root routes, top-level `/api`, and `proletariat.icu` routes outside the approved repo prefix. Passing the guard does not approve implementation or route activation.

# What Not To Do

Do not:

- add `.github/workflows/deploy-production.yml`
- run production deploy
- edit server config
- edit reverse proxy config
- expose a public URL
- commit secrets
- paste raw server config or logs into docs
RUNBOOK
}

write_production_profile_test_plan() {
  write_file docs/06_testing/test-production-profile.md <<'TESTPLAN'
---
title: "Production Profile Scaffold Test Plan"
doc_type: "test"
status: "draft"
owner: "user"
source: "agent"
created: "2026-06-01"
updated: "2026-06-01"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Objective

Validate the scaffold-only production profile without implementing production deployment.

# Positive Checks

- production profile docs exist
- placeholder environment example exists
- production guard script exists
- guard accepts approved `us.hermes` plus repo-scoped `proletariat.icu/{reponame}` route values
- no production workflow exists
- no public route is activated

# Negative Checks

The guard must reject:

- `PROD_HOST=43.130.49.185`
- `PROD_DOMAIN=www.proletariat.icu`
- `PROD_ROUTE=/`
- `PROD_ROUTE=/api`
- `PROD_DOMAIN=proletariat.icu` with routes outside `/{reponame}/` or `/{reponame}/api`

# Acceptance Criteria

- local docs checks pass
- generated repo PR Quality Gate can run
- no production deploy workflow is generated
- no server config is committed
- production implementation remains blocked until separate explicit approval
TESTPLAN
}

echo "Governance core:"
create_docs_structure
copy_core_governance_docs
copy_governance_scripts
copy_github_templates
write_starter_readme_if_missing
write_starter_changelog_if_missing
ensure_local_private_ignores

echo
echo "Profile assets:"
case "$PROJECT_TYPE" in
  node)
    write_node_makefile
    write_node_workflow
    maybe_create_node_data_gitkeep
    ;;
  go-js)
    write_go_js_makefile
    write_go_js_workflow
    ;;
  docs-only)
    write_docs_only_makefile
    write_docs_only_workflow
    ;;
esac

copy_optional_example_app
copy_optional_dev_deploy
copy_optional_production_profile

echo
if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run complete. Re-run with DRY_RUN=false to apply."
else
  echo "Bootstrap complete. Review generated files before committing in the target repository."
fi
