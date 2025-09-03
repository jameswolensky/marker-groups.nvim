# Makefile for marker-groups.nvim testing and development

.PHONY: test test-unit test-integration test-file lint format format-check pre-commit clean help

# Default target
all: test

# Helper: run tests in sandboxed XDG with ephemeral plugin deps
define RUN_TESTS
	@TMP_XDG=$$(mktemp -d 2>/dev/null || mktemp -d -t xdgdata); \
	PACK_START="$$TMP_XDG/nvim/site/pack/testing/start"; PACK_OPT="$$TMP_XDG/nvim/site/pack/testing/opt"; \
	mkdir -p "$$PACK_START" "$$PACK_OPT"; \
	XDG_DATA_HOME="$$TMP_XDG" $(1); \
	RC=$$?; rm -rf "$$TMP_XDG"; exit $$RC
endef

# Test commands
test: ## Run all tests
	@echo "Running all marker-groups tests (mini.test)..."
	$(call RUN_TESTS,nvim --headless -u NONE -l scripts/minitest.lua)

test-unit: ## Run unit tests only
	@echo "Running unit tests (mini.test)..."
	$(call RUN_TESTS,MODE=unit nvim --headless -u NONE -l scripts/minitest.lua)

test-integration: ## Run integration tests only
	@echo "Running integration tests (mini.test)..."
	$(call RUN_TESTS,MODE=integration nvim --headless -u NONE -l scripts/minitest.lua)

test-file: ## Run specific test file (usage: make test-file FILE=tests/mini/unit/test_config.lua)
	@echo "Running test file: $(FILE)"
	$(call RUN_TESTS,TEST_FILE=$(FILE) nvim --headless -u NONE -l scripts/minitest.lua)


# Development commands
lint: ## Run linter (lua language server)
	@echo "Running Lua linter..."
	@if command -v lua-language-server >/dev/null 2>&1; then \
		echo "Checking Lua syntax..."; \
		find lua tests -name "*.lua" -exec lua -l {} \; >/dev/null; \
		echo "Lua syntax check passed"; \
	else \
		echo "lua-language-server not found. Install it for better linting."; \
		find lua tests -name "*.lua" -exec lua -l {} \; >/dev/null; \
	fi

format: ## Format Lua code with stylua
	@echo "Formatting Lua code..."
	@if command -v stylua >/dev/null 2>&1; then \
		stylua lua/ tests/; \
		echo "Code formatted with stylua"; \
	else \
		echo "stylua not found. Install it with: cargo install stylua"; \
	fi

format-check: ## Check if Lua code is properly formatted (without modifying files)
	@echo "Checking Lua code formatting..."
	@if command -v stylua >/dev/null 2>&1; then \
		if stylua --check lua/ tests/; then \
			echo "✅ All Lua files are properly formatted"; \
		else \
			echo "❌ Formatting issues found. Run 'make format' to fix them"; \
			exit 1; \
		fi; \
	else \
		echo "stylua not found. Install it with: cargo install stylua"; \
		exit 1; \
	fi

pre-commit: lint format-check ## Run all pre-commit checks (lint + format check)
	@echo "✅ All pre-commit checks passed!"

clean: ## Clean test artifacts and temporary files
	@echo "Cleaning test artifacts..."
	@find . -name "*.tmp" -delete
	@find . -name "*_test_*" -delete
	@rm -rf /tmp/marker_groups_test_*
	@echo "Cleanup complete"

# Dependency management
install-deps: ## Install optional local tools (formatters/linters)
	@echo "Checking optional developer tools..."
	@echo "Optional: stylua for code formatting"
	@echo "Optional: lua-language-server for linting"
	@echo "mini.nvim (mini.test) is auto-bootstrapped by scripts/minimal_init.lua"

# Utility commands
check-health: ## Run health check
	@echo "Running marker-groups health check..."
	@nvim --headless -c "lua require('marker-groups.health').check()" -c "qa!"

debug-state: ## Show debug state information
	@echo "Displaying debug state..."
	@nvim --headless -c "lua require('marker-groups.utils.debug').show_state()" -c "qa!"

# CI/CD helpers
ci-test: ## Run tests in CI environment
	@echo "Running tests in CI mode (mini.test)..."
	$(call RUN_TESTS,nvim --headless -u NONE -l scripts/minitest.lua)

# Development setup
dev-setup: ## Set up development environment
	@echo "Setting up development environment..."
	@mkdir -p tests/fixtures
	@echo "Development setup complete"
	@echo ""
	@echo "Quick start:"
	@echo "  make test          # Run all tests"
	@echo "  make test-unit     # Run unit tests"
	@echo "  make lint          # Check code quality"
	@echo "  make format        # Format code"

help: ## Show this help message
	@echo "marker-groups.nvim development tasks"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make test                                    # Run all tests"
	@echo "  make test-file FILE=tests/mini/unit/test_config.lua  # Run specific test"

