SHELL := /bin/bash

.PHONY: help test lint doc-check doc-guard watch-docs agent-docs backend-test frontend-build smoke-api e2e-smoke server-preflight package-release deploy-dev deploy-dev-dry-run runtime-status runtime-start runtime-stop runtime-restart runtime-health runtime-logs runtime-diagnose rollback-dev init-new-repo bootstrap-dry-run bootstrap-test backend-dev frontend-dev release-check

help:
	@echo "Available commands:"
	@echo "  make help          Show this help"
	@echo "  make test          Run backend/frontend tests when present"
	@echo "  make lint          Run backend/frontend lint checks when present"
	@echo "  make doc-check     Run local documentation checks"
	@echo "  make doc-guard     Run Doc Watch Guard report"
	@echo "  make watch-docs    Re-run doc checks in a loop"
	@echo "  make agent-docs    Print a safe agent documentation review prompt"
	@echo "  make backend-test  Run backend Go tests"
	@echo "  make frontend-build Install frontend dependencies and build"
	@echo "  make smoke-api     Run API smoke test against a running backend"
	@echo "  make e2e-smoke     Run minimal Playwright smoke test with local servers"
	@echo "  make server-preflight HOST=<ssh-target> Run read-only server discovery"
	@echo "  make package-release Build backend/frontend release artifact"
	@echo "  make deploy-dev HOST=<ssh-target> DRY_RUN=true|false Run opt-in dev deploy wrapper"
	@echo "  make deploy-dev-dry-run HOST=<ssh-target> Run dev deploy wrapper in dry-run mode"
	@echo "  make runtime-status HOST=<ssh-target> Check remote Dogsquard runtime status"
	@echo "  make runtime-start HOST=<ssh-target> Start remote Dogsquard runtime"
	@echo "  make runtime-stop HOST=<ssh-target> Stop remote Dogsquard runtime"
	@echo "  make runtime-restart HOST=<ssh-target> Restart remote Dogsquard runtime"
	@echo "  make runtime-health HOST=<ssh-target> Check remote Dogsquard runtime health"
	@echo "  make runtime-logs HOST=<ssh-target> [COMPONENT=backend|frontend] Tail remote runtime logs"
	@echo "  make runtime-diagnose HOST=<ssh-target> Run remote runtime diagnostics"
	@echo "  make rollback-dev HOST=<ssh-target> TARGET_RELEASE=<id> Switch remote current symlink"
	@echo "  make bootstrap-dry-run TARGET=<path> PROJECT_TYPE=node|go-js|docs-only"
	@echo "  make bootstrap-test Run profile-aware bootstrap script tests"
	@echo "  make init-new-repo TARGET=<path> [DRY_RUN=false] Legacy conservative bootstrap"
	@echo "  make backend-dev   Run the example Go backend"
	@echo "  make frontend-dev  Run the example frontend dev server"
	@echo "  make release-check Run doc-check, lint, test, and frontend build"

test:
	@set -euo pipefail; \
	ran=0; \
	if [[ -d backend ]] && find backend -name '*.go' -type f | grep -q .; then \
		echo "Running Go tests..."; \
		(cd backend && go test ./...); \
		ran=1; \
	fi; \
	if [[ -d frontend && -f frontend/package.json ]]; then \
		if grep -q '"test"' frontend/package.json; then \
			echo "Running frontend tests..."; \
			(cd frontend && npm test); \
		else \
			echo "frontend/package.json has no test script; skipping frontend tests."; \
		fi; \
		ran=1; \
	fi; \
	if [[ "$$ran" -eq 0 ]]; then \
		echo "No backend Go files or frontend package.json found; skipping tests."; \
	fi

lint:
	@set -euo pipefail; \
	ran=0; \
	if [[ -d backend ]] && find backend -name '*.go' -type f | grep -q .; then \
		echo "Checking Go formatting..."; \
		files="$$(find backend -name '*.go' -type f)"; \
		unformatted="$$(gofmt -l $$files)"; \
		if [[ -n "$$unformatted" ]]; then \
			echo "gofmt required for:"; \
			echo "$$unformatted"; \
			exit 1; \
		fi; \
		echo "Running go vet..."; \
		(cd backend && go vet ./...); \
		ran=1; \
	fi; \
	if [[ -d frontend && -f frontend/package.json ]]; then \
		if grep -q '"lint"' frontend/package.json; then \
			echo "Running frontend lint..."; \
			(cd frontend && npm run lint); \
		else \
			echo "frontend/package.json has no lint script; skipping frontend lint."; \
		fi; \
		ran=1; \
	fi; \
	if [[ "$$ran" -eq 0 ]]; then \
		echo "No backend Go files or frontend package.json found; skipping lint."; \
	fi

doc-check:
	@./scripts/doc-check-local.sh

doc-guard:
	@./scripts/doc-guard.sh

