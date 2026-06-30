.PHONY: help build clean rebuild tag major-release minor-release patch-release revision-release

# Default target
.DEFAULT_GOAL := help

# Configuration
PROJECT_NAME := DeoVRDeeplink
SOLUTION_FILE := $(PROJECT_NAME).sln
PROJECT_FILE := $(PROJECT_NAME)/$(PROJECT_NAME).csproj
BUILD_CONFIG := Release
FRAMEWORK := net9.0
BUILD_DIR := $(PROJECT_NAME)/bin/$(BUILD_CONFIG)/$(FRAMEWORK)
MANIFEST_FILE := manifest.json

# Get current version from .csproj
CURRENT_VERSION := $(shell grep -oP '(?<=<AssemblyVersion>)[^<]+' $(PROJECT_FILE))
VERSION_PARTS := $(subst ., ,$(CURRENT_VERSION))
MAJOR := $(word 1,$(VERSION_PARTS))
MINOR := $(word 2,$(VERSION_PARTS))
PATCH := $(word 3,$(VERSION_PARTS))
REVISION := $(word 4,$(VERSION_PARTS))

# GitHub settings
REPO_OWNER := daffodil6714
REPO_NAME := DeoVRDeeplink
GITHUB_REPO := $(REPO_OWNER)/$(REPO_NAME)

help:
	@echo "$(PROJECT_NAME) Release Management"
	@echo ""
	@echo "Current version: $(CURRENT_VERSION)"
	@echo ""
	@echo "Build targets:"
	@echo "  make build              - Build the solution (Release)"
	@echo "  make clean              - Clean build artifacts"
	@echo "  make rebuild            - Clean and rebuild"
	@echo ""
	@echo "Release targets:"
	@echo "  make major-release      - Bump major version (X.0.0.0) and release"
	@echo "  make minor-release      - Bump minor version (X.Y.0.0) and release"
	@echo "  make patch-release      - Bump patch version (X.Y.Z.0) and release"
	@echo "  make revision-release   - Bump revision version (X.Y.Z.W) and release"
	@echo ""
	@echo "Low-level targets:"
	@echo "  make tag                - Create git tag for current version"
	@echo "  make create-release     - Create GitHub release with current version"

# Build targets
build:
	@echo "Building $(PROJECT_NAME) ($(CURRENT_VERSION))..."
	dotnet build -c $(BUILD_CONFIG) $(SOLUTION_FILE)
	@echo "✓ Build complete"

clean:
	@echo "Cleaning build artifacts..."
	dotnet clean -c $(BUILD_CONFIG) $(SOLUTION_FILE)
	@echo "✓ Clean complete"

rebuild: clean build

