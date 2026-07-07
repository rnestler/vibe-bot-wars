# frozen_string_literal: true

# A registered bot: a name plus the external webhook URL that controls it. Runtime
# fields (position, hp, heading, ...) hold its state within the current match and are
# reset by Arena::Setup on a new match. Registration persists across matches.
class Bot < ApplicationRecord
  belongs_to :game, default: -> { Game.current }

  before_validation :normalize_webhook_url

  validates :name, presence: true, uniqueness: true
  # A trailing slash (e.g. "http://host:4000/") is fine — \S+ accepts it.
  validates :webhook_url, presence: true,
                          format: { with: %r{\Ahttps?://\S+\z}i, message: "must be an http(s) URL" }
  validates :heading, inclusion: { in: Game::HEADINGS }

  scope :active, -> { where(active: true) }

  def coordinates
    [x, y]
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
    self.webhook_url = webhook_url.strip if webhook_url.present?
  end
end
