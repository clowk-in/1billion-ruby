#!/bin/sh
# release.sh bumps the version of this SDK, closes the Unreleased section of
# CHANGELOG.md, makes the commit "release: X.Y.Z" and the tag vX.Y.Z, then
# asks before it pushes.
#
#   scripts/release.sh patch|minor|major [--dry-run] [--yes]
#
# The Makefile calls it: make tag patch, make tag minor, make tag major.
# --yes (make tag patch YES=1) pushes without asking, for scripts and agents.
# tag.yml calls it too, for a commit "tag(patch): ..." on main.
#
# The script pushes main and the tag, and ends. CI tests the release commit,
# and when the tests pass it runs the release (release.yml and publish.yml)
# for that tag. A failed CI publishes nothing.

set -eu

cd "$(dirname "$0")/.."

bump="${1:-patch}"
dry=""
yes=""

[ $# -gt 0 ] && shift

for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    --yes | -y) yes=1 ;;
  esac
done

case "$bump" in
  patch | minor | major) ;;
  *)
    echo "usage: make tag patch|minor|major" >&2
    exit 2
    ;;
esac

# fail stops the release. A dry run only warns and goes on.
fail() {
  echo "release: $1" >&2

  [ -n "$dry" ] || exit 1
}

# Each file holds one version string: VERSION = "X.Y.Z", Version = "X.Y.Z"
# or "version": "X.Y.Z".
VERSION_FILES="lib/onebillion/version.rb"

cleanup() {
  for file in CHANGELOG.md $VERSION_FILES; do
    rm -f "$file.tmp"
  done
}

trap cleanup EXIT

# Checks: on main, clean tree, up to date with origin.
branch="$(git rev-parse --abbrev-ref HEAD)"

if [ "$branch" != "main" ]; then
  fail "you are on $branch, not main."
fi

if [ -n "$(git status --porcelain)" ]; then
  fail "the working tree is not clean."
fi

git fetch --quiet --tags origin main

# Local commits that are not pushed are fine: the push at the end sends them
# with the tag. Stop only when origin/main has commits that main does not.
if ! git merge-base --is-ancestor origin/main HEAD; then
  fail "origin/main has commits that main does not have. Pull first."
fi

ahead="$(git rev-list --count origin/main..HEAD)"

if [ "$ahead" -gt 0 ]; then
  echo "release: main has $ahead commit(s) that are not pushed. The push sends them too."
fi

# Next version, from the latest v* tag.
last="$(git tag --list 'v*' --sort=-v:refname | head -n 1)"
last="${last:-v0.0.0}"

current="${last#v}"
major="$(echo "$current" | cut -d. -f1)"
minor="$(echo "$current" | cut -d. -f2)"
patch="$(echo "$current" | cut -d. -f3)"

case "$bump" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac

next="$major.$minor.$patch"
today="$(date -u +%Y-%m-%d)"

echo "release: $last -> v$next ($bump)"

if git rev-parse --quiet --verify "refs/tags/v$next" >/dev/null; then
  fail "the tag v$next already exists."
fi

if [ -z "$(awk '/^## \[Unreleased\]/ { on = 1; next } /^## \[/ { on = 0 } on && NF' CHANGELOG.md)" ]; then
  fail "the Unreleased section of CHANGELOG.md is empty. Say what changed first."
fi

if [ -n "$dry" ]; then
  echo "release: dry run, nothing written."
  exit 0
fi

# CHANGELOG: open a section for the version under Unreleased, and move the
# compare links. With no tag yet, the link of the version is its tag.
awk -v ver="$next" -v last="$last" -v today="$today" '
  /^## \[Unreleased\]/ && !done_head {
    print
    print ""
    print "## [" ver "] - " today
    done_head = 1
    next
  }
  /^\[Unreleased\]: / && !done_link {
    base = $2
    sub(/\/compare\/.*/, "", base)
    print "[Unreleased]: " base "/compare/v" ver "...HEAD"

    if (last == "v0.0.0") {
      print "[" ver "]: " base "/releases/tag/v" ver
    } else {
      print "[" ver "]: " base "/compare/" last "...v" ver
    }

    done_link = 1
    next
  }
  { print }
' CHANGELOG.md > CHANGELOG.md.tmp

mv CHANGELOG.md.tmp CHANGELOG.md

for file in $VERSION_FILES; do
  sed -E "s/((VERSION|Version) = \"|\"version\": \")[0-9]+\.[0-9]+\.[0-9]+/\1$next/" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
done

git --no-pager diff --stat

# VERSION_FILES is a list of paths: split it on purpose.
# shellcheck disable=SC2086
git add CHANGELOG.md $VERSION_FILES
git commit --quiet -m "release: $next"
git tag "v$next"

echo "release: made the commit and the tag v$next."

if [ -n "$yes" ]; then
  answer=y
else
  printf "Push main and v%s to origin? [y/N] " "$next"
  read -r answer
fi

if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
  git push origin main
  git push origin "v$next"

  echo "release: pushed. CI tests the commit, then releases v$next."

  exit 0
fi

echo "release: not pushed. To push: git push origin main && git push origin v$next"
echo "release: to undo: git tag -d v$next && git reset --hard HEAD~1"
