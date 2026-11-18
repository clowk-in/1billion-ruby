module OneBillion
  # The ActionMailer delivery method. Your mailers stay as they are:
  #
  #   config.action_mailer.delivery_method = :onebillion
  #
  # The API key comes from ENV["ONEBILLION_API_KEY"]. The optional `onebillion_settings`
  # (`api_key:`, `url:`) win over the environment.
  #
  # It sends the finished MIME message (`raw`) to every envelope recipient (to, cc and bcc; Bcc
  # is not in the message). The Message-ID is the Idempotency-Key, so a retried job never sends
  # the mail twice.
  class DeliveryMethod
    attr_reader :settings

    def initialize(settings = {})
      @settings = settings
    end

    def deliver!(mail)
      client.send_mail(to: mail.smtp_envelope_to, raw: mail.encoded, idempotency_key: mail.message_id || SecureRandom.uuid)
    end

    private

    def client
      @client ||= Client.new(api_key: settings[:api_key] || OneBillion.api_key, url: settings[:url] || OneBillion.url, agent: "actionmailer")
    end
  end
end
