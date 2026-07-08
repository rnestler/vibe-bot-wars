# frozen_string_literal: true

module Arena
  # Advances the arena by one tick:
  #   1. build each bot's sensor payload and POST all webhooks in parallel
  #   2. resolve every command simultaneously (move / scan / repair / idle)
  #   3. apply movement, collisions, damage and gem pickups
  #   4. advance the clock, persist, and broadcast the new state
  #
  # `client` is injectable for tests; it must respond to
  # `call(bot, payload, timeout_ms:)` and return a WebhookClient::Result-like object.
  class Tick
    def self.call(game, client: WebhookClient)
      new(game, client:).call
    end

    def initialize(game, client: WebhookClient)
      @game = game
      @client = client
    end

    def call
      return @game unless @game.running?

      @bots = @game.running_bots.to_a.select(&:placed?)
      @gems = @game.gems.map { |cell| [cell[0], cell[1]] }
      actions = gather_actions
      resolve(actions)
      advance_clock
      persist
      Broadcaster.call(@game, collisions: collision_cells)
      @game
    end

    # Cells that saw a crash this tick, for a brief highlight in the UI: the contested
    # cells of bot-bot collisions plus the recoil cells of bots that hit a wall/edge.
    def collision_cells
      (@collision_cells.to_a + @crashers.map(&:coordinates)).uniq
    end

    private

    # Fan out webhook calls across threads (no ActiveRecord touched inside them),
    # then reset each bot's vision radius to the default so a `scan` only lasts one tick.
    def gather_actions
      timeout_ms = @game.webhook_timeout_ms
      threads = @bots.map do |bot|
        payload = SensorPayload.call(
          game: @game, bot: bot, others: @bots - [bot], radius: bot.vision_radius
        )
        Thread.new { [bot, @client.call(bot, payload, timeout_ms:)] }
      end

      results = threads.to_h(&:value)
      @bots.each { |bot| bot.vision_radius = @game.vision_radius }
      results.transform_values { |result| interpret(result) }.tap do |actions|
        @bots.each { |bot| record_diagnostics(bot, results[bot], actions[bot]) }
      end
    end

    def interpret(result)
      return { type: "idle", error: result.error } unless result.ok?

      command = result.command
      return { type: "idle", error: "malformed command" } unless command.is_a?(Hash)

      case command["command"].to_s.downcase
      when "move"
        dir = command["dir"].to_s.upcase
        return { type: "idle", error: "invalid direction" } unless Game::DIRECTIONS.key?(dir)

        { type: "move", dir: dir }
      when "scan" then { type: "scan" }
      when "repair" then { type: "repair" }
      when "heal" then { type: "heal" }
      when "respawn" then { type: "respawn" }
      when "idle" then { type: "idle" }
      else { type: "idle", error: "unknown command" }
      end
    end

    def record_diagnostics(bot, result, action)
      bot.last_contacted_at = Time.current
      bot.last_error = action[:error] || result.error
      bot.last_command = action[:dir] ? "#{action[:type]}:#{action[:dir]}" : action[:type]
    end

    # Apply non-move commands immediately, collect movement intentions, then
    # resolve movement conflicts and damage. `@crashers` hit walls/borders;
    # `@collided` (a Set) covers blocked movers and rammed victims.
    def resolve(actions)
      @crashers = []
      @collision_opponents = Hash.new { |hash, bot| hash[bot] = Set.new } # bot => bots it hit
      @collision_cells = Set.new # contested cells, for the UI highlight
      intents = {} # bot => target [x, y]

      advance_cooldowns # tick down respawn cooldowns for every bot
      advance_lame_states # count down / revive lamed bots before they may act

      @bots.each do |bot|
        if bot.downed
          bot.last_command = "lamed" # lamed bots take no action at all
          next
        end
        if bot.blocked_ticks.positive? # blocked after a respawn: out of action, counting down
          bot.blocked_ticks -= 1
          bot.last_command = "blocked"
          next
        end

        action = actions[bot]
        case action[:type]
        when "repair" then bot.repair!(@game.repair_amount, bot.max_hp)
        when "heal" then heal_allies(bot)
        when "scan" then bot.vision_radius = @game.scan_radius
        when "respawn" then respawn(bot)
        when "move" then classify_move(bot, action[:dir], intents)
        end
      end

      movers = settle_conflicts(intents)
      apply_moves(movers)
      apply_damage
      replenish_gems # top the board back up to gem_count after pickups
    end

    def advance_cooldowns
      @bots.each { |bot| bot.respawn_cooldown -= 1 if bot.respawn_cooldown.positive? }
    end

    # A lamed bot is out of action until its timer runs out, then it revives at 1 HP.
    # (Healers can cut this short by healing it above 0 first — see Bot#repair!.)
    def advance_lame_states
      @bots.each do |bot|
        next unless bot.downed

        if bot.lamed_ticks <= 0
          revive(bot)
        else
          bot.lamed_ticks -= 1
        end
      end
    end

    def revive(bot)
      bot.hp = 1
      bot.downed = false
      bot.lamed_ticks = 0
      bot.blocked_ticks = 0
    end

    def classify_move(bot, dir, intents)
      dx, dy = Game::DIRECTIONS.fetch(dir)
      bot.heading = dir
      target = [bot.x + dx, bot.y + dy]
      if @game.open_cell?(*target)
        intents[bot] = target
      else
        @crashers << bot # wall or off-grid
      end
    end

    # Iteratively demote movers that would collide until the set is stable:
    #   - target cell occupied by a bot that is staying put
    #   - two+ movers targeting the same cell
    #   - two movers swapping cells
    # Survivors get to move; everyone demoted collides with whoever it ran into, so we
    # remember those opponents (their role decides how much damage each side takes).
    def settle_conflicts(intents)
      loop do
        occupied = occupied_cells(intents)
        counts = intents.values.tally
        bad = intents.keys.select do |bot|
          target = intents[bot]
          occupied.include?(target) || counts[target] > 1 || swapping?(bot, intents)
        end
        break if bad.empty?

        # Record before deleting; collisions are mutual, so a partner deleted earlier in
        # this pass has already been linked to everyone it hit.
        bad.each do |bot|
          record_collision(bot, intents)
          intents.delete(bot)
        end
      end
      intents
    end

    # Everything `bot` ran into: a staying occupant of its target, other movers aiming
    # at the same cell, and a swap partner. Collisions are mutual.
    def record_collision(bot, intents)
      target = intents[bot]
      @collision_cells << target # the contested cell — the point of impact
      occupant = @bots.find { |b| !intents.key?(b) && b.coordinates == target }
      same_target = intents.keys.select { |b| b != bot && intents[b] == target }
      swap_partner = intents.keys.find { |b| b != bot && b.coordinates == target && intents[b] == bot.coordinates }

      opponents = ([occupant, swap_partner] + same_target).compact.uniq
      opponents.each do |opponent|
        @collision_opponents[bot] << opponent
        @collision_opponents[opponent] << bot
      end
    end

    def occupied_cells(intents)
      @bots.reject { |bot| intents.key?(bot) }.to_set(&:coordinates)
    end

    def swapping?(bot, intents)
      intents.any? { |other, target| other != bot && target == bot.coordinates && intents[bot] == other.coordinates }
    end

    def apply_moves(movers)
      movers.each do |bot, target|
        bot.x, bot.y = target
        collect_gem(bot)
      end
    end

    def collect_gem(bot)
      return unless bot.collector? # only collectors can pick up gems

      cell = bot.coordinates
      return unless @gems.delete(cell)

      bot.gems_collected += 1
    end

    # A healer mends every same-group ally within its (current) vision radius, reviving
    # any that were downed. It never heals itself and stays put for the tick.
    def heal_allies(healer)
      return unless healer.healer?

      @bots.each do |ally|
        next if ally == healer || !ally.placed?
        next unless ally.group == healer.group && chebyshev(healer, ally) <= healer.vision_radius

        before = ally.hp
        ally.repair!(@game.heal_amount, ally.max_hp)
        healer.hp_restored += ally.hp - before # actual HP restored, ignoring overheal
      end
    end

    def chebyshev(a, b)
      [(a.x - b.x).abs, (a.y - b.y).abs].max
    end

    # Teleports the bot to a random free cell and restores its HP to at least half of max
    # (never lowering it), then blocks it for a short time as the cost. Refused while on
    # cooldown or if the board is full.
    def respawn(bot)
      return if bot.respawn_cooldown.positive?

      cell = free_cells.sample or return

      bot.x, bot.y = cell
      bot.hp = [bot.hp, bot.max_hp / 2].max
      bot.blocked_ticks = @game.respawn_block_ticks
      bot.respawn_cooldown = @game.respawn_cooldown_ticks
    end

    # Keeps at least gem_count gems on the board. Dropped loot can push the count above
    # gem_count; that excess is simply not topped up until it's collected back down.
    def replenish_gems
      while @gems.size < @game.gem_count
        cell = free_cells.sample or break

        @gems << cell
      end
    end

    # Cells not occupied by a wall, a placed bot, or a gem.
    def free_cells
      occupied = @game.walls.to_set { |c| [c[0], c[1]] }
      @bots.each { |b| occupied << b.coordinates if b.placed? }
      @gems.each { |c| occupied << c }
      (0...@game.width).to_a.product((0...@game.height).to_a) - occupied.to_a
    end

    def apply_damage
      @crashers.each do |bot|
        before = bot.hp
        bot.damage!(@game.wall_damage)
        knock_out(bot) if before.positive? && bot.hp.zero?
      end
      # Each bot takes the hardest hit among the bots it collided with; fighters hit harder.
      # Credit the actual HP lost to whoever landed that hit.
      @collision_opponents.each do |bot, opponents|
        dealer = opponents.max_by { |opponent| collision_damage_from(opponent) }
        before = bot.hp
        bot.damage!(collision_damage_from(dealer))
        dealer.damage_dealt += before - bot.hp
        knock_out(bot) if before.positive? && bot.hp.zero?
      end
    end

    # The moment a bot is knocked to 0 (not on later hits while down): start its lame timer
    # and, if it's a collector, spill the gems it was carrying back onto the map.
    def knock_out(bot)
      bot.lamed_ticks = @game.lame_ticks
      drop_gems(bot)
    end

    # A downed collector loses all its gems; they scatter onto the free cells nearest to
    # where it fell, so other bots can grab them.
    def drop_gems(bot)
      return unless bot.collector? && bot.gems_collected.positive?

      count = bot.gems_collected
      bot.gems_collected = 0
      nearest = free_cells.sort_by { |x, y| (x - bot.x).abs + (y - bot.y).abs }
      @gems.concat(nearest.first(count))
    end

    def collision_damage_from(bot)
      bot.fighter? ? @game.fighter_collision_damage : @game.collision_damage
    end

    def advance_clock
      @game.tick += 1
      @game.gems = @gems
      return unless @game.tick >= @game.max_ticks

      @game.status = "finished"
      @game.finished_at = Time.current
      # Use the in-memory bots (already updated this tick) rather than re-querying.
      @game.winner_bot = @bots.max_by(&:gems_collected)
    end

    def persist
      @game.transaction do
        @bots.each(&:save!)
        @game.save!
      end
    end
  end
end
