require "json"
require "net/http"
require "securerandom"
require "uri"

module OneBillion
  # The client of the 1billion API. Use it only on a server: an API key must never reach a
  # browser.
  #
  #   client = OneBillion::Client.new(api_key: ENV["ONEBILLION_KEY"])
  #   client.send_mail(from: "App <hi@app.com>", to: ["ana@example.com"], subject: "Oi", text: "Olá")
  #
  # A 503 or a network error is tried again (3 times in all) with the same Idempotency-Key, so
  # a retry never sends twice. No other error is tried again.
  class Client
    DEFAULT_URL = "https://1billion.clowk.in"
    TRIES = 3

    def initialize(api_key:, url: DEFAULT_URL, timeout: 10, backoff: 0.5, transport: nil)
      raise ArgumentError, "api_key is required" if api_key.to_s.empty?

      @api_key = api_key
      @url = URI(url)
      @timeout = timeout
      @backoff = backoff
      @transport = transport || method(:http)
    end

    # POST /send. `text:` and `html:` go in the body; `raw:` sends a finished MIME message.
    # Returns the parsed answer: { "messages" => [{ "id", "to", "status" }] }.
    def send_mail(idempotency_key: nil, text: nil, html: nil, **fields)
      body = fields.compact
      body[:body] = { text: text, html: html }.compact if text || html

      request(:post, "/send", body, idempotency_key: idempotency_key || SecureRandom.uuid)
    end

    def message(id) = request(:get, "/messages/#{URI.encode_www_form_component(id)}")

    def unsuppress(address) = request(:delete, "/suppressions/#{URI.encode_www_form_component(address)}")

    def validate(address) = request(:post, "/validate", { address: address })

    private

    def request(verb, path, body = nil, idempotency_key: nil)
      headers = {
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type" => "application/json",
        "User-Agent" => "onebillion-ruby/#{VERSION}"
      }
      headers["Idempotency-Key"] = idempotency_key if idempotency_key

      tries = 0

      begin
        tries += 1
        status, text = @transport.call(verb, @url + path, headers, body && JSON.generate(body))

        answer(status, text)
      rescue Error => error
        retry if retryable?(error) && tries < TRIES && pause(tries)

        raise
      end
    end

    def retryable?(error) = error.status.nil? || error.status == 503

    def pause(tries)
      sleep(@backoff * (2**(tries - 1)))

      true
    end

    def answer(status, text)
      body = text.to_s.empty? ? {} : JSON.parse(text)

      return body if status.between?(200, 299)

      message = body["error"] || "HTTP #{status}"

      case status
      when 429 then raise NoCredits.new(message, status: status, body: body)
      when 422 then raise Refused.new(message, status: status, body: body)
      else raise Error.new(message, status: status, body: body)
      end
    rescue JSON::ParserError
      raise Error.new("HTTP #{status}: not JSON", status: status)
    end

    def http(verb, uri, headers, payload)
      klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete }.fetch(verb)
      req = klass.new(uri, headers)
      req.body = payload if payload

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: @timeout, read_timeout: @timeout) { |h| h.request(req) }

      [response.code.to_i, response.body]
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, IOError => error
      raise Error.new(error.message)
    end
  end
end
