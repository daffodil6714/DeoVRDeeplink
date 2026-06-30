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
CURRENT_VERSION := $(shell powershell -Command "(Select-Xml -Path '$(PROJECT_FILE)' -XPath '//AssemblyVersion').Node.InnerText")
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

# ZIP and checksum generation
$(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip: build
	@echo "Creating release package..."
	@powershell -Command " \
		$$path = '$(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip'; \
		if (Test-Path $$path) { Remove-Item $$path }; \
		Compress-Archive -Path '$(BUILD_DIR)/*' -DestinationPath $$path -Force; \
		Write-Host '✓ Package created: $$path'"

get-checksum: $(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip
	@powershell -Command " \
		$$file = '$(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip'; \
		$$hash = (Get-FileHash -Path $$file -Algorithm MD5).Hash; \
		Write-Host $$hash"

# Manifest update
update-manifest: get-checksum
	@echo "Updating manifest.json with version $(CURRENT_VERSION)..."
	@powershell -Command " \
		$$manifest = Get-Content '$(MANIFEST_FILE)' | ConvertFrom-Json; \
		$$hash = ((Get-FileHash -Path '$(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip' -Algorithm MD5).Hash); \
		$$newVersion = @{ \
			version = '$(CURRENT_VERSION)'; \
			changelog = 'Release $(CURRENT_VERSION)'; \
			targetAbi = '10.11.6.0'; \
			sourceUrl = 'https://github.com/$(GITHUB_REPO)/releases/download/v$(CURRENT_VERSION)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip'; \
			checksum = $$hash; \
			timestamp = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ') \
		}; \
		$$manifest[0].versions += $$newVersion; \
		$$manifest | ConvertTo-Json -Depth 10 | Set-Content '$(MANIFEST_FILE)'; \
		Write-Host '✓ Manifest updated'"

# Git tagging
tag:
	@echo "Creating git tag v$(CURRENT_VERSION)..."
	git tag -a v$(CURRENT_VERSION) -m "Release $(CURRENT_VERSION)" || echo "Tag already exists"
	@echo "✓ Tag created/verified"

# GitHub release creation
create-release: $(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip tag
	@echo "Creating GitHub release..."
	@powershell -Command " \
		$$assetPath = '$(BUILD_DIR)/$(PROJECT_NAME)-v$(CURRENT_VERSION).zip'; \
		if (Get-Command gh -ErrorAction SilentlyContinue) { \
			gh release create v$(CURRENT_VERSION) --title 'v$(CURRENT_VERSION)' --notes 'Release $(CURRENT_VERSION)' $$assetPath || echo 'Release already exists'; \
			Write-Host '✓ GitHub release created' \
		} else { \
			Write-Host '⚠ GitHub CLI (gh) not found. Skipping release creation.'; \
			Write-Host '  Upload manually: gh release create v$(CURRENT_VERSION) --title ''v$(CURRENT_VERSION)'' $$assetPath' \
		}"

# Version bumping functions
bump-major:
	@echo "Bumping major version: $(MAJOR).$(MINOR).$(PATCH).$(REVISION) -> $$(( $(MAJOR) + 1 )).0.0.0"
	@powershell -Command " \
		$$newMajor = $$(( $(MAJOR) + 1 )); \
		$$newVersion = '$$newMajor.0.0.0'; \
		$$xml = [xml](Get-Content '$(PROJECT_FILE)'); \
		$$xml.SelectSingleNode('//AssemblyVersion').InnerText = $$newVersion; \
		$$xml.Save('$(PROJECT_FILE)'); \
		Write-Host '✓ Version updated to $$newVersion'"

bump-minor:
	@echo "Bumping minor version: $(MAJOR).$(MINOR).$(PATCH).$(REVISION) -> $(MAJOR).$$(( $(MINOR) + 1 )).0.0"
	@powershell -Command " \
		$$newMinor = $$(( $(MINOR) + 1 )); \
		$$newVersion = '$(MAJOR).$$newMinor.0.0'; \
		$$xml = [xml](Get-Content '$(PROJECT_FILE)'); \
		$$xml.SelectSingleNode('//AssemblyVersion').InnerText = $$newVersion; \
		$$xml.Save('$(PROJECT_FILE)'); \
		Write-Host '✓ Version updated to $$newVersion'"

bump-patch:
	@echo "Bumping patch version: $(MAJOR).$(MINOR).$(PATCH).$(REVISION) -> $(MAJOR).$(MINOR).$$(( $(PATCH) + 1 )).0"
	@powershell -Command " \
		$$newPatch = $$(( $(PATCH) + 1 )); \
		$$newVersion = '$(MAJOR).$(MINOR).$$newPatch.0'; \
		$$xml = [xml](Get-Content '$(PROJECT_FILE)'); \
		$$xml.SelectSingleNode('//AssemblyVersion').InnerText = $$newVersion; \
		$$xml.Save('$(PROJECT_FILE)'); \
		Write-Host '✓ Version updated to $$newVersion'"

bump-revision:
	@echo "Bumping revision version: $(MAJOR).$(MINOR).$(PATCH).$(REVISION) -> $(MAJOR).$(MINOR).$(PATCH).$$(( $(REVISION) + 1 ))"
	@powershell -Command " \
		$$newRevision = $$(( $(REVISION) + 1 )); \
		$$newVersion = '$(MAJOR).$(MINOR).$(PATCH).$$newRevision'; \
		$$xml = [xml](Get-Content '$(PROJECT_FILE)'); \
		$$xml.SelectSingleNode('//AssemblyVersion').InnerText = $$newVersion; \
		$$xml.Save('$(PROJECT_FILE)'); \
		Write-Host '✓ Version updated to $$newVersion'"

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
