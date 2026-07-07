# frozen_string_literal: true

module Arena
  # End-of-match standings, also useful live: the best bot overall, the best bot in each
  # group, and a per-group score. Groups have different sizes, so the group score is the
  # average gems per bot (total is exposed too). Purely derived from the bots' current
  # gem counts — nothing is persisted here.
  class Results
    def initialize(game)
      @game = game
    end

    # Bots ranked by gems collected, highest first.
    def ranked
      @ranked ||= @game.bots.to_a.sort_by { |bot| -bot.gems_collected }
    end

    # The single best bot across all groups (nil if there are no bots).
    def overall_best
      ranked.first
    end

    # One entry per group, in GROUP_LABELS order. `best` is the group's top bot (or nil).
    def groups
      Bot::GROUP_LABELS.map do |key, label|
        members = ranked.select { |bot| bot.group == key }
        total = members.sum(&:gems_collected)
        {
          key: key,
          label: label,
          size: members.size,
          total: total,
          average: members.any? ? (total.to_f / members.size).round(2) : 0.0,
          best: members.first
        }
      end
    end

    # JSON-friendly group summaries for broadcasting to the browser.
    def group_summaries
      groups.map do |group|
        best = group[:best]
        {
          key: group[:key], label: group[:label], size: group[:size],
          total: group[:total], average: group[:average],
          best_bot_id: best&.id, best_bot_name: best&.name, best_bot_gems: best&.gems_collected
        }
      end
    end
  end
end
