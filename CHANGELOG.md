# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- The first release of the gem `1billion`.
- **ActionMailer:** `delivery_method :onebillion` sends the finished message to every recipient (`to`, `cc` and `bcc`), with the `Message-ID` as the `Idempotency-Key`.
- **`OneBillion::Client`:** `send_mail` (text, HTML, attachments, raw MIME, priority), `message`, `unsuppress` and `validate` (the verdict of an address, its score and its signals; 100 credits).
- A retry of a `503` and of a network error, 3 tries in all, with the same `Idempotency-Key`.
- `OneBillion::NoCredits` (429), `OneBillion::Refused` (422, `check` and `address`) and `OneBillion::Error`.

[Unreleased]: https://github.com/clowk-in/1billion-ruby/compare/v0.0.0...HEAD
