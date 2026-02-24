# =============================================================================
# bonfire Makefile
# =============================================================================

SHELL := bash
.DEFAULT_GOAL := help

REPO_DIR := $(shell pwd)

# Colors
BOLD  := \033[1m
RESET := \033[0m
BLUE  := \033[34m
GREEN := \033[32m

##@ Setup

.PHONY: install
install: ## Run full bootstrap (with confirmation prompt)
	@bash bootstrap.sh

.PHONY: install-yes
install-yes: ## Run full bootstrap without prompts
	@bash bootstrap.sh --yes

.PHONY: dotfiles
dotfiles: ## Stow dotfiles only
	@bash bootstrap.sh --only dotfiles

.PHONY: mise
mise: ## Install/update mise tools only
	@bash bootstrap.sh --only mise

##@ Dotfile Management

.PHONY: sync
sync: ## Pull latest, re-stow dotfiles, update mise tools
	@bin/dotup

.PHONY: sync-all
sync-all: ## Full sync: pull + dotfiles + all packages + mise prune
	@bin/dotsync

.PHONY: audit
audit: ## Show drift between config and installed packages
	@bin/pkgaudit

.PHONY: check
check: ## Show dotfile symlink drift
	@bin/dotcheck

.PHONY: add
add: ## Add a file to a stow package (usage: make add PKG=zsh FILE=~/.zshrc)
ifndef PKG
	$(error PKG is required. Usage: make add PKG=<package> FILE=<filepath>)
endif
ifndef FILE
	$(error FILE is required. Usage: make add PKG=<package> FILE=<filepath>)
endif
	@bin/dotadd $(PKG) $(FILE)

##@ Testing

.PHONY: test
test: ## Run all verification checks
	@bash scripts/12-verify.sh

.PHONY: test-commands
test-commands: ## Test that required commands are available
	@bash tests/test-commands.sh

.PHONY: test-dotfiles
test-dotfiles: ## Test dotfile symlinks
	@bash tests/test-dotfiles.sh

.PHONY: test-services
test-services: ## Test running services (SSH, Docker)
	@bash tests/test-services.sh

##@ Utilities

.PHONY: list
list: ## List all available setup scripts
	@bash bootstrap.sh --list

.PHONY: log
log: ## Show the last 50 lines of the setup log
	@if [ -f setup.log ]; then tail -50 setup.log; else echo "No setup.log found"; fi

.PHONY: clean-log
clean-log: ## Remove the setup log
	@rm -f setup.log && echo "setup.log removed"

.PHONY: shellcheck
shellcheck: ## Run shellcheck on all scripts
	@if command -v shellcheck &>/dev/null; then \
		shellcheck scripts/_lib.sh scripts/[0-9]*.sh bootstrap.sh bin/*; \
		echo "shellcheck passed"; \
	else \
		echo "shellcheck not installed — install with: apt install shellcheck"; \
	fi

##@ Help

.PHONY: help
help: ## Show this help message
	@printf "\n${BOLD}bonfire${RESET} — Dev environment bootstrap\n\n"
	@awk 'BEGIN {FS = ":.*##"; printf ""} \
		/^[a-zA-Z_0-9-]+:.*?##/ { printf "  ${BLUE}%-20s${RESET} %s\n", $$1, $$2 } \
		/^##@/ { printf "\n${BOLD}%s${RESET}\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo ""
