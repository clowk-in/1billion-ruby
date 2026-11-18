require "minitest/autorun"
require "openssl"
require_relative "../lib/onebillion"
require_relative "client_test"

# Keeps OneBillion.api_key, OneBillion.url and the env vars of one test out of the next test.
module CleanGlobals
  def setup
    @env = ENV.to_h.slice("ONEBILLION_API_KEY", "ONEBILLION_URL", "ONEBILLION_WEBHOOK_SECRET")
    %w[ONEBILLION_API_KEY ONEBILLION_URL ONEBILLION_WEBHOOK_SECRET].each { |name| ENV.delete(name) }

    OneBillion.api_key = nil
    OneBillion.url = nil
  end

  def teardown
    %w[ONEBILLION_API_KEY ONEBILLION_URL ONEBILLION_WEBHOOK_SECRET].each { |name| ENV.delete(name) }
    ENV.update(@env)

    OneBillion.api_key = nil
    OneBillion.url = nil
  end
end

class GlobalsTest < Minitest::Test
  include CleanGlobals

  def test_the_key_and_the_url_come_from_the_environment
    ENV["ONEBILLION_API_KEY"] = "env-key"
    ENV["ONEBILLION_URL"] = "http://env.test"

    assert_equal "env-key", OneBillion.api_key
    assert_equal "http://env.test", OneBillion.url
  end

  def test_a_set_value_wins_over_the_environment
    ENV["ONEBILLION_API_KEY"] = "env-key"
    OneBillion.api_key = "set-key"
    OneBillion.url = "http://set.test"

    assert_equal "set-key", OneBillion.api_key
    assert_equal "http://set.test", OneBillion.url
  end

  def test_the_url_has_a_default
    assert_equal OneBillion::Client::DEFAULT_URL, OneBillion.url
  end

  def test_the_client_uses_the_key_from_the_environment
    ENV["ONEBILLION_API_KEY"] = "env-key"
    transport = FakeTransport.new([200, '{"id":"m1"}'])

    OneBillion::Client.new(url: "http://api.test", transport: transport).message("m1")

    assert_equal "Bearer env-key", transport.calls.first[:headers]["Authorization"]
  end

  def test_no_key_is_a_clear_error
    error = assert_raises(ArgumentError) { OneBillion::Client.new }

    assert_match "ONEBILLION_API_KEY", error.message
  end

  def test_the_delivery_method_needs_no_settings
    ENV["ONEBILLION_API_KEY"] = "env-key"
    ENV["ONEBILLION_URL"] = "http://env.test"

    client = OneBillion::DeliveryMethod.new.send(:client)

    assert_equal "env-key", client.instance_variable_get(:@api_key)
    assert_equal "http://env.test", client.instance_variable_get(:@url).to_s
  end

  def test_the_settings_of_the_delivery_method_win
    ENV["ONEBILLION_API_KEY"] = "env-key"

    client = OneBillion::DeliveryMethod.new(api_key: "set-key", url: "http://set.test").send(:client)

    assert_equal "set-key", client.instance_variable_get(:@api_key)
    assert_equal "http://set.test", client.instance_variable_get(:@url).to_s
  end
end

class EmailsTest < Minitest::Test
  include CleanGlobals

  ANSWER = '{"messages":[{"id":"m1","to":"ana@x.com","status":"accepted"},{"id":"m2","to":"bia@x.com","status":"accepted"}]}'.freeze

  def fake(*answers)
    transport = FakeTransport.new(*answers)
    OneBillion.client = OneBillion::Client.new(api_key: "key", url: "http://api.test", backoff: 0, transport: transport)

    transport
  end

  def test_sends_like_resend
    transport = fake([202, ANSWER])

    answer = OneBillion::Emails.send(
      {
        from: "App <hi@app.com>",
        to: ["ana@x.com", "bia@x.com"],
        "cc" => "cc@x.com",
        reply_to: "help@app.com",
        subject: "Oi",
        html: "<p>Olá</p>",
        text: "Olá",
        attachments: [{ filename: "a.txt", content: "b2k=", content_type: "text/plain" }],
        priority: "high"
      },
      { idempotency_key: "k1" }
    )

    call = transport.calls.first

    assert_equal "m1", answer["id"]
    assert_equal 2, answer["messages"].size
    assert_equal({ "text" => "Olá", "html" => "<p>Olá</p>" }, call[:body]["body"])
    assert_nil call[:body]["html"]
    assert_equal "cc@x.com", call[:body]["cc"]
    assert_equal "help@app.com", call[:body]["reply_to"]
    assert_equal "a.txt", call[:body]["attachments"].first["filename"]
    assert_equal "k1", call[:headers]["Idempotency-Key"]
  end

  def test_an_unsupported_key_is_an_error_that_names_it
    transport = fake([202, ANSWER])

    error = assert_raises(ArgumentError) { OneBillion::Emails.send(from: "a@app.com", to: "b@x.com", subject: "s", text: "t", tags: []) }

    assert_match "tags", error.message
    assert_empty transport.calls
  end

  def test_an_unsupported_option_is_an_error
    fake([202, ANSWER])

    error = assert_raises(ArgumentError) { OneBillion::Emails.send({ from: "a@app.com", to: "b@x.com", subject: "s", text: "t" }, { retries: 2 }) }

    assert_match "retries", error.message
  end

  def test_the_default_client_uses_the_environment
    ENV["ONEBILLION_API_KEY"] = "env-key"

    assert_equal "env-key", OneBillion.client.instance_variable_get(:@api_key)
  end

  def test_a_new_key_makes_a_new_client
    OneBillion.api_key = "one"
    first = OneBillion.client
    OneBillion.api_key = "two"

    refute_same first, OneBillion.client
  end
