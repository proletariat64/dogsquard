SHELL := /bin/bash

.PHONY: help test lint doc-check doc-guard watch-docs agent-docs backend-test frontend-build smoke-api e2e-smoke server-preflight package-release deploy-dev deploy-dev-dry-run backend-dev frontend-dev release-check

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

backend-dev:
	@cd backend && go run ./cmd/server

frontend-dev:
	@cd frontend && npm run dev

release-check: doc-check lint test frontend-build
