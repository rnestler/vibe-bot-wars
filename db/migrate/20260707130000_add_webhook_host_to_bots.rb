# frozen_string_literal: true

require "ipaddr"

# Webhooks must point at a literal IP and each device (IP) may register only one bot.
# `webhook_host` holds the normalized IP derived from `webhook_url`; a unique index makes
# the "one bot per device" rule a database guarantee. Legacy rows whose webhook isn't an
# IP are left NULL (Postgres allows many NULLs under a unique index).
class AddWebhookHostToBots < ActiveRecord::Migration[8.1]
  def up
    add_column :bots, :webhook_host, :string
    Bot.reset_column_information
    Bot.find_each { |bot| bot.update_column(:webhook_host, ip_host(bot.webhook_url)) }
    add_index :bots, :webhook_host, unique: true
  end

  def down
    remove_index :bots, :webhook_host
    remove_column :bots, :webhook_host
  end

  private

  def ip_host(url)
    host = URI.parse(url.to_s).host.to_s.delete_prefix("[").delete_suffix("]")
    IPAddr.new(host).to_s
  rescue StandardError
    nil
  end
end
