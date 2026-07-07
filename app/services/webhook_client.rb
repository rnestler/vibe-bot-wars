# frozen_string_literal: true

require "net/http"
require "json"

# Posts a sensor payload to a bot's external webhook and returns its command.
# Uses stdlib Net::HTTP with tight timeouts. Never raises: any failure (timeout,
# connection error, non-2xx, invalid JSON) comes back as a Result with an `error`,
# which the tick engine treats as an idle turn.
#
# Note: instances touch no ActiveRecord, so this is safe to call from the tick
# engine's per-bot threads (only loaded attributes + the passed timeout are used).
class WebhookClient
  Result = Struct.new(:command, :error) do
    def ok?
      error.nil?
    end
  end

  def self.call(bot, payload, timeout_ms:)
    new(bot).call(payload, timeout_ms:)
  end

  def initialize(bot)
    @bot = bot
  end

  def call(payload, timeout_ms:)
    uri = URI.parse(@bot.webhook_url)
    timeout = timeout_ms / 1000.0

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout
    http.read_timeout = timeout
    http.write_timeout = timeout if http.respond_to?(:write_timeout=)

    response = http.request(build_request(uri, payload))
    return Result.new(error: "HTTP #{response.code}") unless response.is_a?(Net::HTTPSuccess)

    Result.new(command: JSON.parse(response.body))
  rescue Timeout::Error # Net::OpenTimeout/ReadTimeout/WriteTimeout all subclass this
    Result.new(error: "timeout")
  rescue JSON::ParserError
    Result.new(error: "invalid JSON response")
  rescue StandardError => e
    Result.new(error: e.message.to_s[0, 120])
  end

  private

  def build_request(uri, payload)
    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["X-Bot-Secret"] = @bot.secret if @bot.secret.present?
    request.body = payload.to_json
    request
  end
end
