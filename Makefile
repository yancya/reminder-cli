.PHONY: build release install clean help

# Default target
.DEFAULT_GOAL := help

# Build directory
BUILD_DIR = .build
PRODUCT_NAME = reminder-cli
INSTALL_PATH = $(HOME)/bin

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build debug version
	swift build

release: ## Build release version
	swift build -c release

install: release ## Build and symlink to ~/bin
	@echo "Installing $(PRODUCT_NAME) to $(INSTALL_PATH)..."
	@mkdir -p $(INSTALL_PATH)
	@rm -f $(INSTALL_PATH)/$(PRODUCT_NAME)
	@ln -s $(PWD)/$(BUILD_DIR)/release/$(PRODUCT_NAME) $(INSTALL_PATH)/$(PRODUCT_NAME)
	@echo "✅ Symlinked $(INSTALL_PATH)/$(PRODUCT_NAME) -> $(PWD)/$(BUILD_DIR)/release/$(PRODUCT_NAME)"

uninstall: ## Remove installed binary
	@echo "Removing $(INSTALL_PATH)/$(PRODUCT_NAME)..."
	@rm -f $(INSTALL_PATH)/$(PRODUCT_NAME)
	@echo "✅ Uninstalled"

clean: ## Remove build artifacts
	swift package clean
	rm -rf $(BUILD_DIR)

run: build ## Build and run (debug)
	$(BUILD_DIR)/debug/$(PRODUCT_NAME)

version: ## Show version
	@swift --version
	@echo "Package info:"
	@swift package describe

.PHONY: format
format: ## Format Swift code (requires swift-format)
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format -i -r Sources/; \
		echo "✅ Code formatted"; \
	else \
		echo "⚠️  swift-format not installed. Run: brew install swift-format"; \
	fi
