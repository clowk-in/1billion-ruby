require "minitest/autorun"
require "mail"
require_relative "../lib/onebillion"

# A transport that answers from a list and records each call, so no test needs the network.
class FakeTransport
  attr_reader :calls

  def initialize(*answers)
    @answers = answers
    @calls = []
  end

  def call(verb, uri, headers, body)
    @calls << { verb: verb, path: uri.path, headers: headers, body: body && JSON.parse(body) }

    answer = @answers.shift

    raise OneBillion::Error.new("connection refused") if answer == :network

    answer
  end
end

class ClientTest < Minitest::Test
  def client(transport) = OneBillion::Client.new(api_key: "key", url: "http://api.test", backoff: 0, transport: transport)

  def test_sends_a_mail_with_its_headers
    transport = FakeTransport.new([202, '{"messages":[{"id":"m1","to":"ana@x.com","status":"accepted"}]}'])

    answer = client(transport).send_mail(from: "App <hi@app.com>", to: ["ana@x.com"], subject: "Oi", text: "Olá", idempotency_key: "k1")
    call = transport.calls.first

    assert_equal "m1", answer["messages"].first["id"]
    assert_equal [:post, "/send"], [call[:verb], call[:path]]
    assert_equal({ "text" => "Olá" }, call[:body]["body"])
    assert_equal "Bearer key", call[:headers]["Authorization"]
    assert_equal "k1", call[:headers]["Idempotency-Key"]
    assert_match %r{\Aonebillion-ruby/}, call[:headers]["User-Agent"]
  end

  def test_retries_a_503_and_a_network_error_with_the_same_key
    transport = FakeTransport.new([503, '{"error":"try again later"}'], :network, [202, '{"messages":[]}'])

    client(transport).send_mail(from: "a@app.com", to: ["b@x.com"], subject: "s", text: "t")

    keys = transport.calls.map { |call| call[:headers]["Idempotency-Key"] }

    assert_equal 3, keys.size
    assert_equal 1, keys.uniq.size
    refute_nil keys.first
  end

  def test_gives_up_after_3_tries
    transport = FakeTransport.new([503, "{}"], [503, "{}"], [503, "{}"])

    error = assert_raises(OneBillion::Error) { client(transport).message("m1") }

    assert_equal 503, error.status
    assert_equal 3, transport.calls.size
  end

  def test_never_retries_other_errors
    transport = FakeTransport.new([422, '{"error":"x@tmp.com: disposable","check":"disposable","address":"x@tmp.com"}'])

    error = assert_raises(OneBillion::Refused) { client(transport).send_mail(from: "a@app.com", to: ["x@tmp.com"], subject: "s", text: "t") }

    assert_equal ["disposable", "x@tmp.com"], [error.check, error.address]
    assert_equal 1, transport.calls.size
  end

  def test_no_credits
    transport = FakeTransport.new([429, '{"error":"not enough credits","retry_after":3600,"buy_url":"https://1billion.clowk.in/usage"}'])

    error = assert_raises(OneBillion::NoCredits) { client(transport).send_mail(from: "a@app.com", to: ["b@x.com"], subject: "s", text: "t") }

    assert_equal "https://1billion.clowk.in/usage", error.body["buy_url"]
  end

  def test_message_unsuppress_and_validate
    transport = FakeTransport.new([200, '{"id":"m1","status":"sent"}'], [204, ""], [200, '{"valid":false}'])
    api = client(transport)

    assert_equal "sent", api.message("m1")["status"]
    assert_equal({}, api.unsuppress("ana@x.com"))
    refute api.validate("x@tmp.com")["valid"]
    assert_equal ["/messages/m1", "/suppressions/ana%40x.com", "/validate"], transport.calls.map { |call| call[:path] }
  end

  def test_needs_a_key
    assert_raises(ArgumentError) { OneBillion::Client.new(api_key: "") }
  end
end

class DeliveryMethodTest < Minitest::Test
  def test_sends_the_raw_mail_to_every_envelope_recipient
    transport = FakeTransport.new([202, '{"messages":[]}'])
    delivery = OneBillion::DeliveryMethod.new(api_key: "key")
    delivery.instance_variable_set(:@client, OneBillion::Client.new(api_key: "key", url: "http://api.test", transport: transport))

    mail = Mail.new do
      from "App <hi@app.com>"
      to "ana@x.com"
      cc "bia@x.com"
      bcc "hidden@x.com"
      subject "Seu código"
      body "482 913"
      message_id "<abc@app.com>"
    end

    delivery.deliver!(mail)

    body = transport.calls.first[:body]

    assert_equal %w[ana@x.com bia@x.com hidden@x.com], body["to"]
    assert_includes body["raw"], "482 913"
    refute_includes body["raw"], "hidden@x.com"
    assert_equal "abc@app.com", transport.calls.first[:headers]["Idempotency-Key"]
  end
end

# Against a real console (the dev stack: ONEBILLION_URL=http://localhost:3100
# ONEBILLION_KEY=dev-token ONEBILLION_FROM="Dev <hi@dev.test>").
class IntegrationTest < Minitest::Test
  def test_sends_and_reads_a_mail
    skip "set ONEBILLION_URL to run" unless ENV["ONEBILLION_URL"]

    api = OneBillion::Client.new(api_key: ENV.fetch("ONEBILLION_KEY"), url: ENV.fetch("ONEBILLION_URL"))
    sent = api.send_mail(from: ENV.fetch("ONEBILLION_FROM"), to: ["sdk-ruby@gmail.com"], subject: "SDK Ruby", text: "Olá")
    id = sent["messages"].first["id"]

    assert_equal id, api.message(id)["id"]
    assert api.validate("ana@gmail.com")["valid"]
  end
end
