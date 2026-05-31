#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-dogsquard}"
DRY_RUN="${DRY_RUN:-true}"
FORCE="${FORCE:-false}"
INCLUDE_EXAMPLE_APP="${INCLUDE_EXAMPLE_APP:-false}"
INCLUDE_DEV_DEPLOY="${INCLUDE_DEV_DEPLOY:-false}"

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/init-new-repo.sh <target-path>"
  echo
  echo "Defaults to dry-run mode."
  echo "Examples:"
  echo "  scripts/init-new-repo.sh ../new-project"
  echo "  DRY_RUN=false scripts/init-new-repo.sh ../new-project"
  echo "  DRY_RUN=false FORCE=true scripts/init-new-repo.sh ../new-project"
  echo "  DRY_RUN=false INCLUDE_EXAMPLE_APP=true scripts/init-new-repo.sh ../new-project"
  echo "  DRY_RUN=false INCLUDE_DEV_DEPLOY=true scripts/init-new-repo.sh ../new-project"
  exit 2
fi

TARGET="$1"
if [[ ! -d "$TARGET" ]]; then
  echo "FAIL: target path is not a directory: $TARGET"
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$(cd "$TARGET" && pwd)"

if [[ "$TARGET_DIR" == "$ROOT_DIR" ]]; then
  echo "FAIL: target path must not be the Dogsquard repository itself."
  exit 2
fi

case "$DRY_RUN" in
  true|false) ;;
  *) echo "FAIL: DRY_RUN must be true or false."; exit 2 ;;
esac

case "$FORCE" in
  true|false) ;;
  *) echo "FAIL: FORCE must be true or false."; exit 2 ;;
esac

case "$INCLUDE_EXAMPLE_APP" in
  true|false) ;;
  *) echo "FAIL: INCLUDE_EXAMPLE_APP must be true or false."; exit 2 ;;
esac

case "$INCLUDE_DEV_DEPLOY" in
  true|false) ;;
  *) echo "FAIL: INCLUDE_DEV_DEPLOY must be true or false."; exit 2 ;;
esac

echo "Dogsquard new-repo bootstrap"
echo "TARGET=$TARGET_DIR"
echo "DRY_RUN=$DRY_RUN"
echo "FORCE=$FORCE"
echo "INCLUDE_EXAMPLE_APP=$INCLUDE_EXAMPLE_APP"
echo "INCLUDE_DEV_DEPLOY=$INCLUDE_DEV_DEPLOY"
echo

mkdir_if_needed() {
  local dir="$1"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "PLAN mkdir -p $dir"
  else
    mkdir -p "$dir"
  fi
}

copy_file() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "$ROOT_DIR/$src" ]]; then
    echo "FAIL: source file missing: $src"
    exit 1
  fi

  if [[ -e "$TARGET_DIR/$dest" && "$FORCE" != "true" ]]; then
    echo "SKIP exists: $dest"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "PLAN copy file: $src -> $dest"
  else
    mkdir -p "$(dirname "$TARGET_DIR/$dest")"
    cp "$ROOT_DIR/$src" "$TARGET_DIR/$dest"
  fi
}

copy_dir() {
  local src="$1"
  local dest="$2"

  if [[ ! -d "$ROOT_DIR/$src" ]]; then
    echo "FAIL: source directory missing: $src"
    exit 1
  fi

  if [[ -e "$TARGET_DIR/$dest" && "$FORCE" != "true" ]]; then
    echo "SKIP exists: $dest"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "PLAN copy directory: $src -> $dest"
  else
    mkdir -p "$(dirname "$TARGET_DIR/$dest")"
    rm -rf "$TARGET_DIR/$dest"
    cp -R "$ROOT_DIR/$src" "$TARGET_DIR/$dest"
  fi
}

write_starter_readme() {
  local dest="README.md"
  if [[ -e "$TARGET_DIR/$dest" && "$FORCE" != "true" ]]; then
    echo "SKIP exists: $dest"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "PLAN write starter README.md"
    return
  fi

  cat > "$TARGET_DIR/$dest" <<'README'
# New Dogsquard Project

This repository was initialized from Dogsquard.

## Start Here

- Read or create the Control Board issue.
- Review `docs/05_design/design-20260531-project-roadmap.md`.
- Review `docs/07_runbooks/runbook-control-board.md`.
- Add product-specific BRD, PRD, BDD, and ADR documents before implementation.

## Local Validation

```bash
make doc-check
make doc-guard
make release-check
git diff --check
bash -n scripts/*.sh
```

## Notes

Dogsquard provides process, docs, local commands, GitHub workflow, and delivery foundations. It does not define your business product.
README
}

write_starter_changelog() {
  local dest="CHANGELOG.md"
  if [[ -e "$TARGET_DIR/$dest" && "$FORCE" != "true" ]]; then
    echo "SKIP exists: $dest"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "PLAN write starter CHANGELOG.md"
    return
  fi

  cat > "$TARGET_DIR/$dest" <<'CHANGELOG'
# Changelog

## Unreleased

### Added

- Initialized repository from Dogsquard.
CHANGELOG
}

