.PHONY: test precommit help all
.DEFAULT_GOAL := help

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Project paths
TESTS_DIR := ./tests

## Install formatting tools
install-tools:
	@echo -e "$(BLUE)=== Installing Formatting Tools ===$(NC)"
	@echo -e "$(YELLOW)Installing uv...$(NC)"
	@if command -v uv >/dev/null 2>&1; then \
		echo -e "$(GREEN)✓ uv already installed$(NC)"; \
	else \
		curl -LsSf https://astral.sh/uv/install.sh | sh; \
		echo -e "$(GREEN)✓ uv installed$(NC)"; \
	fi
	@echo -e "$(YELLOW)Installing yamlfmt...$(NC)"
	@if command -v go >/dev/null 2>&1; then \
		go install github.com/google/yamlfmt/cmd/yamlfmt@latest; \
		echo -e "$(GREEN)✓ yamlfmt installed$(NC)"; \
	else \
		echo -e "$(RED)✗ Go not found. Please install Go first$(NC)"; \
	fi
	@echo -e "$(YELLOW)Installing shfmt...$(NC)"
	@if command -v go >/dev/null 2>&1; then \
		go install mvdan.cc/sh/v3/cmd/shfmt@latest; \
		echo -e "$(GREEN)✓ shfmt installed$(NC)"; \
	else \
		echo -e "$(RED)✗ Go not found. Please install Go first$(NC)"; \
	fi
	@echo -e "$(YELLOW)Installing prettier...$(NC)"
	@if command -v npm >/dev/null 2>&1; then \
		npm install -g prettier; \
		echo -e "$(GREEN)✓ prettier installed$(NC)"; \
	else \
		echo -e "$(RED)✗ npm not found. Please install Node.js/npm first$(NC)"; \
	fi
	@echo -e "$(GREEN)All formatting tools installed! 🛠️$(NC)"

## Format all files (yaml, js, sh, md)
fmt:
	@echo -e "$(BLUE)=== Formatting Files ===$(NC)"
	@echo -e "$(YELLOW)Formatting YAML files...$(NC)"
	@if command -v yamlfmt >/dev/null 2>&1; then \
		find . -name "*.yaml" -o -name "*.yml" | grep -v node_modules | xargs uv run ./scripts/fmt-cloud-init-yaml.py; \
		echo -e "$(GREEN)✓ YAML files formatted$(NC)"; \
	else \
		echo -e "$(RED)✗ yamlfmt not found. Install with: go install github.com/google/yamlfmt/cmd/yamlfmt@latest$(NC)"; \
	fi
	@echo -e "$(YELLOW)Formatting shell scripts...$(NC)"
	@if command -v shfmt >/dev/null 2>&1; then \
		find . -name "*.sh" | grep -v node_modules | xargs shfmt -w -i 2; \
		echo -e "$(GREEN)✓ Shell scripts formatted$(NC)"; \
	else \
		echo -e "$(RED)✗ shfmt not found. Install with: go install mvdan.cc/sh/v3/cmd/shfmt@latest$(NC)"; \
	fi
	@echo -e "$(YELLOW)Formatting JavaScript, JSON, and Markdown files...$(NC)"
	@if command -v prettier >/dev/null 2>&1; then \
		prettier --write .; \
		echo -e "$(GREEN)✓ JavaScript, JSON, and Markdown files formatted$(NC)"; \
	else \
		echo -e "$(RED)✗ prettier not found. Install with: npm install -g prettier$(NC)"; \
	fi
	@echo -e "$(GREEN)All files formatted! 🎨$(NC)"

test:
	@$(TESTS_DIR)/run-all-tests.sh