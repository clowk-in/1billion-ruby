module OneBillion
  # The same call as Resend::Emails.send, so a move from Resend changes only the constant:
  #
  #   OneBillion::Emails.send({ from: "App <hi@app.com>", to: "ana@example.com", subject: "Oi", html: "<p>Olá</p>" })
  #   # => { "id" => "9f2c…", "messages" => [{ "id" => "9f2c…", "to" => "ana@example.com", "status" => "accepted" }] }
  #
  # A key that 1billion does not support (for example `tags` or `scheduled_at`) raises an
  # ArgumentError: the mail is never sent without it.
  module Emails
    FIELDS = %i[from to cc bcc reply_to subject html text attachments priority].freeze
    OPTIONS = %i[idempotency_key].freeze

    def self.send(params, options = {})
      params = symbolize(params, FIELDS, "OneBillion::Emails.send")
      options = symbolize(options, OPTIONS, "the options of OneBillion::Emails.send")

      answer = OneBillion.client.send_mail(**params, **options)

      { "id" => answer.fetch("messages", []).first&.fetch("id"), **answer }
    end

    def self.symbolize(hash, allowed, name)
      hash = hash.to_h { |key, value| [key.to_sym, value] }
      unknown = hash.keys - allowed

      raise ArgumentError, "#{name} does not support: #{unknown.join(", ")}" if unknown.any?

      hash
    end

    private_class_method :symbolize
  end
end