# ZIP and checksum generation (PowerShell only for this)
$(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip: build
	@echo "Creating release package..."
	@powershell -Command "Compress-Archive -Path '$(BUILD_DIR)/*' -DestinationPath '$(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip' -Force; Write-Host '✓ Package created'"

get-checksum: $(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip
	@powershell -Command "$$hash = (Get-FileHash -Path '$(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip' -Algorithm MD5).Hash; Write-Host $$hash"

# Manifest update
update-manifest: get-checksum
	@echo "Updating manifest.json with version $(CURRENT_VERSION)..."
	@bash -c ' \
		CHECKSUM=$$(powershell -Command "(Get-FileHash -Path '"'"'$(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip'"'"' -Algorithm MD5).Hash"); \
		TIMESTAMP=$$(date -u +"%Y-%m-%dT%H:%M:%SZ"); \
		node -e " \
			const fs = require('"'"'fs'"'"'); \
			const manifest = JSON.parse(fs.readFileSync('"'"'$(MANIFEST_FILE)'"'"')); \
			const newVersion = { \
				version: '"'"'$(CURRENT_VERSION)'"'"', \
				changelog: '"'"'Release $(CURRENT_VERSION)'"'"', \
				targetAbi: '"'"'10.11.6.0'"'"', \
				sourceUrl: '"'"'https://github.com/$(GITHUB_REPO)/releases/download/v$(CURRENT_VERSION)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip'"'"', \
				checksum: '"'"'$$CHECKSUM'"'"', \
				timestamp: '"'"'$$TIMESTAMP'"'"' \
			}; \
			manifest[0].versions.push(newVersion); \
			fs.writeFileSync('"'"'$(MANIFEST_FILE)'"'"', JSON.stringify(manifest, null, 4)); \
			console.log('"'"'✓ Manifest updated'"'"'); \
		" \
	'

# Git tagging
tag:
	@echo "Creating git tag v$(CURRENT_VERSION)..."
	@git tag -a v$(CURRENT_VERSION) -m "Release $(CURRENT_VERSION)" 2>/dev/null || echo "Tag already exists"
	@echo "✓ Tag created/verified"

# GitHub release creation
create-release: $(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip tag
	@echo "Creating GitHub release..."
	@if command -v gh &> /dev/null; then \
		gh release create v$(CURRENT_VERSION) --title "v$(CURRENT_VERSION)" --notes "Release $(CURRENT_VERSION)" "$(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip" 2>/dev/null || echo "Release already exists"; \
		echo "✓ GitHub release created"; \
	else \
		echo "⚠ GitHub CLI (gh) not found. Skipping release creation."; \
		echo "  Upload manually: gh release create v$(CURRENT_VERSION) --title 'v$(CURRENT_VERSION)' '$(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip'"; \
	fi

# Version bumping functions (Bash)
bump-major:
	@echo "Bumping major version: $(MAJOR).$(MINOR).$(PATCH).$(REVISION) -> $$(($(MAJOR) + 1)).0.0.0"
	@bash -c ' \
		NEW_VERSION="$$(($(MAJOR) + 1)).0.0.0"; \
		sed -i.bak "s/<AssemblyVersion>[^<]*<\/AssemblyVersion>/<AssemblyVersion>$$NEW_VERSION<\/AssemblyVersion>/" "$(PROJECT_FILE)"; \
		rm -f "$(PROJECT_FILE).bak"; \
		echo "✓ Version updated to $$NEW_VERSION"'

bump-minor:
	@echo "Bumping minor version: $(MAJOR).$(MINOR).$(PATCH).$(REVISION) -> $(MAJOR).$$(($(MINOR) + 1)).0.0"
	@bash -c ' \
		NEW_VERSION="$(MAJOR).$$(($(MINOR) + 1)).0.0"; \
		sed -i.bak "s/<AssemblyVersion>[^<]*<\/AssemblyVersion>/<AssemblyVersion>$$NEW_VERSION<\/AssemblyVersion>/" "$(PROJECT_FILE)"; \
		rm -f "$(PROJECT_FILE).bak"; \
		echo "✓ Version updated to $$NEW_VERSION"'

bump-patch:
	@echo "Bumping patch version: $(MAJOR).$(MINOR).$(PATCH).$(REVISION) -> $(MAJOR).$(MINOR).$$(($(PATCH) + 1)).0"
	@bash -c ' \
		NEW_VERSION="$(MAJOR).$(MINOR).$$(($(PATCH) + 1)).0"; \
		sed -i.bak "s/<AssemblyVersion>[^<]*<\/AssemblyVersion>/<AssemblyVersion>$$NEW_VERSION<\/AssemblyVersion>/" "$(PROJECT_FILE)"; \
		rm -f "$(PROJECT_FILE).bak"; \
		echo "✓ Version updated to $$NEW_VERSION"'

bump-revision:
	@echo "Bumping revision version: $(MAJOR).$(MINOR).$(PATCH).$(REVISION) -> $(MAJOR).$(MINOR).$(PATCH).$$(($(REVISION) + 1))"
	@bash -c ' \
		NEW_VERSION="$(MAJOR).$(MINOR).$(PATCH).$$(($(REVISION) + 1))"; \
		sed -i.bak "s/<AssemblyVersion>[^<]*<\/AssemblyVersion>/<AssemblyVersion>$$NEW_VERSION<\/AssemblyVersion>/" "$(PROJECT_FILE)"; \
		rm -f "$(PROJECT_FILE).bak"; \
		echo "✓ Version updated to $$NEW_VERSION"'

# Full release workflows
major-release: bump-major rebuild $(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip update-manifest
	@git add $(PROJECT_FILE) $(MANIFEST_FILE)
	@git commit -m "chore: bump major version to $(CURRENT_VERSION)"
	@$(MAKE) create-release
	@echo "✓ Major release complete: v$(CURRENT_VERSION)"

minor-release: bump-minor rebuild $(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip update-manifest
	@git add $(PROJECT_FILE) $(MANIFEST_FILE)
	@git commit -m "chore: bump minor version to $(CURRENT_VERSION)"
	@$(MAKE) create-release
	@echo "✓ Minor release complete: v$(CURRENT_VERSION)"

patch-release: bump-patch rebuild $(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip update-manifest
	@git add $(PROJECT_FILE) $(MANIFEST_FILE)
	@git commit -m "chore: bump patch version to $(CURRENT_VERSION)"
	@$(MAKE) create-release
	@echo "✓ Patch release complete: v$(CURRENT_VERSION)"

revision-release: bump-revision rebuild $(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip update-manifest
	@git add $(PROJECT_FILE) $(MANIFEST_FILE)
	@git commit -m "chore: bump revision version to $(CURRENT_VERSION)"
	@$(MAKE) create-release
	@echo "✓ Revision release complete: v$(CURRENT_VERSION)"
