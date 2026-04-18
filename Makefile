# Local checks before pushing (CI-style).
.PHONY: prepush help format-check compile-strict test credo dialyzer

# Bump CalVer in mix.exs, commit, tag vYYYY.MM.seq, and push (branch + tags).
.PHONY: bump release git-tag git-push-tags

.DEFAULT_GOAL := help

help:
	@echo "Checks"
	@echo "  make prepush          format, compile --warnings-as-errors, test, credo, dialyzer"
	@echo "  make format-check"
	@echo "  make compile-strict"
	@echo "  make test"
	@echo "  make credo"
	@echo "  make dialyzer"
	@echo ""
	@echo "Version (CalVer in mix.exs: @version \"YYYY.MM.seq\")"
	@echo "  make bump             # vs today: same month -> seq+1; new month/year -> YYYY.MM.1"
	@echo "  make git-tag          # annotated tag from mix.exs (vYYYY.MM.seq)"
	@echo "  make git-push-tags    # git push + push tags"
	@echo "  make release          # bump + commit + tag + push"

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
