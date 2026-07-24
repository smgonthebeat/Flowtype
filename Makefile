APP_NAME := Flowtype
BUILD_DIR := .build/release
APP_DIR := .build/$(APP_NAME).app
DIST_DIR := .build/dist
DMG_STAGING_DIR := .build/dmg-staging
DMG_PATH := $(DIST_DIR)/$(APP_NAME).dmg
UV_BINARY ?= $(shell command -v uv 2>/dev/null)
UV_REALPATH := $(shell if [ -n "$(UV_BINARY)" ]; then python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$(UV_BINARY)"; fi)
HELPER_VERSION ?= $(shell date -u +%Y.%m.%d)
SOURCE_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || printf unknown)
CODESIGN_IDENTITY ?= -

-include local.mk

.PHONY: build open run install dmg clean test verify-package

build:
	swift build -c release
	@if [ -z "$(UV_REALPATH)" ]; then \
		echo "uv is required to build a standalone Flowtype bundle. Install uv or set UV_BINARY=/path/to/uv."; \
		exit 1; \
	fi
	python3 script/app_bundle.py assemble \
		--app "$(APP_DIR)" \
		--app-binary "$(BUILD_DIR)/$(APP_NAME)" \
		--uv "$(UV_REALPATH)" \
		--helper-version "$(HELPER_VERSION)" \
		--source-commit "$(SOURCE_COMMIT)"
	codesign --force --deep --sign "$(CODESIGN_IDENTITY)" "$(APP_DIR)"

open:
	open "$(APP_DIR)"

run: build open

install: build
	@if [ -e "/Applications/$(APP_NAME).app" ]; then \
		archive_root="$(CURDIR)/.trash"; \
		mkdir -p "$$archive_root"; \
		archive_path="$$archive_root/$$(date +%F)_$(APP_NAME).app"; \
		counter=1; \
		while [ -e "$$archive_path" ]; do \
			archive_path="$$archive_root/$$(date +%F)_$(APP_NAME)_$$counter.app"; \
			counter=$$((counter + 1)); \
		done; \
		mv "/Applications/$(APP_NAME).app" "$$archive_path"; \
		echo "Archived previous app at $$archive_path"; \
	fi
	ditto "$(APP_DIR)" "/Applications/$(APP_NAME).app"

dmg: build
	./script/create_dmg.sh "$(APP_DIR)" "$(DMG_PATH)"
	./script/verify_package.sh "$(APP_DIR)" "$(DMG_PATH)"

verify-package:
	./script/verify_package.sh "$(APP_DIR)" "$(DMG_PATH)"

test:
	swift test

clean:
	rm -rf .build
