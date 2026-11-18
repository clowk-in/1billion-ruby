.PHONY: test build tag

test:
	bundle exec rake

# Builds 1billion-X.Y.Z.gem, to check the gemspec. The release workflow
# builds and pushes it.
build:
	gem build 1billion.gemspec

# Release: make tag patch|minor|major. Bumps the version and CHANGELOG.md,
# commits "release: X.Y.Z", tags vX.Y.Z, and asks before the push. With
# make's --dry-run (-n) or DRY=1, it only shows the next version. YES=1
# pushes without asking. See scripts/release.sh.
RELEASE_DRY := $(if $(or $(DRY),$(findstring n,$(filter-out -%,$(firstword $(MAKEFLAGS))))),--dry-run)

ifneq ($(filter tag,$(firstword $(MAKECMDGOALS))),)
MAKEFLAGS += --silent
BUMP := $(word 2,$(MAKECMDGOALS))

ifneq ($(BUMP),)
$(eval $(BUMP): tag ;)
endif
endif

tag:
	+@scripts/release.sh $(or $(BUMP),patch) $(RELEASE_DRY) $(if $(YES),--yes)
