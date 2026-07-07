# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # HTTP Basic auth for operator-only actions: the arena map, the match controls, and
  # deleting bots. Credentials come from ENV (defaults are fine for a local demo).
  def require_admin
    authenticate_or_request_with_http_basic("Bot Wars") do |user, password|
      ActiveSupport::SecurityUtils.secure_compare(user, admin_username) &
        ActiveSupport::SecurityUtils.secure_compare(password, admin_password)
    end
  end

  # Called when Basic auth is missing/declined. We still send the WWW-Authenticate
  # challenge so an operator gets the browser login prompt, but the 401 body bounces
  # anyone who doesn't log in over to /bots (where they can register a bot).
  def request_http_basic_authentication(realm = "Bot Wars", _message = nil)
    response.headers["WWW-Authenticate"] = %(Basic realm="#{realm.tr('"', "")}")
    render template: "shared/login_required", layout: false, status: :unauthorized
  end

  def admin_username
    ENV.fetch("ARENA_ADMIN_USER", "admin")
  end

  def admin_password
    ENV.fetch("ARENA_ADMIN_PASSWORD", "botwars")
  end

  # True when the request comes from the same device the bot's webhook points at (its IP
  # matches the request's). Lets a participant edit their own bot without the operator
  # password; any other request falls through to admin auth.
  def request_from_webhook_host?(bot)
    bot.webhook_host.present? && IPAddr.new(bot.webhook_host) == IPAddr.new(request.remote_ip)
  rescue IPAddr::InvalidAddressError
    false
  end
end
