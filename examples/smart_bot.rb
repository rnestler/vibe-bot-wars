#!/usr/bin/env ruby
# frozen_string_literal: true

# A smart, role-aware reference bot for Vibe Bot Wars — no gems required.
#
#   ruby examples/smart_bot.rb [port]      # default port 4568
#
# It listens on all interfaces and prints its LAN URL. Register ONE bot (with the role
# you want) and point its webhook at http://<shown-ip>:4568/. The bot reads its own role
# from each tick's payload and plays accordingly:
#
#   * collector — heads for the nearest visible gem, steers around other bots (it's
#                 fragile), repairs when hurt, and scans to look further when idle.
#   * fighter   — hunts enemy bots (preferring enemy collectors) and rams them for heavy
#                 collision damage; escorts allies when no enemy is in sight.
#   * healer    — shadows wounded same-group allies and `heal`s them once they're in range;
#                 repairs itself when low.
#
# All three fall back to `scan` to see further and to safe wandering when there's nothing
# to do. This is intentionally readable, not optimal — a starting point to improve on.

require "socket"
require "json"

PORT = (ARGV[0] || 4568).to_i
DIRS = { "N" => [0, -1], "E" => [1, 0], "S" => [0, 1], "W" => [-1, 0] }.freeze

# ---- decision entry point -------------------------------------------------------------

def decide(payload)
  me = payload["self"] or return { command: "idle" }
  vision = payload["vision"] || {}
  arena = payload["arena"] || {}
  return { command: "repair" } if me["downed"] # downed bots may only repair

  case me["role"]
  when "fighter" then fighter(me, vision, arena)
  when "healer" then healer(me, vision, arena)
  else collector(me, vision, arena)
  end
end

# ---- per-role strategies --------------------------------------------------------------

def collector(me, vision, arena)
  return { command: "repair" } if low?(me, 0.35)

  gems = vision["gems"] || []
  blocked = walls_and_bots(vision) # collectors avoid every bot; a collision hurts
  if gems.any?
    gem = nearest_cell(me, gems)
    dir = toward(me, arena, gem[0], gem[1], blocked)
    return { command: "move", dir: dir } if dir
  end

  look_further_or_wander(me, vision, arena, blocked)
end

def fighter(me, vision, arena)
  return { command: "repair" } if low?(me, 0.2) # big HP pool, so only bail out when really low

  target = pick_enemy(me, enemies(me, vision))
  if target
    ram = ram_dir(me, target)
    return { command: "move", dir: ram } if ram # adjacent: charge in and deal damage

    # Close in, avoiding walls and other bots but NOT the target (we want to hit it).
    lane = walls(vision) + bots(vision).reject { |c| c == [target["x"], target["y"]] }
    dir = toward(me, arena, target["x"], target["y"], lane)
    return { command: "move", dir: dir } if dir
  end

  # No enemy in sight: stick near an ally, otherwise look further / patrol.
  ally = nearest_bot(me, allies(me, vision))
  blocked = walls_and_bots(vision)
  if ally
    dir = toward(me, arena, ally["x"], ally["y"], blocked)
    return { command: "move", dir: dir } if dir
  end
  look_further_or_wander(me, vision, arena, blocked)
end

def healer(me, vision, arena)
  return { command: "repair" } if low?(me, 0.35)

  radius = vision["radius"] || 1
  wounded = allies(me, vision).select { |b| hurt?(b) }
  in_range = wounded.select { |b| chebyshev(me, b["x"], b["y"]) <= radius }
  return { command: "heal" } if in_range.any? # heal reaches every ally within our vision

  blocked = walls_and_bots(vision)
  follow = nearest_bot(me, wounded.any? ? wounded : allies(me, vision))
  if follow
    dir = toward(me, arena, follow["x"], follow["y"], blocked)
    return { command: "move", dir: dir } if dir
  end
  look_further_or_wander(me, vision, arena, blocked)
end

# ---- shared helpers -------------------------------------------------------------------

def look_further_or_wander(me, vision, arena, blocked)
  return { command: "scan" } if (vision["radius"] || 1) <= 1

  dir = wander(me, arena, blocked)
  dir ? { command: "move", dir: dir } : { command: "idle" }
end

