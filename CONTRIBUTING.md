# Contributing to 1billion-ruby

Thank you for your help. Bug reports, docs fixes and pull requests are welcome.

## Before you start

- Search the [issues](https://github.com/clowk-in/1billion-ruby/issues) first.
- For a large change, open an issue and describe the idea before you write code.
- Security problems: do not open a public issue. See [SECURITY.md](SECURITY.md).
- This SDK follows the [1billion API](https://1billion.clowk.in/openapi.yml). A new endpoint comes to the 3 SDKs
  ([Ruby](https://github.com/clowk-in/1billion-ruby), [Go](https://github.com/clowk-in/1billion-go),
  [JavaScript](https://github.com/clowk-in/1billion-js)) with the same names and the same rules.

## Set up

You need Ruby 3.1 or newer, with Bundler.

```bash
git clone https://github.com/clowk-in/1billion-ruby && cd 1billion-ruby
bundle install
make test
```

The unit tests use a fake transport: no network and no API key. The integration test runs only when
`ONEBILLION_URL` is set:

```bash
ONEBILLION_URL=https://1billion.clowk.in ONEBILLION_API_KEY=<a test key> ONEBILLION_FROM="Test <hi@your-domain.com>" bundle exec rake
```

## Rules

- **Test first.** Write the failing test, then the code.
- **No runtime dependencies.** Only the standard library. `mail` is a test dependency, for the ActionMailer
  tests.
- **Blank lines.** Put one blank line before `if`, `case`, `begin`, `return` and a block that does a new job,
  after the `end` of a block when more lines follow, and between groups of lines that do different things.
- **Simple.** Do the minimum that solves the problem. No speculative options.
- **The same rules as the other SDKs:** a retry only of `503` and network errors, 3 tries in all, with the same
  `Idempotency-Key`.
- **Docs.** A change that alters behavior updates `README.md` and the `Unreleased` section of
  [CHANGELOG.md](CHANGELOG.md) in the same pull request.

## Pull requests

1. Fork, and make a branch from `main`.
2. Make small commits. Use [Conventional Commits](https://www.conventionalcommits.org) for each message and the
   pull request title: `type(scope): summary`, with the types `feat`, `fix`, `docs`, `refactor`, `perf`, `test`,
   `build`, `ci` and `chore`. `release: X.Y.Z` is only for `make tag`.
3. Run `make test` and `make build`.
4. Open the pull request and fill in the template.

## Releases

The maintainers release from `main`:

- `make tag patch|minor|major` bumps `OneBillion::VERSION`, closes the `Unreleased` section of `CHANGELOG.md`,
  makes the commit `release: X.Y.Z` and the tag `vX.Y.Z`, and asks before it pushes. `make tag 0.3.0` sets an exact version instead; it must be higher than the latest tag. `make -n tag minor` shows
  the next version and writes nothing.
- Or merge a commit with the subject `tag(patch): ...`, `tag(minor): ...` or `tag(major): ...`. When CI
  passes on `main`, `tag.yml` runs the same script.

When CI passes on the release commit, `release.yml` makes the GitHub release with the notes of
`CHANGELOG.md`, and `publish.yml` pushes the gem to rubygems.org. It uses the secret `GEM_HOST_API_KEY` when it
is set. Without it, it uses trusted publishing, and the secret `RUBYGEMS_OWNER` (the id of the rubygems.org
account that owns the gem) must be set.

## License

By contributing, you agree that your work is licensed under the [MIT license](LICENSE).
