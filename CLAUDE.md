# 1billion-ruby — guide for AI agents

Read this file first. It tells you what this repo is, how to test it, and its rules.

## What it is

The official Ruby client of [1billion](https://1billion.clowk.in), a transactional e-mail API: the gem
`1billion`, with its code under `OneBillion` (a Ruby constant can not start with a digit). It has no runtime
dependencies. The API it follows is [openapi.yml](https://1billion.clowk.in/openapi.yml).

| Path | What |
|---|---|
| `lib/1billion.rb` | the file that Bundler requires by the gem name; it requires `onebillion` |
| `lib/onebillion/client.rb` | `OneBillion::Client`: `send_mail`, `message`, `unsuppress`, `validate` |
| `lib/onebillion/delivery_method.rb` | the ActionMailer delivery method `:onebillion` |
| `lib/onebillion/errors.rb` | `Error`, `NoCredits` (429), `Refused` (422) |
| `lib/onebillion/version.rb` | `OneBillion::VERSION`, changed only by `make tag` |
| `test/` | Minitest, with a fake transport: no network |

The same SDK exists for Go (`clowk-in/1billion-go`) and JavaScript (`clowk-in/1billion-js`). The 3 keep the
same names and the same rules. A change to one usually needs the same change in the other two.

## Run and test

```bash
bundle install
make test    # bundle exec rake
make build   # gem build, to check the gemspec
```

The integration test runs only with `ONEBILLION_URL`, `ONEBILLION_KEY` and `ONEBILLION_FROM`.

## Rules

- **Test first.** Write the failing test, then the code.
- **The retry rule:** only a `503` and a network error are tried again, 3 tries in all, with the same
  `Idempotency-Key`. The client makes the key when the caller does not pass one; the delivery method uses
  the `Message-ID`.
- **No runtime dependencies.** Only the standard library. Ruby 3.1 is the oldest version (CI tests 3.1 to 4.0).
- **Simple:** the minimum that solves the problem. No speculative options.
- **Blank lines:** one blank line before `if`, `case`, `begin` and `return` (unless first in the method), after
  the `end` of a block when more lines follow, and between groups of lines that do different jobs.
- **Docs change with behavior** in the same commit: `README.md` and the `Unreleased` section of `CHANGELOG.md`.
- **Docs style:** short sentences and simple words (ASD-STE100 style), as in the existing pages.
- This is a public repo. Never put an API key, a customer address or a private host in code, tests or docs.

## Release

- `make tag patch|minor|major` (`scripts/release.sh`) bumps `OneBillion::VERSION`, closes the `Unreleased`
  section of `CHANGELOG.md`, commits `release: X.Y.Z`, tags `vX.Y.Z` and asks before the push. `YES=1` pushes
  without asking. `make -n tag minor` is a dry run.
- A commit `tag(patch|minor|major): ...` on `main` does the same through `tag.yml`, after CI passes.
- CI tests the release commit, then `release.yml` makes the GitHub release and `publish.yml` pushes the gem.
- Never push a `v*` tag or a gem by hand: the version in `version.rb` must match the tag.

## Git

- **Conventional Commits** for every commit and PR title: `type(scope): summary`, lower case type, summary in
  the imperative, no period at the end. Types: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`,
  `ci`, `chore`.
- Commit only when the maintainer asks. Do not watch CI: the maintainer follows it.
- Never credit Claude in a commit or a PR: no `Co-Authored-By: Claude` trailer, no "Generated with Claude Code"
  line. The author is always the maintainer.
