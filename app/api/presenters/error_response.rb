class ErrorResponse
  attr_reader :message, :code, :status

  def initialize(message:, code: "error", status: 400)
    @message = message
    @code = code
    @status = status
  end

  def to_h
    {
      message: message,
      error_code: code,
      status: status
    }
  end
end
