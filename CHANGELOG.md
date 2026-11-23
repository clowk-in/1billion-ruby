# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- The event of a received mail: `OneBillion::Signature::MAIL_RECEIVED` (`"mail.received"`). Its `"data"` is the
  whole mail (`from`, `subject`, `text`, `html`, `attachments`, `auth` and more). The other events have no
  `"data"`.

## [0.3.0] - 2026-11-18

### Added

- `OneBillion.api_key` and `OneBillion.url`, from `ENV["ONEBILLION_API_KEY"]` and `ENV["ONEBILLION_URL"]` by default.
- `OneBillion::Emails.send(params, options)`: the same call as `Resend::Emails.send`. It returns `"id"` and `"messages"`. A key that 1billion does not support raises an `ArgumentError`.
- `OneBillion::Signature.verify(payload:, headers:)`: checks the signature of a webhook and returns the event. It raises `OneBillion::Signature::Invalid`.

### Changed

- The delivery method `:onebillion` needs no settings: the whole Rails setup is `config.action_mailer.delivery_method = :onebillion`. `onebillion_settings` still wins.
- `OneBillion::Client.new` takes the key from `ONEBILLION_API_KEY` when you do not pass `api_key:`.
- The env var of the docs and of the integration test is `ONEBILLION_API_KEY` (it was `ONEBILLION_KEY`).

## [0.1.0] - 2026-11-18

### Added

- The first release of the gem `1billion`.
- **ActionMailer:** `delivery_method :onebillion` sends the finished message to every recipient (`to`, `cc` and `bcc`), with the `Message-ID` as the `Idempotency-Key`.
- **`OneBillion::Client`:** `send_mail` (text, HTML, attachments, raw MIME, priority), `message`, `unsuppress` and `validate` (the verdict of an address, its score and its signals; 100 credits).
- A retry of a `503` and of a network error, 3 tries in all, with the same `Idempotency-Key`.
- `OneBillion::NoCredits` (429), `OneBillion::Refused` (422, `check` and `address`) and `OneBillion::Error`.

[Unreleased]: https://github.com/clowk-in/1billion-ruby/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/clowk-in/1billion-ruby/compare/v0.1.0...v0.3.0
[0.1.0]: https://github.com/clowk-in/1billion-ruby/releases/tag/v0.1.0
