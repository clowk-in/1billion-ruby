# onebillion (Ruby)

The Ruby client of [1billion](https://1billion.clowk.in): transactional e-mail with our own MTA. Use it only
on a server: an API key must never reach a browser.

```ruby
gem "onebillion"
```

## Rails (ActionMailer)

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :onebillion
config.action_mailer.onebillion_settings = { api_key: ENV["ONEBILLION_KEY"] }
```

Your mailers do not change. The gem sends the finished message to every recipient (to, cc and bcc), and the
Message-ID is the Idempotency-Key: a retried job never sends the mail twice. Send with `deliver_later`.

## The client

```ruby
client = OneBillion::Client.new(api_key: ENV["ONEBILLION_KEY"])

client.send_mail(
  from: "App <hi@seu-dominio.com>",
  to: ["jane@exemplo.com"],
  subject: "Seu código",
  text: "Seu código é 482 913",
  priority: "high",
  idempotency_key: "login-jane-482913"
)

client.message("9f2c…")             # the state of one recipient
client.unsuppress("jane@exemplo.com")
client.validate("jane@exemplo.com") # { "valid" => true, "checks" => [...] }
```

- A `503` or a network error is tried again, 3 times in all, with the same `Idempotency-Key` (made for you
  when you do not pass one). No other error is tried again.
- `OneBillion::NoCredits` (402, `error.body["buy_url"]`), `OneBillion::Refused` (422, `error.check` and
  `error.address`), `OneBillion::Error` for the rest (`error.status`, `error.body`).

The API is in [openapi.yml](https://1billion.clowk.in/openapi.yml).

## Tests

```bash
bundle exec rake
ONEBILLION_URL=http://localhost:3100 ONEBILLION_KEY=dev-token ONEBILLION_FROM="Dev <hi@dev.test>" bundle exec rake
```
