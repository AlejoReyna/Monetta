.PHONY: help setup gen gen-watch test test-core test-services test-all analyze format fix schema clean run-dev run-staging validate-staging validate-production build-staging-android build-production-android refresh-catalog verify-catalog verify-catalog-remote doctor

FLUTTER ?= flutter
DART    ?= dart

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

doctor: ## Verify the toolchain is installed correctly
	$(FLUTTER) doctor -v

setup: ## Install dependencies
	$(FLUTTER) pub get

gen: ## Run all code generation (freezed, drift, ferry, riverpod)
	$(DART) run build_runner build --delete-conflicting-outputs

gen-watch: ## Code generation in watch mode
	$(DART) run build_runner watch --delete-conflicting-outputs

schema: ## Download the Shopify Storefront API schema for ferry codegen
	./scripts/fetch_schema.sh

test: ## Run all tests
	$(FLUTTER) test

test-core: ## Run only the pure-Dart core tests (fast: no widget pump)
	$(FLUTTER) test test/normalize test/reco

test-services: ## Run tests and type checks for active TypeScript services
	npm --prefix services/accounts_orders test
	npm --prefix services/accounts_orders run typecheck
	# catalog_monitor retired from product CI (WP-02); see docs/audits/2026-09-07/EXTERNAL_CATALOG_DECOMMISSION.md
	npm --prefix functions test
	npm --prefix functions run typecheck
	npm run typecheck:api
	npm run build:web

test-all: format analyze test test-services verify-catalog ## Run the complete local quality gate
	./bin/check_no_secrets.sh

report: ## Print the catalog health report the owner acts on
	$(DART) run bin/catalog_report.dart

refresh-catalog: ## Regenerate the bundled snapshot from its public source
	$(DART) run bin/refresh_catalog_snapshot.dart

verify-catalog: ## Check bundled catalog shape and freshness
	$(DART) run bin/verify_catalog_snapshot.dart

verify-catalog-remote: ## Also verify every bundled product image URL
	$(DART) run bin/verify_catalog_snapshot.dart --remote

analyze: ## Static analysis
	$(FLUTTER) analyze

format: ## Check formatting (CI-safe)
	$(DART) format --output=none --set-exit-if-changed lib test integration_test

fix: ## Apply formatting and automated fixes
	$(DART) format lib test integration_test
	$(DART) fix --apply

validate-staging: ## Validate the local staging dart-defines
	$(DART) run bin/validate_dart_defines.dart config/dart_defines.staging.json staging

validate-production: ## Validate the local production dart-defines
	$(DART) run bin/validate_dart_defines.dart config/dart_defines.production.json production

run-staging: validate-staging ## Run against the authoritative staging catalog
	$(FLUTTER) run --flavor staging --dart-define-from-file=config/dart_defines.staging.json

run-dev: run-staging ## Alias for the canonical staging launch

build-staging-android: validate-staging ## Build the signed/debug staging Android artifact
	$(FLUTTER) build apk --debug --flavor staging --dart-define-from-file=config/dart_defines.staging.json

build-production-android: validate-production ## Build the production Android App Bundle
	$(FLUTTER) build appbundle --release --flavor production --dart-define-from-file=config/dart_defines.production.json

clean: ## Clean build artifacts
	$(FLUTTER) clean
	$(FLUTTER) pub get