end

class SignatureTest < Minitest::Test
  include CleanGlobals

  SECRET = "whsec_test".freeze
  PAYLOAD = '{"id":"e1","type":"delivered","message_id":"m1","to":"ana@x.com","detail":"250 ok","created_at":"2026-11-18T10:00:00.000Z"}'.freeze

  def headers(timestamp: Time.now.to_i, payload: PAYLOAD, secret: SECRET)
    hex = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")

    { "1B-Event-Id" => "e1", "1B-Timestamp" => timestamp.to_s, "1B-Signature" => "sha256=#{hex}" }
  end

  def test_returns_the_event
    event = OneBillion::Signature.verify(payload: PAYLOAD, headers: headers, secret: SECRET)

    assert_equal "delivered", event["type"]
    assert_equal "m1", event["message_id"]
  end

  def test_header_names_are_case_insensitive
    lower = headers.transform_keys(&:downcase)

    assert_equal "e1", OneBillion::Signature.verify(payload: PAYLOAD, headers: lower, secret: SECRET)["id"]
  end

  # Rails request.headers answers [] for the header name, but is not a Hash.
  def test_takes_an_object_like_rails_request_headers
    rails = Struct.new(:env) { def [](name) = env["HTTP_#{name.upcase.tr("-", "_")}"] }
    env = headers.to_h { |name, value| ["HTTP_#{name.upcase.tr("-", "_")}", value] }

    assert_equal "e1", OneBillion::Signature.verify(payload: PAYLOAD, headers: rails.new(env), secret: SECRET)["id"]
  end

  def test_the_secret_comes_from_the_environment
    ENV["ONEBILLION_WEBHOOK_SECRET"] = SECRET

    assert_equal "e1", OneBillion::Signature.verify(payload: PAYLOAD, headers: headers)["id"]
  end

  def test_no_secret_is_a_clear_error
    error = assert_raises(ArgumentError) { OneBillion::Signature.verify(payload: PAYLOAD, headers: headers) }

    assert_match "ONEBILLION_WEBHOOK_SECRET", error.message
  end

  def test_a_bad_signature_is_invalid
    error = assert_raises(OneBillion::Signature::Invalid) { OneBillion::Signature.verify(payload: PAYLOAD, headers: headers(secret: "other"), secret: SECRET) }

    assert_kind_of OneBillion::Error, error
  end

  def test_a_changed_body_is_invalid
    assert_raises(OneBillion::Signature::Invalid) { OneBillion::Signature.verify(payload: PAYLOAD.sub("delivered", "bounced"), headers: headers, secret: SECRET) }
  end

  def test_a_missing_signature_is_invalid
    assert_raises(OneBillion::Signature::Invalid) { OneBillion::Signature.verify(payload: PAYLOAD, headers: headers.except("1B-Signature"), secret: SECRET) }
    assert_raises(OneBillion::Signature::Invalid) { OneBillion::Signature.verify(payload: PAYLOAD, headers: headers.except("1B-Timestamp"), secret: SECRET) }
  end

  def test_an_old_timestamp_is_invalid
    old = headers(timestamp: Time.now.to_i - 301)

    assert_raises(OneBillion::Signature::Invalid) { OneBillion::Signature.verify(payload: PAYLOAD, headers: old, secret: SECRET) }
    assert_equal "e1", OneBillion::Signature.verify(payload: PAYLOAD, headers: old, secret: SECRET, tolerance: 600)["id"]
  end
end
