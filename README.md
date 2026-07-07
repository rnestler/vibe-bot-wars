# Vibe Bot Wars

A real-time bot battle arena. The Rails app runs the game — a discrete grid where bots
collect gems and crash into walls and each other — while each **bot is controlled by an
external server** reached over a **webhook**. Every tick the game sends each bot its
sensor readings and the bot answers with a command.

## How it works

- The arena is an **N×N grid**. Bots move one cell per tick (N/E/S/W).
- Each tick (~500 ms) the game **POSTs sensor data to every bot's webhook in parallel**,
  collects the commands (with a short timeout), and applies them **simultaneously**.
- **Gems** spawn randomly; collecting one scores a point and respawns another elsewhere.
- Crashing into a **wall**, the **arena edge**, or **another bot** costs HP. At 0 HP a bot
  is **downed** and must `repair` before it can move again — it is never eliminated.
- A match runs for a fixed number of ticks; the **winner is whoever collected the most
  gems**.
- The live arena + scoreboard update over Action Cable (WebSockets).

## Running it

Requires Ruby (see `.ruby-version`), PostgreSQL, and [foreman](https://github.com/ddollar/foreman)
(`gem install foreman`).

```bash
bin/setup            # install gems, create & migrate the database
bin/dev              # starts the web server AND the arena game loop
```

`bin/dev` runs two processes (see `Procfile.dev`):

- `web` — the Rails server / UI at http://localhost:3000
- `game` — `bin/rake arena:run`, the real-time loop that ticks the arena

The game loop **must** run as its own process; without it, matches won't advance.

The web server binds to `0.0.0.0`, so others on the same WiFi/LAN can reach it at
`http://<your-machine-ip>:3000`. (Development host checking is disabled for this; don't
run the dev server on an untrusted network.)

## Access control

- The **arena map and match controls** (start/stop) are protected by **HTTP Basic auth**.
  Credentials come from `ARENA_ADMIN_USER` / `ARENA_ADMIN_PASSWORD` (defaults: `admin` /
  `botwars`). Set them in the environment for anything beyond a local demo.
- **Registering** a bot is open to everyone — participants add their own.
- **Deleting** a bot is operator-only (Basic auth).
- **Editing** a bot is allowed without a password when the request comes from the same host
  the bot's webhook points at (i.e. the machine running that bot). Otherwise it falls back
  to operator auth. This is a convenience for LAN demos, not a hard security boundary — if
  everyone shares one public IP (NAT), they can edit each other's bots, so keep the operator
  password for the real gate.

Then, in the UI:

1. **Add a bot** and point its webhook URL at your server — or at the built-in reference
   bot (`POST /demo_bot`) to try things out immediately.
2. Click **New match** to lay out the arena and start ticking.

To run an external reference bot in another terminal:

```bash
ruby examples/random_bot.rb 4567   # simple greedy collector
ruby examples/smart_bot.rb  4568   # role-aware: plays collector / fighter / healer
```

Both listen on all interfaces and print their LAN URL to register. `smart_bot.rb` reads its
own `role` from each tick and plays it: collectors chase gems and dodge bots, fighters hunt
and ram enemy collectors, healers shadow wounded allies and `heal` them in range.

## Webhook contract

Each tick the game sends your bot a `POST` with `Content-Type: application/json`
(and, if you set a shared secret, an `X-Bot-Secret` header):

```json
{
  "game_id": 1, "tick": 42,
  "arena": { "width": 20, "height": 20 },
  "self":  { "id": 3, "name": "Ada", "x": 5, "y": 7, "heading": "N",
             "hp": 80, "max_hp": 100, "gems": 4, "downed": false },
  "vision": {
    "radius": 1,
    "walls": [[5, 6]],
    "gems":  [[6, 7]],
    "bots":  [{ "x": 4, "y": 7, "hp": 60, "downed": false }]
  }
}
```

Coordinates are absolute (origin top-left; +x east, +y south). `vision` is a square radius
around you — **1 by default**, and the larger `scan_radius` on the tick *after* you `scan`.

Respond within the timeout with **one** command:

```json
{ "command": "move", "dir": "N" }   // N | E | S | W — move one cell
{ "command": "scan" }               // stay put; get a bigger vision sweep next tick
{ "command": "repair" }             // stay put; heal some HP
{ "command": "idle" }               // do nothing
```

No response, a late response, or invalid JSON is treated as `idle` for that tick, and the
error is shown next to your bot in the UI. Downed bots (0 HP) may only `repair` until they
recover.

## Code map

- `app/models/{game,bot}.rb` — the arena (a single persistent row) and registered bots.
- `app/services/arena/` — `setup` (start a match), `sensor_payload` (build vision),
  `tick` (the engine: fan out webhooks, resolve moves/collisions/gems, advance),
  `broadcaster` (push state to the UI).
- `app/services/webhook_client.rb` — posts to a bot's webhook with timeouts.
- `lib/tasks/arena.rake` — the `arena:run` real-time loop.
- `app/controllers/` — `arena` (live page), `bots` (CRUD + webhook test),
  `matches` (start/stop), `demo_bot` (built-in reference bot).
- `app/javascript/controllers/arena_controller.js` — canvas renderer + scoreboard.
- `examples/random_bot.rb` — a standalone, dependency-free reference bot.

## Tests

```bash
bin/rails test
```

Game-logic tests inject a stub webhook client, so they need no network. The
`WebhookClient` tests exercise real HTTP against a throwaway local server.
