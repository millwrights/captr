# Captr — build a macOS .app bundle with clang (no Xcode project required).

APP        := Captr
VERSION    := 0.2.0
BUNDLE     := build/$(APP).app
CONTENTS   := $(BUNDLE)/Contents
BINDIR     := $(CONTENTS)/MacOS
RESDIR     := $(CONTENTS)/Resources
BIN        := $(BINDIR)/$(APP)

SRC        := $(wildcard src/*.m)
FRAMEWORKS := -framework Cocoa -framework Carbon -framework ServiceManagement \
              -framework ApplicationServices -framework CoreGraphics \
              -framework ScreenCaptureKit -framework Vision \
              -framework AVFoundation -framework CoreMedia \
              -framework CoreImage -framework UniformTypeIdentifiers
CFLAGS     := -fobjc-arc -Wall -Wextra -Wno-unused-parameter -O2 \
              -mmacosx-version-min=13.0 -fmodules

# Code-signing identity, e.g. "Developer ID Application: Your Name (TEAMID)".
# Override on the command line:  make sign SIGN_IDENTITY="Developer ID Application: ..."
# Or persist it once so every build signs the same way (recommended for local
# dev so Screen Recording / Accessibility permission sticks across rebuilds):
#   ./scripts/dev-cert.sh            # create a stable "Millwrights" identity
#   echo "Millwrights" > .signing-identity
SIGN_IDENTITY ?= $(shell cat .signing-identity 2>/dev/null || echo -)

# Release settings.
# GitHub owner/repo for releases (override: make release REPO=you/fork).
REPO       ?= millwrights/captr
TAG        := v$(VERSION)
DIST_ZIP   := build/Captr-$(TAG).zip

.PHONY: all app run clean sign notarize test dist release install uninstall

INSTALL_DIR := /Applications
INSTALLED   := $(INSTALL_DIR)/$(APP).app

TEST_SRC := tests/CPTests.m src/CPCaptureEngine.m src/CPExporter.m src/CPMarkup.m src/CPCanvasView.m

all: app

app: $(BIN)

$(BIN): $(SRC) Resources/Info.plist
	@mkdir -p $(BINDIR) $(RESDIR)
	clang $(CFLAGS) $(FRAMEWORKS) $(SRC) -o $(BIN)
	@cp Resources/Info.plist $(CONTENTS)/Info.plist
	@printf 'APPL????' > $(CONTENTS)/PkgInfo
	@for lproj in Resources/*.lproj; do \
		[ -d "$$lproj" ] && cp -R "$$lproj" "$(RESDIR)/" || true; \
	done
	@codesign --force --timestamp=none --identifier com.millwrights.captr \
		--sign "$(SIGN_IDENTITY)" $(BUNDLE) \
		&& echo "  signed with: $(SIGN_IDENTITY)" \
		|| echo "  ⚠ codesign FAILED for '$(SIGN_IDENTITY)' — Screen Recording permission will NOT persist. Run scripts/dev-cert.sh"
	@echo "✓ Built $(BUNDLE)"

run: app
	@echo "Launching $(APP)…"
	@open $(BUNDLE)

# Build, quit any running copy, install into /Applications, and launch it there.
install: app
	@echo "Quitting any running $(APP)…"
	@pkill -x $(APP) 2>/dev/null || true
	@sleep 1
	@echo "Installing to $(INSTALLED)…"
	@rm -rf "$(INSTALLED)"
	@cp -R $(BUNDLE) "$(INSTALLED)"
	@codesign --verify --strict "$(INSTALLED)" && echo "  signature OK" || echo "  ⚠ signature check failed"
	@echo "Launching $(INSTALLED)…"
	@open "$(INSTALLED)"
	@echo "✓ Installed and launched $(INSTALLED)"

# Remove the installed copy (settings in ~/Library are left intact).
uninstall:
	@pkill -x $(APP) 2>/dev/null || true
	@rm -rf "$(INSTALLED)"
	@echo "✓ Removed $(INSTALLED)"

sign: app
	codesign --force --deep --options runtime \
		--entitlements Resources/captr.entitlements \
		--sign "$(SIGN_IDENTITY)" $(BUNDLE)
	@codesign --verify --verbose $(BUNDLE)

notarize:
	@SIGN_IDENTITY="$(SIGN_IDENTITY)" scripts/sign-and-notarize.sh

# Package the built app into a distributable zip (no upload).
dist: app
	@rm -f "$(DIST_ZIP)"
	/usr/bin/ditto -c -k --keepParent "$(BUNDLE)" "$(DIST_ZIP)"
	@echo "✓ Packaged $(DIST_ZIP)"

# Tag the current commit and publish a GitHub Release with the zip attached.
release: dist
	@command -v gh >/dev/null 2>&1 || { echo "error: GitHub CLI 'gh' not found — 'brew install gh'"; exit 1; }
	@gh auth status >/dev/null 2>&1 || { echo "error: not logged in — run 'gh auth login'"; exit 1; }
	@git remote get-url origin >/dev/null 2>&1 || { echo "error: no 'origin' remote — 'git remote add origin https://github.com/$(REPO).git'"; exit 1; }
	@echo "==> Tagging $(TAG)"
	@git rev-parse -q --verify "refs/tags/$(TAG)" >/dev/null 2>&1 || git tag -a "$(TAG)" -m "Captr $(TAG)"
	@git push origin "$(TAG)"
	@echo "==> Generating release notes"
	@scripts/release-notes.sh "$(TAG)" "$(REPO)" > "build/RELEASE_NOTES-$(TAG).md"
	@echo "==> Publishing GitHub Release $(TAG) on $(REPO)"
	@if gh release view "$(TAG)" --repo "$(REPO)" >/dev/null 2>&1; then \
		echo "  release exists — updating notes and asset"; \
		gh release edit "$(TAG)" --repo "$(REPO)" --notes-file "build/RELEASE_NOTES-$(TAG).md"; \
		gh release upload "$(TAG)" "$(DIST_ZIP)" --repo "$(REPO)" --clobber; \
	else \
		gh release create "$(TAG)" "$(DIST_ZIP)" --repo "$(REPO)" \
			--title "Captr $(TAG)" --notes-file "build/RELEASE_NOTES-$(TAG).md"; \
	fi
	@echo "✓ Released: https://github.com/$(REPO)/releases/tag/$(TAG)"

test:
	@mkdir -p build
	clang $(CFLAGS) -Isrc -framework Cocoa -framework CoreGraphics -framework CoreImage \
		$(TEST_SRC) -o build/cptests
	@./build/cptests

clean:
	rm -rf build
	@echo "✓ Cleaned"