watch-docs:
	@./scripts/watch-docs.sh

agent-docs:
	@./scripts/agent-doc-review.sh

backend-test:
	@cd backend && go test ./...

frontend-build:
	@if [[ -d frontend && -f frontend/package.json ]]; then \
		cd frontend && npm install && npm run build; \
	else \
		echo "No frontend/package.json found; skipping frontend build."; \
	fi

smoke-api:
	@./scripts/smoke-api.sh

e2e-smoke:
	@./scripts/e2e-smoke.sh

server-preflight:
	@if [[ -z "$${HOST:-}" ]]; then \
		echo "Usage: make server-preflight HOST=us.hermes"; \
		echo "   or: make server-preflight HOST=cn.ant"; \
		exit 2; \
	fi; \
	./scripts/server-preflight.sh "$$HOST"

package-release:
	@./scripts/package-release.sh

deploy-dev:
	@if [[ -z "$${HOST:-}" ]]; then \
		echo "Usage: make deploy-dev HOST=cn.ant DRY_RUN=true DEPLOY_ROOT=~/apps/dogsquard-dev"; \
		echo "Actual deploy requires explicit DRY_RUN=false."; \
		exit 2; \
	fi; \
	./scripts/deploy-dev.sh

deploy-dev-dry-run:
	@if [[ -z "$${HOST:-}" ]]; then \
		echo "Usage: make deploy-dev-dry-run HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev"; \
		exit 2; \
	fi; \
	DRY_RUN=true ./scripts/deploy-dev.sh

runtime-status:
	@if [[ -z "$${HOST:-}" ]]; then \
		echo "Usage: make runtime-status HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev"; \
		exit 2; \
	fi; \
	ACTION=status ./scripts/runtime-dev.sh

runtime-start:
	@if [[ -z "$${HOST:-}" ]]; then \
		echo "Usage: make runtime-start HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev"; \
		exit 2; \
	fi; \
	ACTION=start ./scripts/runtime-dev.sh

runtime-stop:
	@if [[ -z "$${HOST:-}" ]]; then \
		echo "Usage: make runtime-stop HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev"; \
		exit 2; \
	fi; \
	ACTION=stop ./scripts/runtime-dev.sh

runtime-restart:
	@if [[ -z "$${HOST:-}" ]]; then \
		echo "Usage: make runtime-restart HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev"; \
		exit 2; \
	fi; \
	ACTION=restart ./scripts/runtime-dev.sh

runtime-health:
	@if [[ -z "$${HOST:-}" ]]; then \
		echo "Usage: make runtime-health HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev"; \
		exit 2; \
	fi; \
	ACTION=health ./scripts/runtime-dev.sh

runtime-logs:
	@if [[ -z "$${HOST:-}" ]]; then \
		echo "Usage: make runtime-logs HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev [COMPONENT=backend|frontend]"; \
		exit 2; \
	fi; \
	ACTION=logs ./scripts/runtime-dev.sh

runtime-diagnose:
	@if [[ -z "$${HOST:-}" ]]; then \
		echo "Usage: make runtime-diagnose HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev"; \
		exit 2; \
	fi; \
	ACTION=diagnose ./scripts/runtime-dev.sh

rollback-dev:
	@if [[ -z "$${HOST:-}" || -z "$${TARGET_RELEASE:-}" ]]; then \
		echo "Usage: make rollback-dev HOST=cn.ant TARGET_RELEASE=<release-id> DEPLOY_ROOT=~/apps/dogsquard-dev"; \
		exit 2; \
	fi; \
	ACTION=rollback ./scripts/runtime-dev.sh

init-new-repo:
	@if [[ -z "$${TARGET:-}" ]]; then \
		echo "Usage: make init-new-repo TARGET=../new-project"; \
		echo "   or: make init-new-repo TARGET=../new-project DRY_RUN=false"; \
		echo "   or: make init-new-repo TARGET=../new-project DRY_RUN=false INCLUDE_EXAMPLE_APP=true"; \
		echo "   or: make init-new-repo TARGET=../new-project DRY_RUN=false INCLUDE_DEV_DEPLOY=true"; \
		exit 2; \
	fi; \
	./scripts/init-new-repo.sh "$$TARGET"

bootstrap-dry-run:
	@if [[ -z "$${TARGET:-}" || -z "$${PROJECT_TYPE:-}" ]]; then \
		echo "Usage: make bootstrap-dry-run TARGET=../new-project PROJECT_TYPE=node|go-js|docs-only"; \
		exit 2; \
	fi; \
	TARGET_DIR="$$TARGET" DRY_RUN=true ./scripts/bootstrap-project.sh

bootstrap-test:
	@./scripts/test-bootstrap-project.sh

backend-dev:
	@cd backend && go run ./cmd/server

frontend-dev:
	@cd frontend && npm run dev

release-check: doc-check lint test frontend-build
