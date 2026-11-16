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

  # 402: no credits for these recipients. `body["buy_url"]` is the page to buy more.
  class NoCredits < Error; end

  # 422: a bad message, a domain that is not verified, or a recipient that failed a check.
  class Refused < Error
    def check = body["check"]

    def address = body["address"]
  end
end
