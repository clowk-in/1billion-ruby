require_relative "onebillion/version"
require_relative "onebillion/errors"
require_relative "onebillion/client"
require_relative "onebillion/delivery_method"
require_relative "onebillion/emails"
require_relative "onebillion/signature"

# 1billion: transactional e-mail. See OneBillion::Client, OneBillion::Emails,
# OneBillion::Signature and OneBillion::DeliveryMethod.
#
# The API key comes from ENV["ONEBILLION_API_KEY"] and the base URL from ENV["ONEBILLION_URL"],
# unless you set OneBillion.api_key or OneBillion.url.
module OneBillion
  class << self
    def api_key = @api_key || ENV["ONEBILLION_API_KEY"]

    def url = @url || ENV["ONEBILLION_URL"] || Client::DEFAULT_URL

    def api_key=(value)
      @api_key = value
      @client = nil
    end

    def url=(value)
      @url = value
      @client = nil
    end

    # The client of OneBillion::Emails, made from OneBillion.api_key and OneBillion.url.
    attr_writer :client

    def client = @client ||= Client.new
  end
end

if defined?(ActionMailer)
  ActionMailer::Base.add_delivery_method(:onebillion, OneBillion::DeliveryMethod)
elsif defined?(ActiveSupport)
  ActiveSupport.on_load(:action_mailer) { add_delivery_method(:onebillion, OneBillion::DeliveryMethod) }
end
