# frozen_string_literal: true

module Arena
  # End-of-match standings, per team (group). A group's score is its total gems divided by
  # team_size ** score_exponent: with an exponent of 1 that's a plain per-bot average, and
  # larger exponents handicap bigger teams more, reducing the advantage of extra bots.
  # Derived from the bots' current gem counts — nothing is persisted here.
  class Results
    def initialize(game)
      @game = game
    end

    # One entry per group, in GROUP_LABELS order, each with its size-handicapped score.
    def groups
      exponent = @game.score_exponent.to_f
      Bot::GROUP_LABELS.map do |key, label|
        members = @game.bots.select { |bot| bot.group == key }
        total = members.sum(&:gems_collected)
        {
          key: key,
          label: label,
          size: members.size,
          total: total,
          score: members.any? ? (total / (members.size**exponent)).round(2) : 0.0
        }
      end
    end

    # Groups ranked by score, highest first.
    def ranked_groups
      groups.sort_by { |group| -group[:score] }
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
          size: group[:size], total: group[:total], score: group[:score]
        }
      end
    end
  end
end
