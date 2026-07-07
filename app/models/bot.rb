# frozen_string_literal: true

require "ipaddr"

# A registered bot: a name plus the external webhook URL that controls it. Runtime
# fields (position, hp, heading, ...) hold its state within the current match and are
# reset by Arena::Setup on a new match. Registration persists across matches.
class Bot < ApplicationRecord
  # Display names for the three groups (one per school class). Rename these labels to
  # whatever the classes should be called in the UI — the enum keys below stay the same.
  GROUP_LABELS = {
    "group_a" => "KSH 23a",
    "group_b" => "KBW 23a",
    "group_c" => "Group C"
  }.freeze

  # Role determines what a bot can do (see Arena::Tick). Only collectors score gems;
  # fighters are tougher and hit harder; healers mend same-group allies in range.
  ROLE_LABELS = {
    "collector" => "Collector",
    "fighter" => "Fighter",
    "healer" => "Healer"
  }.freeze

  belongs_to :game, default: -> { Game.current }

  enum :group, { group_a: 0, group_b: 1, group_c: 2 }, default: :group_a
  enum :role, { collector: 0, fighter: 1, healer: 2 }, default: :collector

  before_validation :normalize_webhook_url

  validates :name, presence: true, uniqueness: true
  validates :webhook_url, presence: true
  # The webhook must be an http(s) URL whose host is a literal IP address, and each device
  # (IP) may register only one bot. Port and path are ignored for the device check, so
  # http://10.0.0.5:4567/ and http://10.0.0.5:9000/tick count as the same device.
  validate :webhook_url_must_be_ip
  validate :webhook_host_is_unique
  validates :heading, inclusion: { in: Game::HEADINGS }

  scope :active, -> { where(active: true) }

  def coordinates
    [x, y]
  end

  # Human-readable group name for the UI (see GROUP_LABELS).
  def group_label
    GROUP_LABELS.fetch(group, group)
  end

  # Human-readable role name for the UI (see ROLE_LABELS).
  def role_label
    ROLE_LABELS.fetch(role, role)
  end

  def placed?
    x && y
  end

  # Applies damage, flooring HP at 0 and marking the bot as downed when it hits 0.
  def damage!(amount)
    self.hp = [hp - amount, 0].max
    self.downed = true if hp.zero?
  end

  # Heals up to max_hp; a bot that recovers above 0 HP is no longer downed.
  def repair!(amount, max_hp)
    self.hp = [hp + amount, max_hp].min
    self.downed = false if hp.positive?
  end

  private

  def normalize_webhook_url
    self.webhook_url = webhook_url.to_s.strip
    self.webhook_host = parse_ip_host(webhook_url)
  end

  # The normalized IP string of the URL's host, or nil if it isn't an http(s) URL that
  # points at a literal IP address (hostnames like "localhost" are rejected).
  def parse_ip_host(url)
    uri = URI.parse(url)
    return nil unless %w[http https].include?(uri.scheme)

    host = uri.host.to_s.delete_prefix("[").delete_suffix("]") # unwrap IPv6 [::1]
    IPAddr.new(host).to_s
  rescue URI::InvalidURIError, IPAddr::InvalidAddressError
    nil
  end

  def webhook_url_must_be_ip
    return if webhook_host.present?

    errors.add(:webhook_url, "must be an http(s) URL with an IP address, e.g. http://192.168.1.5:4567/")
  end

  def webhook_host_is_unique
    return if webhook_host.blank?

    duplicates = Bot.where(webhook_host: webhook_host)
    duplicates = duplicates.where.not(id: id) if persisted?
    return unless duplicates.exists?

    errors.add(:webhook_url, "device (#{webhook_host}) already has a bot — only one bot per device")
  end
end
