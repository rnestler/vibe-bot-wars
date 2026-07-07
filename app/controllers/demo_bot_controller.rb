# frozen_string_literal: true

# A built-in reference bot. It implements the same webhook contract an external bot
# server would, so a match can run end-to-end with no external process: register a bot
# whose webhook URL points at POST /demo_bot. Strategy is a simple greedy gem-seeker
# that repairs when hurt and scans when it sees nothing.
class DemoBotController < ApplicationController
  skip_forgery_protection

  def respond
    payload = JSON.parse(request.body.read)
    render json: decide(payload)
  rescue JSON::ParserError
    render json: { command: "idle" }
  end

  private

  def decide(payload)
    me = payload["self"]
    vision = payload["vision"]

    return { command: "repair" } if me["downed"] || me["hp"] <= me["max_hp"] * 0.3

    gems = vision["gems"] || []
    if gems.any?
      { command: "move", dir: step_toward(me, nearest(me, gems), vision) }
    elsif vision["radius"].to_i <= 1
      { command: "scan" } # look further before committing to a direction
    else
      { command: "move", dir: safe_random_dir(me, vision) }
    end
  end

  def nearest(me, cells)
    cells.min_by { |(x, y)| (x - me["x"]).abs + (y - me["y"]).abs }
  end

  # One grid step toward a target, preferring the larger axis and avoiding known walls.
  def step_toward(me, target, vision)
    tx, ty = target
    candidates = []
    candidates << (tx > me["x"] ? "E" : "W") if tx != me["x"]
    candidates << (ty > me["y"] ? "S" : "N") if ty != me["y"]
    candidates.sort_by! { |dir| axis_distance(dir, me, target) }.reverse!
    candidates.find { |dir| !blocked?(me, dir, vision) } || candidates.first || "N"
  end

  def axis_distance(dir, me, target)
    %w[E W].include?(dir) ? (target[0] - me["x"]).abs : (target[1] - me["y"]).abs
  end

  def safe_random_dir(me, vision)
    Game::HEADINGS.shuffle.find { |dir| !blocked?(me, dir, vision) } || "N"
  end

  def blocked?(me, dir, vision)
    dx, dy = Game::DIRECTIONS.fetch(dir)
    (vision["walls"] || []).include?([me["x"] + dx, me["y"] + dy])
  end
end
