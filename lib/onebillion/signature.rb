require "json"
require "openssl"

module OneBillion
  # Checks the signature of a webhook and returns the event:
  #
  #   event = OneBillion::Signature.verify(payload: request.raw_post, headers: request.headers)
  #   event["type"] # => "delivered"
  #
  # A mail.received event (MAIL_RECEIVED) has the received mail in event["data"]: "from", "subject",
  # "text", "html", "attachments", "auth" and more. The other events have no "data".
  #
  # The signature is `1B-Signature: sha256=<hex>`, with hex = HMAC-SHA256(secret,
  # "<1B-Timestamp>.<raw body>"). The secret comes from ENV["ONEBILLION_WEBHOOK_SECRET"].
  module Signature
    # A bad or missing signature, or a timestamp out of the tolerance.
    class Invalid < Error; end

    # The type of the event of a received mail: a mail to an address whose route is "webhook".
    MAIL_RECEIVED = "mail.received".freeze

    def self.verify(payload:, headers:, secret: ENV["ONEBILLION_WEBHOOK_SECRET"], tolerance: 300)
      raise ArgumentError, "no webhook secret: set ONEBILLION_WEBHOOK_SECRET or pass secret:" if secret.to_s.empty?

      timestamp = header(headers, "1B-Timestamp").to_s
      signature = header(headers, "1B-Signature").to_s

      raise Invalid, "no 1B-Timestamp or 1B-Signature header" if timestamp.empty? || signature.empty?

      seconds = Integer(timestamp, 10, exception: false)

      raise Invalid, "the timestamp is out of the tolerance" if seconds.nil? || (Time.now.to_i - seconds).abs > tolerance

      expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")}"

      raise Invalid, "the signature does not match" unless OpenSSL.secure_compare(expected, signature)

      JSON.parse(payload)
    end

    # A Hash with names in any case, or an object with [] such as Rails request.headers.
    def self.header(headers, name)
      value = headers[name]

      return value if value || !headers.is_a?(Hash)

      headers.find { |key, _| key.to_s.casecmp?(name) }&.last
    end

    private_class_method :header
  end
end
