.PHONY: help setup gen gen-watch test test-core analyze format fix schema clean run-dev doctor

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

analyze: ## Static analysis
	$(FLUTTER) analyze

format: ## Check formatting (CI-safe)
	$(DART) format --set-exit-if-changed lib test

fix: ## Apply formatting and automated fixes
	$(DART) format lib test
	$(DART) fix --apply

run-dev: ## Run the dev flavor
	$(FLUTTER) run --flavor dev -t lib/main_dev.dart

clean: ## Clean build artifacts
	$(FLUTTER) clean
	$(FLUTTER) pub get