write_template_gitignore() {
  local dest=".gitignore"
  if [[ -e "$TARGET_DIR/$dest" && "$FORCE" != "true" ]]; then
    echo "SKIP exists: $dest"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "PLAN write .gitignore"
    return
  fi

  cat > "$TARGET_DIR/$dest" <<'GITIGNORE'
.claude/
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
    mkdir_if_needed "$TARGET_DIR/$dir"
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "PLAN touch $dir/.gitkeep"
    else
      touch "$TARGET_DIR/$dir/.gitkeep"
    fi
  done
}

copy_core_docs() {
  local files=(
    docs/01_brd/brd-20260530-project-operating-model.md
    docs/02_prd/prd-20260530-document-governance.md
    docs/03_bdd/bdd-20260530-document-governance.md
    docs/04_adr/0001-use-github-actions-as-ci-authority.md
    docs/05_design/design-20260530-agent-charter.md
    docs/05_design/design-20260531-project-roadmap.md
    docs/05_design/design-20260531-template-inventory.md
    docs/06_testing/test-20260530-pr-quality-gate.md
    docs/06_testing/test-20260531-template-finalization.md
    docs/07_runbooks/runbook-branch-protection.md
    docs/07_runbooks/runbook-ci-failure-debugging.md
    docs/07_runbooks/runbook-control-board.md
    docs/07_runbooks/runbook-github-labels.md
    docs/07_runbooks/runbook-new-repo-bootstrap.md
    docs/07_runbooks/runbook-pr-quality-gate.md
    docs/08_releases/release-v0.1.0-candidate.md
    docs/ci-cd-implementation-plan.md
  )

  local file
  for file in "${files[@]}"; do
    copy_file "$file" "$file"
  done
}

copy_core_scripts() {
  local files=(
    scripts/agent-doc-review.sh
    scripts/doc-check-local.sh
    scripts/doc-guard.sh
    scripts/lib-doc-rules.sh
    scripts/watch-docs.sh
  )

  local file
  for file in "${files[@]}"; do
    copy_file "$file" "$file"
  done
}

copy_dev_deploy_assets() {
  local files=(
    .github/workflows/deploy-dev.yml
    scripts/deploy-dev.sh
    scripts/package-release.sh
    scripts/remote-deploy.sh
    scripts/remote-runtime.sh
    scripts/runtime-dev.sh
    scripts/server-preflight.sh
    docs/02_prd/prd-20260530-dev-deploy-workflow.md
    docs/02_prd/prd-20260530-dev-deployment.md
    docs/03_bdd/bdd-20260530-dev-deploy-workflow.md
    docs/03_bdd/bdd-20260530-dev-deployment.md
    docs/04_adr/0003-use-ssh-artifact-deploy-for-dev.md
    docs/04_adr/0005-use-github-actions-for-cn-ant-dev-deploy.md
    docs/06_testing/test-20260530-dev-deploy-workflow.md
    docs/06_testing/test-20260530-dev-deployment.md
    docs/07_runbooks/runbook-dev-deployment.md
    docs/07_runbooks/runbook-github-dev-deploy-workflow.md
    docs/07_runbooks/runbook-server-preflight.md
  )

  local file
  for file in "${files[@]}"; do
    copy_file "$file" "$file"
  done
}

copy_example_app_assets() {
  copy_dir backend backend
  copy_dir frontend frontend
  copy_file scripts/e2e-smoke.sh scripts/e2e-smoke.sh
  copy_file scripts/smoke-api.sh scripts/smoke-api.sh
  copy_file docs/02_prd/prd-20260530-example-internal-app.md docs/02_prd/prd-20260530-example-internal-app.md
  copy_file docs/03_bdd/bdd-20260530-example-internal-app.md docs/03_bdd/bdd-20260530-example-internal-app.md
  copy_file docs/04_adr/0002-use-small-internal-task-intake-as-example-app.md docs/04_adr/0002-use-small-internal-task-intake-as-example-app.md
  copy_file docs/06_testing/test-20260530-example-internal-app.md docs/06_testing/test-20260530-example-internal-app.md
  copy_file docs/07_runbooks/runbook-example-app-local-development.md docs/07_runbooks/runbook-example-app-local-development.md
}

echo "Template core:"
create_docs_structure
copy_core_docs
copy_core_scripts
copy_file Makefile Makefile
copy_file .env.example .env.example
copy_dir .github/ISSUE_TEMPLATE .github/ISSUE_TEMPLATE
copy_file .github/pull_request_template.md .github/pull_request_template.md
copy_file .github/labels.yml .github/labels.yml
copy_file .github/workflows/pr-quality.yml .github/workflows/pr-quality.yml
write_starter_readme
write_starter_changelog
write_template_gitignore

if [[ "$INCLUDE_EXAMPLE_APP" == "true" ]]; then
  echo
  echo "Optional example app:"
  copy_example_app_assets
else
  echo
  echo "SKIP optional example app: set INCLUDE_EXAMPLE_APP=true to copy backend/ and frontend/."
fi

if [[ "$INCLUDE_DEV_DEPLOY" == "true" ]]; then
  echo
  echo "Optional dev deploy assets:"
  copy_dev_deploy_assets
else
  echo
  echo "SKIP optional dev deploy assets: set INCLUDE_DEV_DEPLOY=true to copy deploy workflow/docs/scripts."
fi

echo
if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run complete. Re-run with DRY_RUN=false to apply."
else
  echo "Bootstrap complete."
  echo "Review generated files before committing in the target repo."
fi
