# Local checks before pushing (CI-style).
.PHONY: prepush help format-check compile-strict test credo dialyzer codesign-setup-test codesign-setup-validate

# Bump CalVer in mix.exs, commit, tag vY.M.S, and push (branch + tags).
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
	@echo "Version (CalVer in mix.exs: @version \"Y.M.S\", no leading zeros)"
	@echo "  make bump             # vs today: same month -> seq+1; new month/year -> Y.M.1"
	@echo "  make git-tag          # annotated tag from mix.exs (vY.M.S)"
	@echo "  make git-push-tags    # git push + push tags"
	@echo "  make release          # bump + commit + tag + push"
	@echo "  make retag-latest     # drop newest v* tag + GH release, recreate at HEAD, push"

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
	git add mix.exs && \
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
