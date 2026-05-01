# Local checks before pushing (CI-style).
.PHONY: prepush help format-check compile-strict test credo dialyzer codesign-setup-test codesign-setup-validate

# Desktop app (Tauri + ElixirKit).
.PHONY: app-dev app-build app-clean help-app-version app-updater-keys app-updater-keys-force

# Bump CalVer in mix.exs (+ Tauri manifests), commit, tag vYY.M.S, and push.
.PHONY: bump release git-tag git-push-tags retag-latest

.DEFAULT_GOAL := help

help:
	@echo "Checks"
	@echo "  make prepush          format, compile --warnings-as-errors, test, credo, dialyzer"
	@echo "  make codesign-setup-validate  verify .p12 + password (openssl only; no keychain)"
	@echo "  make codesign-setup-test      full keychain setup like CI (see .env.codesign.local.example)"
	@echo "  make format-check"
	@echo "  make compile-strict"
	@echo "  make test"
	@echo "  make credo"
	@echo "  make dialyzer"
	@echo ""
	@echo "Version (CalVer YY.M.S in mix.exs, src-tauri/Cargo.toml, Cargo.lock, tauri.conf.json)"
	@echo "  make bump             # bump CalVer only (same month -> seq+1; new month/year -> YY.M.1)"
	@echo "  make git-tag          # annotated tag from mix.exs (vYY.M.S), local only"
	@echo "  make git-push-tags    # git push + push tags"
	@echo "  make release          # bump + commit version files + tag + push (new release only)"
	@echo "  make retag-latest     # move newest v* tag to HEAD + refresh GH release (CI retry; no bump)"
	@echo ""
	@echo "Desktop app (needs Rust + cargo-tauri / npx @tauri-apps/cli)"
	@echo "  make app-dev                  # tauri dev (Phoenix started by app; no CLI wait on :4000)"
	@echo "  make app-build                # prod Elixir release + tauri bundle"
	@echo "  make app-clean                # rm src-tauri/target"
	@echo "  make app-updater-keys         # tauri signer generate → src-tauri/updater.{pub,key} (see README)"
	@echo "  make app-updater-keys-force   # overwrite existing updater.key"

prepush: format-check compile-strict test credo dialyzer

format-check:
	mix format --check-formatted

compile-strict:
	mix compile --warnings-as-errors

test:
	MIX_ENV=test mix test

credo:
	mix credo

dialyzer:
	mix dialyzer

codesign-setup-validate:
	bash scripts/test_macos_codesign_setup.sh --validate-only

codesign-setup-test:
	bash scripts/test_macos_codesign_setup.sh

bump:
	elixir scripts/bump_calver.exs

release: bump
	@$(MAKE) _release_commit_tag_push

_release_commit_tag_push:
	@version=$$(sed -n 's/^[[:space:]]*@version "\([^"]*\)".*/\1/p' mix.exs); \
	git add mix.exs src-tauri/tauri.conf.json src-tauri/Cargo.toml src-tauri/Cargo.lock && \
	git commit -m "Bump version to $$version" && \
	git tag -a "v$$version" -m "Version $$version" && \
	git push && git push --tags

git-tag:
	@version=$$(sed -n 's/^[[:space:]]*@version "\([^"]*\)".*/\1/p' mix.exs); \
	git tag -a "v$$version" -m "Version $$version"

git-push-tags:
	git push
	git push --tags

# Most recently created tag matching v* (see git-for-each-ref creatordate).
retag-latest:
	@command -v gh >/dev/null || { echo "gh (GitHub CLI) is required." >&2; exit 1; }; \
	tag=$$(git for-each-ref --sort=-creatordate --format '%(refname:short)' 'refs/tags/v*' | head -1); \
	if [ -z "$$tag" ]; then echo 'No tags matching v* found.' >&2; exit 1; fi; \
	echo "Retagging $$tag at $$(git rev-parse --short HEAD)..."; \
	git tag -d "$$tag" 2>/dev/null || true; \
	if ! gh release delete "$$tag" --yes --cleanup-tag 2>/dev/null; then \
	  git push origin ":refs/tags/$$tag" || true; \
	fi; \
	ver=$${tag#v}; \
	git tag -a "$$tag" -m "Version $$ver"; \
	git push origin "$$tag"

# --- Desktop (Tauri) ---

help-app-version:
	@sed -n 's/^[[:space:]]*@version "\([^"]*\)".*/\1/p' mix.exs | head -1

# Phoenix is spawned inside the Rust binary (elixirkit::mix), not by beforeDevCommand — so the CLI
# must not block on build.devUrl, or `tauri dev` waits forever for a server that does not exist yet.
app-dev:
	cd src-tauri && npx --yes @tauri-apps/cli@2 dev --no-dev-server-wait

app-build:
	bash scripts/tauri_prebuild.sh
	cd src-tauri && npx --yes @tauri-apps/cli@2 build

app-clean:
	rm -rf src-tauri/target

app-updater-keys:
	bash scripts/tauri_updater_keys.sh

app-updater-keys-force:
	FORCE=1 bash scripts/tauri_updater_keys.sh
