<p align="center">
  <a href="https://1billion.clowk.in">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/clowk-in/1billion-ruby/main/.github/assets/logo-white.svg">
      <img src="https://raw.githubusercontent.com/clowk-in/1billion-ruby/main/.github/assets/logo-color.svg" alt="1billion" height="64">
    </picture>
  </a>
</p>

<p align="center">
  <b>Transactional e-mail on its own sending infrastructure.</b><br>
  The official Ruby SDK.
</p>

<p align="center">
  <a href="https://1billion.clowk.in"><b>Website</b></a> ·
  <a href="https://1billion.clowk.in"><b>Get an API key</b></a> ·
  <a href="https://1billion.clowk.in/openapi.yml"><b>API reference</b></a> ·
  <a href="CHANGELOG.md"><b>Changelog</b></a>
</p>

<p align="center">
  <a href="https://github.com/clowk-in/1billion-ruby/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/clowk-in/1billion-ruby/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://rubygems.org/gems/1billion"><img alt="Gem Version" src="https://img.shields.io/gem/v/1billion.svg"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
</p>

The official Ruby client of [1billion](https://1billion.clowk.in): transactional e-mail on its own sending
infrastructure. Send a login code, a receipt or a reset link from Rails or from plain Ruby, and read what
happened to each recipient.

- **Rails with one line.** An ActionMailer delivery method: your mailers do not change.
- **No dependencies.** Only the Ruby standard library (`net/http`, `json`).
- **Safe retries.** A `503` or a network error is tried again with the same `Idempotency-Key`, so a retry never
  sends a mail twice.
- **Clear errors.** `OneBillion::NoCredits` and `OneBillion::Refused` tell you what to do next.
- **Address validation.** A verdict, a score and the signals of an address, before you send to it.

> Use it only on a server. An API key must never reach a browser.

## Install

```bash
bundle add 1billion
```

Ruby 3.1 or newer. The gem is named `1billion`; its code is under `OneBillion`, because a Ruby constant can
not start with a digit.

Make an API key in the [console](https://1billion.clowk.in), and verify the domain that you send from. Put the
key in the environment:

```bash
export ONEBILLION_API_KEY=<your API key>
```

## Rails (ActionMailer)

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :onebillion
```

That is all. The key comes from `ONEBILLION_API_KEY`. Your mailers and views do not change:

```ruby
class UserMailer < ApplicationMailer
  def login_code(user, code)
    @code = code

    mail(to: user.email, subject: "Your code")
  end
end

UserMailer.login_code(user, "482913").deliver_later
```

The gem sends the finished MIME message to every recipient (`to`, `cc` and `bcc`), and the `Message-ID` is
the `Idempotency-Key`: the same message sent twice goes out once. Send with `deliver_later`, so a slow
network never holds a web request.

To set the key in code, use `onebillion_settings`. The settings win over the environment:

```ruby
config.action_mailer.onebillion_settings = { api_key: Rails.application.credentials.onebillion_api_key }
```

| Setting | Default | What |
|---|---|---|
| `api_key` | `ENV["ONEBILLION_API_KEY"]` | the API key of the app |
| `url` | `ENV["ONEBILLION_URL"]`, else `https://1billion.clowk.in` | another console, for example a dev stack |

## Send a mail (the same call as Resend)

```ruby
answer = OneBillion::Emails.send(
  {
    from: "Acme <hi@acme.com>",
    to: "jane@example.com",
    subject: "Your code",
    html: "<p>Your code is <b>482 913</b></p>"
  },
  { idempotency_key: "login-jane-482913" }
)

answer["id"] # => "9f2c…", the id of the first message
```

This is the call of `Resend::Emails.send`: a move from Resend changes only the constant. The keys can be
symbols or strings. It returns when 1billion has the mail (`202`, status `accepted`); the delivery runs after
that, with its own retries. The answer has `"id"` and `"messages"` (one per recipient).

| Key | What |
|---|---|
| `from` | a sender on a verified domain of the app, with a name or without one |
| `to`, `cc`, `bcc` | one recipient or a list |
| `reply_to` | the reply address |
| `text`, `html` | the body: one of them or both |
| `attachments` | `[{ filename:, content_type:, content: }]`, with `content` in base64 |
| `priority` | `"normal"` (the default) or `"high"`: mail that a person waits for goes first |

The second argument takes `idempotency_key`: the same key in 30 days returns the first answer and sends
nothing again. Without it, the SDK makes one and uses it for its own retries.

A key that 1billion does not support (for example `tags`, `headers` or `scheduled_at`) raises an
`ArgumentError` that names it. The SDK never drops a key and sends the mail without it.

The key comes from `ONEBILLION_API_KEY`. To set it in code, use `OneBillion.api_key = "..."` (and
`OneBillion.url` for another console).

## Verify a webhook

```ruby
class WebhooksController < ApplicationController
  skip_forgery_protection

  def create
    event = OneBillion::Signature.verify(payload: request.raw_post, headers: request.headers)

    case event["type"]
    when "bounced" then User.find_by(email: event["to"])&.update(email_bounced: true)
    end

    head :ok
  rescue OneBillion::Signature::Invalid
    head :unauthorized
  end
end
```

`verify` checks `1B-Signature` against the raw body and `1B-Timestamp`, and returns the event as a Hash
(`id`, `type`, `message_id`, `to`, `detail`, `created_at`). The secret comes from
`ONEBILLION_WEBHOOK_SECRET`; pass `secret:` to set it in code. A bad or missing signature, or a timestamp older
than 5 minutes (`tolerance: 300`), raises `OneBillion::Signature::Invalid`. `headers` is a Hash (names in any
case) or Rails `request.headers`.

### A received mail

A mail to an address whose route is "webhook" (Recebimento, in the console) comes as the event
`mail.received` (`OneBillion::Signature::MAIL_RECEIVED`). Its `"data"` is the whole mail. 1billion keeps no
content, so this is the only time your app gets it.

```ruby
if event["type"] == OneBillion::Signature::MAIL_RECEIVED
  mail = event["data"]

  Feedback.create!(from: mail["mail_from"], subject: mail["subject"], body: mail["text"])

  mail["attachments"].each { |file| Rails.logger.info([file["filename"], file["content_type"], file["size"]]) }
end
```

`"data"` has `id`, `from`, `to`, `mail_from`, `subject`, `message_id`, `text`, `html`, `attachments` (the name,
type and size of each file, never its content), `auth` (`spf`, `dkim` and `dmarc` as our mx saw them), `size`
and `received_at`. `text` and `html` are whole, never cut, and are `nil` when the mail has none. The other events
have no `"data"`.

## Read a message, validate an address, suppressions

`OneBillion.client` is a client with the key of `ONEBILLION_API_KEY`, ready to use.

### Read a message

```ruby
OneBillion.client.message("9f2c…")
# => { "id" => "9f2c…", "status" => "sent", "attempts" => 1, "last_error" => nil, ... }
```

`status` is `accepted`, `queued`, `sending`, `sent`, `bounced` or `suppressed`. `sent` means that the mail
server of the recipient accepted the message. Messages stay for 30 days.

### Validate an address

```ruby
OneBillion.client.validate("jane@gmial.com")
# => { "result" => "risky", "reason" => "possible_typo", "score" => 0.3,
#      "did_you_mean" => "jane@gmail.com", "disposable" => false, "role" => false, ... }
```

`result` is `deliverable`, `risky` or `undeliverable`. A validation sends nothing and costs 100 credits.

### Suppressions

A hard bounce or a complaint puts the address on the suppression list of the app, and 1billion stops sending
to it. When the address works again:

```ruby
OneBillion.client.unsuppress("jane@example.com")
```

## Errors

```ruby
begin
  OneBillion::Emails.send(mail)
rescue OneBillion::NoCredits => error
  # 429: no credits for these recipients today. They come back at 00:00 in the time
  # zone of the workspace (error.body["retry_after"] seconds), or buy a pack
  # (error.body["buy_url"]).
rescue OneBillion::Refused => error
  # 422: a bad message, a domain that is not verified, or a recipient that failed a
  # check (error.check, error.address).
rescue OneBillion::Error => error
  # Any other answer: error.status and error.body. status is nil for a network error.
end
```

| Status | Error | What |
|---|---|---|
| `401` | `OneBillion::Error` | a bad API key |
| `403` | `OneBillion::Error` | the sends of the workspace are paused (low reputation); a person reviews it |
| `422` | `OneBillion::Refused` | fix the message or the recipient |
| `429` | `OneBillion::NoCredits` | no credits today |
| `503` | — | tried again by the client |

Only a `503` and a network error are tried again: 3 tries in all, with a wait that doubles (0.5 s, then 1 s).
No other error is tried again, because a second try gives the same answer.

## More than one key (the client)

`OneBillion::Emails.send` and `OneBillion.client` use one key for the whole process. To send for two apps
from one process, or to another console, make a client for each:

```ruby
billing = OneBillion::Client.new(api_key: ENV["BILLING_ONEBILLION_API_KEY"])

billing.send_mail(
  from: "Acme Billing <billing@acme.com>",
  to: ["jane@example.com"],
  subject: "Your receipt",
  html: "<p>Thanks for your order.</p>",
  idempotency_key: "receipt-8812"
)
```

`send_mail` takes the same keys as `Emails.send`, the `idempotency_key` among them, and also `raw`: a
finished MIME message in place of the other fields. `message`, `validate` and `unsuppress` are on the client
too. A client takes these options:

```ruby
OneBillion::Client.new(
  api_key: "...",               # ENV["ONEBILLION_API_KEY"] by default
  url: "http://localhost:3100", # ENV["ONEBILLION_URL"], else https://1billion.clowk.in
  timeout: 5,                   # seconds, 10 by default
  backoff: 1                    # the first wait between tries, 0.5 s by default
)
```

Each request has the `User-Agent` `onebillion-ruby/<version>` (with `actionmailer` from the delivery
method), so the console shows which mails came from the SDK.

## Start sending

1. Make a free account on **[1billion.clowk.in](https://1billion.clowk.in)**: 100 mails a day for free, every day, and your first domain for free.
2. Add your domain. The console gives you the DNS records, and checks them for you.
3. Make an API key, then `bundle add 1billion`.

Your first mail goes out in a few minutes. A question about the SDK? [Open an issue](https://github.com/clowk-in/1billion-ruby/issues).

## Docs

- API reference: [openapi.yml](https://1billion.clowk.in/openapi.yml)
- Changes: [CHANGELOG.md](CHANGELOG.md)
- Other SDKs: [Go](https://github.com/clowk-in/1billion-go) and
  [JavaScript](https://github.com/clowk-in/1billion-js) (Node.js, Next.js, Bun)

## Contributing

Bug reports and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first. For a security
problem, see [SECURITY.md](SECURITY.md). This project follows a [Code of Conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE)
