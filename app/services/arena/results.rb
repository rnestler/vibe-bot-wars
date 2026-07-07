# frozen_string_literal: true

module Arena
  # End-of-match standings. With supporting roles the score is per team (group), not per
  # bot: a group's score is its average gems per bot (groups differ in size, so the sum
  # would unfairly favour bigger groups). Derived from the bots' current gem counts —
  # nothing is persisted here.
  class Results
    def initialize(game)
      @game = game
    end

    # One entry per group, in GROUP_LABELS order, each with its average-gems score.
    def groups
      Bot::GROUP_LABELS.map do |key, label|
        members = @game.bots.select { |bot| bot.group == key }
        total = members.sum(&:gems_collected)
        {
          key: key,
          label: label,
          size: members.size,
          total: total,
          average: members.any? ? (total.to_f / members.size).round(2) : 0.0
        }
      end
    end

    # Groups ranked by score (average gems), highest first.
    def ranked_groups
      groups.sort_by { |group| -group[:average] }
    end

    # The key of the top-scoring group, or nil if no group has any bots.
    def winning_group
      best = ranked_groups.first
      best && best[:size].positive? ? best[:key] : nil
    end

    # JSON-friendly group summaries for broadcasting to the browser.
    def group_summaries
      groups.map do |group|
        {
          key: group[:key], label: group[:label],
          size: group[:size], total: group[:total], average: group[:average]
        }
      end
    end
  end
end
