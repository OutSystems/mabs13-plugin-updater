# Makefile for mabs13-plugin-update - Cordova plugin.xml to Swift Package Manager converter

# Variables
BINARY_NAME = mabs13-plugin-update
BUILD_DIR = .build
INSTALL_DIR = /usr/local/bin

# Default target
.PHONY: all
all: build

# Build the project
.PHONY: build
build:
	@echo "Building $(BINARY_NAME)..."
	swift build -c release

# Run tests
.PHONY: test
test:
	@echo "Running tests..."
	swift test

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf $(BUILD_DIR)

# Install the binary
.PHONY: install
install: build
	@echo "Installing $(BINARY_NAME) to $(INSTALL_DIR)..."
	@echo "This requires sudo privileges..."
	sudo mkdir -p $(INSTALL_DIR)
	sudo cp $(BUILD_DIR)/release/$(BINARY_NAME) $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "$(BINARY_NAME) installed successfully!"

# Uninstall the binary
.PHONY: uninstall
uninstall:
	@echo "Uninstalling $(BINARY_NAME)..."
	@echo "This requires sudo privileges..."
	sudo rm -f $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "$(BINARY_NAME) uninstalled successfully."

# Lint the code
.PHONY: lint
lint:
	@if swiftlint --version >/dev/null 2>&1; then \
		echo "Running SwiftLint..."; \
		swiftlint; \
	else \
		echo "SwiftLint not found. Install with: brew install swiftlint"; \
	fi

# Open project in Xcode
.PHONY: xcode
xcode:
	@echo "Opening project in Xcode..."
	@if command -v xed >/dev/null 2>&1; then \
		xed .; \
	else \
		echo "Xcode command line tools not found."; \
	fi

# Resolve dependencies
.PHONY: resolve
resolve:
	@echo "Resolving package dependencies..."
	swift package resolve

# Update dependencies
.PHONY: update
update:
	@echo "Updating package dependencies..."
	swift package update

# Format code
.PHONY: format
format:
	@echo "Formatting Swift code..."
	swiftformat Sources Tests

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  build     - Build the project"
	@echo "  test      - Run tests"
	@echo "  clean     - Clean build artifacts"
	@echo "  install   - Install binary to $(INSTALL_DIR)"
	@echo "  uninstall - Remove binary"
	@echo "  lint      - Run SwiftLint"
	@echo "  format    - Format code"
	@echo "  xcode     - Open project in Xcode"
	@echo "  resolve   - Resolve dependencies"
	@echo "  update    - Update dependencies"
	@echo "  help      - Show this help"
