# frozen_string_literal: true

require "test_helper"
require "socket"

class WebhookClientTest < ActiveSupport::TestCase
  # Loading net/http eagerly pulls in resolv, which raises in sandboxes where
  # /etc/resolv.conf is unreadable. Guard so the rest of the suite still runs there;
  # WebhookClient is only referenced inside the (skipped) test bodies.
  NET_HTTP = begin
    require "net/http"
    true
  rescue StandardError
    false
  end

  setup { skip "net/http unavailable in this environment" unless NET_HTTP }

  test "parses a JSON command from a 200 response" do
    with_server(body: '{"command":"move","dir":"N"}') do |url|
      result = WebhookClient.call(bot(url), { ping: 1 }, timeout_ms: 500)
      assert result.ok?
      assert_equal({ "command" => "move", "dir" => "N" }, result.command)
    end
  end

  test "reports non-2xx responses as errors" do
    with_server(status: 500) do |url|
      result = WebhookClient.call(bot(url), {}, timeout_ms: 500)
      assert_not result.ok?
      assert_equal "HTTP 500", result.error
    end
  end

  test "reports invalid JSON bodies as errors" do
    with_server(body: "not json") do |url|
      result = WebhookClient.call(bot(url), {}, timeout_ms: 500)
      assert_equal "invalid JSON response", result.error
    end
  end

  test "times out slow webhooks" do
    with_server(delay: 1.0) do |url|
      result = WebhookClient.call(bot(url), {}, timeout_ms: 150)
      assert_equal "timeout", result.error
    end
  end

  private

  def bot(url)
    Bot.new(name: "T", webhook_url: url)
  end

  def with_server(status: 200, body: '{"command":"idle"}', delay: 0)
    server = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      client = server.accept
      drain_request(client)
      sleep(delay) if delay.positive?
      client.write "HTTP/1.1 #{status} Status\r\nContent-Type: application/json\r\n" \
                   "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
      client.close
    rescue IOError, Errno::EPIPE
      # client hung up (e.g. after a timeout) — fine
    end
    yield "http://127.0.0.1:#{server.addr[1]}/"
  ensure
    thread&.kill
    server&.close
  end

  def drain_request(client)
    client.gets
    length = 0
    while (line = client.gets) && line != "\r\n"
      key, value = line.split(":", 2)
      length = value.to_i if value && key.strip.casecmp("content-length").zero?
    end
    client.read(length) if length.positive?
  end
end
