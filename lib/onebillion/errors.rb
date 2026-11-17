module OneBillion
  # Any answer that is not a success. `status` is the HTTP status (nil for a network error)
  # and `body` the parsed JSON, with `error` and, for a 422 of a check, `check` and `address`.
  class Error < StandardError
    attr_reader :status, :body

    def initialize(message, status: nil, body: {})
      @status = status
      @body = body

      super(message)
    end
  end

  # 429: no credits for these recipients today. `body["retry_after"]` is the seconds until the
  # credits of the next day (00:00 UTC), and `body["buy_url"]` the page to buy a pack.
  class NoCredits < Error; end

  # 422: a bad message, a domain that is not verified, or a recipient that failed a check.
  class Refused < Error
    def check = body["check"]

    def address = body["address"]
  end
end
