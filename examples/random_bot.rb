#!/usr/bin/env ruby
# frozen_string_literal: true

# A standalone reference bot for Vibe Bot Wars — no gems required.
#
#   ruby examples/random_bot.rb [port]      # default port 4567
#
# It listens on all interfaces and prints its LAN URL, so register a bot in the UI with
# the http://<shown-ip>:4567/ webhook URL (reachable from the game server on the same
# WiFi) and start a match. It implements the same contract as the built-in /demo_bot:
# greedily heads
# for the nearest visible gem, repairs when hurt, scans when it sees nothing, and
# wanders randomly otherwise.

require "socket"
require "json"

PORT = (ARGV[0] || 4567).to_i
DIRS = { "N" => [0, -1], "E" => [1, 0], "S" => [0, 1], "W" => [-1, 0] }.freeze

def decide(payload)
  me = payload["self"] or return { command: "idle" }
  vision = payload["vision"] || {}
  walls = vision["walls"] || []
  gems = vision["gems"] || []

  return { command: "repair" } if me["downed"] || me["hp"] <= me["max_hp"].to_i * 0.3

  if gems.any?
    target = gems.min_by { |x, y| (x - me["x"]).abs + (y - me["y"]).abs }
    dir = step_toward(me, target, walls)
    { command: "move", dir: dir }
  elsif vision["radius"].to_i <= 1
    { command: "scan" }
  else
    { command: "move", dir: safe_random_dir(me, walls) }
  end
end

def step_toward(me, (tx, ty), walls)
  options = []
  options << (tx > me["x"] ? "E" : "W") if tx != me["x"]
  options << (ty > me["y"] ? "S" : "N") if ty != me["y"]
  options.find { |dir| !blocked?(me, dir, walls) } || options.first || "N"
end

def safe_random_dir(me, walls)
  DIRS.keys.shuffle.find { |dir| !blocked?(me, dir, walls) } || "N"
end

def blocked?(me, dir, walls)
  dx, dy = DIRS[dir]
  walls.include?([me["x"] + dx, me["y"] + dy])
end

# Best-guess LAN address to advertise (the private IPv4 of this machine), so the game
# server on the same WiFi can reach us. Falls back to localhost if none is found.
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

server = TCPServer.new("0.0.0.0", PORT)
puts "random_bot listening on http://#{local_ip}:#{PORT}/  (Ctrl-C to stop)"

loop do
  client = server.accept
  body = read_request(client)
  command =
    begin
      decide(JSON.parse(body))
    rescue JSON::ParserError
      { command: "idle" }
    end
  json = JSON.generate(command)
  client.write "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" \
               "Content-Length: #{json.bytesize}\r\nConnection: close\r\n\r\n#{json}"
  client.close
rescue Interrupt
  break
rescue StandardError => e
  warn "random_bot error: #{e.message}"
  client&.close
end

puts "\nrandom_bot stopped"