# Step one cell toward (tx, ty): try the larger-gap axis first, then the other axis, then
# any open direction so we don't get stuck. Returns a direction or nil if fully boxed in.
def toward(me, arena, tx, ty, blocked)
  dx = tx - me["x"]
  dy = ty - me["y"]
  preferred = []
  preferred << (dx.positive? ? "E" : "W") if dx.nonzero?
  preferred << (dy.positive? ? "S" : "N") if dy.nonzero?
  preferred.sort_by! { |dir| horizontal?(dir) ? -dx.abs : -dy.abs }
  (preferred + (DIRS.keys - preferred)).find { |dir| open?(me, arena, dir, blocked) }
end

def wander(me, arena, blocked)
  ([me["heading"]] + DIRS.keys.shuffle).compact.find { |dir| open?(me, arena, dir, blocked) }
end

def open?(me, arena, dir, blocked)
  dx, dy = DIRS.fetch(dir)
  nx = me["x"] + dx
  ny = me["y"] + dy
  return false if nx.negative? || ny.negative?
  return false if arena["width"] && (nx >= arena["width"] || ny >= arena["height"])

  !blocked.include?([nx, ny]) # rubocop:disable Rails/NegateInclude -- no ActiveSupport here
end

def horizontal?(dir)
  %w[E W].include?(dir)
end

def ram_dir(me, target)
  DIRS.each { |dir, (dx, dy)| return dir if me["x"] + dx == target["x"] && me["y"] + dy == target["y"] }
  nil
end

def pick_enemy(me, foes)
  collectors = foes.select { |b| b["role"] == "collector" }
  nearest_bot(me, collectors.any? ? collectors : foes)
end

def enemies(me, vision)
  (vision["bots"] || []).reject { |b| b["group"] == me["group"] || b["downed"] }
end

def allies(me, vision)
  # Your own bot is never in your vision, so every same-group bot here is a teammate.
  (vision["bots"] || []).select { |b| b["group"] == me["group"] }
end

def walls(vision)
  vision["walls"] || []
end

def bots(vision)
  (vision["bots"] || []).map { |b| [b["x"], b["y"]] }
end

def walls_and_bots(vision)
  walls(vision) + bots(vision)
end

def hurt?(bot)
  bot["downed"] || bot["hp"] < (bot["max_hp"] || 100)
end

def low?(me, fraction)
  me["hp"] <= (me["max_hp"] || 100) * fraction
end

def nearest_cell(me, cells)
  cells.min_by { |x, y| manhattan(me, x, y) }
end

def nearest_bot(me, list)
  list.min_by { |b| manhattan(me, b["x"], b["y"]) }
end

def manhattan(me, x, y)
  (me["x"] - x).abs + (me["y"] - y).abs
end

def chebyshev(me, x, y)
  [(me["x"] - x).abs, (me["y"] - y).abs].max
end

# ---- tiny HTTP server (identical scaffold to random_bot.rb) ---------------------------

def local_ip
  Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address || "127.0.0.1"
end

def read_request(client)
  client.gets # request line
  length = 0
  while (line = client.gets) && line != "\r\n"
    key, value = line.split(":", 2)
    length = value.to_i if value && key.strip.casecmp("content-length").zero?
  end
  length.positive? ? client.read(length).to_s : ""
end

def log(direction, data)
  # Standalone script: no ActiveSupport, so Time.now (not Time.current) is correct here.
  puts "#{Time.now.strftime("%H:%M:%S")} #{direction} #{data}" # rubocop:disable Rails/TimeZone
end

server = TCPServer.new("0.0.0.0", PORT)
puts "smart_bot listening on http://#{local_ip}:#{PORT}/  (Ctrl-C to stop)"

loop do
  client = server.accept
  body = read_request(client)
  command =
    begin
      payload = JSON.parse(body)
      log("in  <-", JSON.generate(payload))
      decide(payload)
    rescue JSON::ParserError
      log("in  <-", "invalid JSON: #{body.inspect}")
      { command: "idle" }
    end
  json = JSON.generate(command)
  log("out ->", json)
  client.write "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" \
               "Content-Length: #{json.bytesize}\r\nConnection: close\r\n\r\n#{json}"
  client.close
rescue Interrupt
  break
rescue StandardError => e
  warn "smart_bot error: #{e.message}"
  client&.close
end

puts "\nsmart_bot stopped"
