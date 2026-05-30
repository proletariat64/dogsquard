SHELL := /bin/bash

.PHONY: help test lint doc-check doc-guard watch-docs agent-docs backend-test frontend-build smoke-api backend-dev frontend-dev release-check

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

backend-dev:
	@cd backend && go run ./cmd/server

frontend-dev:
	@cd frontend && npm run dev

release-check: doc-check lint test frontend-build
