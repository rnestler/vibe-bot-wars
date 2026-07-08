import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

// Renders the live arena on a <canvas> and keeps the scoreboard in sync. Initial
// state comes from the server via the `state` value; subsequent ticks arrive over
// ArenaChannel (broadcast by Arena::Broadcaster).
export default class extends Controller {
  static targets = ["canvas", "scoreboard", "tick", "status", "results"]
  static values = { state: Object }

  connect() {
    this.cell = 26
    this.bots = []
    this.tooltip = this.buildTooltip()
    this.onPointerMove = (event) => this.showBotTooltip(event)
    this.onPointerLeave = () => this.hideTooltip()
    this.canvasTarget.addEventListener("mousemove", this.onPointerMove)
    this.canvasTarget.addEventListener("mouseleave", this.onPointerLeave)
    this.render(this.stateValue)
    this.subscription = consumer.subscriptions.create("ArenaChannel", {
      received: (data) => this.render(data),
    })
  }

  disconnect() {
    if (this.subscription) this.subscription.unsubscribe()
    this.canvasTarget.removeEventListener("mousemove", this.onPointerMove)
    this.canvasTarget.removeEventListener("mouseleave", this.onPointerLeave)
    if (this.tooltip) this.tooltip.remove()
  }

  render(state) {
    if (!state || !state.width) return
    this.bots = state.bots || []
    this.drawGrid(state)
    this.updateScoreboard(state)
    this.updateResults(state)
    if (this.hasTickTarget) this.tickTarget.textContent = `${state.tick} / ${state.max_ticks}`
    if (this.hasStatusTarget) this.statusTarget.textContent = this.statusLabel(state)
  }

  buildTooltip() {
    const el = document.createElement("div")
    el.className = "arena-tooltip"
    el.style.display = "none"
    document.body.appendChild(el)
    return el
  }

  // Maps the cursor to a grid cell and, if a bot sits there, shows its name near the cursor.
  showBotTooltip(event) {
    const canvas = this.canvasTarget
    const rect = canvas.getBoundingClientRect()
    const gx = Math.floor(((event.clientX - rect.left) * (canvas.width / rect.width)) / this.cell)
    const gy = Math.floor(((event.clientY - rect.top) * (canvas.height / rect.height)) / this.cell)
    const bot = this.bots.find((b) => b.x === gx && b.y === gy)

    if (!bot) {
      this.hideTooltip()
      canvas.style.cursor = "default"
      return
    }
    canvas.style.cursor = "pointer"
    this.tooltip.innerHTML =
      `<b>${this.escape(bot.name)}</b>` +
      `<span>${this.escape(bot.role_label || "")} · ${this.escape(bot.group_label || "")}</span>`
    this.tooltip.style.display = "block"
    this.tooltip.style.left = `${event.clientX + 12}px`
    this.tooltip.style.top = `${event.clientY + 12}px`
  }

  hideTooltip() {
    if (this.tooltip) this.tooltip.style.display = "none"
    this.canvasTarget.style.cursor = "default"
  }

  statusLabel(state) {
    if (state.status === "finished") {
      const winner = (state.bots || []).find((b) => b.id === state.winner_bot_id)
      return winner ? `Finished — winner: ${winner.name}` : "Finished"
    }
    return state.status === "running" ? "Running" : "Idle"
  }

  drawGrid(state) {
    const canvas = this.canvasTarget
    const c = this.cell
    canvas.width = state.width * c
    canvas.height = state.height * c
    const ctx = canvas.getContext("2d")

    ctx.fillStyle = "#0f172a"
    ctx.fillRect(0, 0, canvas.width, canvas.height)

    ctx.strokeStyle = "rgba(148,163,184,0.15)"
    for (let x = 0; x <= state.width; x++) this.line(ctx, x * c, 0, x * c, canvas.height)
    for (let y = 0; y <= state.height; y++) this.line(ctx, 0, y * c, canvas.width, y * c)

    ctx.fillStyle = "#334155"
    for (const [x, y] of state.walls || []) ctx.fillRect(x * c, y * c, c, c)

    for (const [x, y] of state.gems || []) this.drawGem(ctx, x, y)

    for (const bot of state.bots || []) if (bot.x != null) this.drawBot(ctx, bot)

    // Drawn last so a crash shows even on a cell occupied by a bot; cleared next tick.
    for (const [x, y] of state.collisions || []) this.drawCollision(ctx, x, y)
  }

  drawCollision(ctx, x, y) {
    const c = this.cell
    ctx.fillStyle = "rgba(248,113,113,0.35)"
    ctx.fillRect(x * c, y * c, c, c)
    ctx.strokeStyle = "rgba(248,113,113,0.95)"
    ctx.lineWidth = 3
    ctx.strokeRect(x * c + 1.5, y * c + 1.5, c - 3, c - 3)
    ctx.lineWidth = 1
  }

  line(ctx, x1, y1, x2, y2) {
    ctx.beginPath()
    ctx.moveTo(x1, y1)
    ctx.lineTo(x2, y2)
    ctx.stroke()
  }

  drawGem(ctx, x, y) {
    const c = this.cell
    const cx = x * c + c / 2
    const cy = y * c + c / 2
    const r = c * 0.28
    ctx.fillStyle = "#22d3ee"
    ctx.beginPath()
    ctx.moveTo(cx, cy - r)
    ctx.lineTo(cx + r, cy)
    ctx.lineTo(cx, cy + r)
    ctx.lineTo(cx - r, cy)
    ctx.closePath()
    ctx.fill()
  }

  drawBot(ctx, bot) {
    const c = this.cell
    const cx = bot.x * c + c / 2
    const cy = bot.y * c + c / 2
    const r = c * 0.36
    const color = this.botColor(bot.id)

    ctx.globalAlpha = bot.downed ? 0.4 : 1
    ctx.fillStyle = color
    ctx.beginPath()
    ctx.arc(cx, cy, r, 0, Math.PI * 2)
    ctx.fill()

    // Heading pointer.
    const [dx, dy] = { N: [0, -1], E: [1, 0], S: [0, 1], W: [-1, 0] }[bot.heading] || [0, -1]
    ctx.strokeStyle = "#f8fafc"
    ctx.lineWidth = 2
    this.line(ctx, cx, cy, cx + dx * r, cy + dy * r)

    // HP arc.
    const frac = Math.max(0, bot.hp / (bot.max_hp || 100))
    ctx.strokeStyle = frac > 0.3 ? "#4ade80" : "#f87171"
    ctx.lineWidth = 3
    ctx.beginPath()
    ctx.arc(cx, cy, r + 3, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac)
    ctx.stroke()

    ctx.globalAlpha = 1
    ctx.lineWidth = 1

    // Name label above the bot, outlined for readability over any background.
    ctx.font = "600 10px system-ui, -apple-system, sans-serif"
    ctx.textAlign = "center"
    ctx.textBaseline = "bottom"
    ctx.lineWidth = 3
    ctx.strokeStyle = "rgba(15,23,42,0.9)"
    ctx.strokeText(bot.name, cx, cy - r - 3)
    ctx.fillStyle = "#e2e8f0"
    ctx.fillText(bot.name, cx, cy - r - 3)
    ctx.lineWidth = 1
    ctx.textAlign = "start"
    ctx.textBaseline = "alphabetic"
  }

  // One table per role, each showing only that role's own score column, sorted by group
  // then by score (highest first).
  updateScoreboard(state) {
    if (!this.hasScoreboardTarget) return
    const bots = state.bots || []
    const tables = [
      { role: "collector", title: "Collectors", metric: "Gems", value: (b) => b.gems || 0 },
      { role: "fighter", title: "Fighters", metric: "Dmg", value: (b) => b.damage_dealt || 0 },
      { role: "healer", title: "Healers", metric: "Healed", value: (b) => b.hp_restored || 0 },
    ]
    this.scoreboardTarget.innerHTML = tables.map((t) => this.roleTable(t, bots)).join("")
  }

  roleTable(config, bots) {
    const rows = bots
      .filter((b) => b.role === config.role)
      .sort((a, b) => (a.group || "").localeCompare(b.group || "") || config.value(b) - config.value(a))
    const body = rows.length
      ? rows.map((b) => this.scoreRow(b, config.value(b))).join("")
      : `<tr><td colspan="5" class="muted">No ${config.title.toLowerCase()} yet.</td></tr>`
    return `
      <h3 class="score-title">${config.title}</h3>
      <table class="score">
        <thead>
          <tr><th>Bot</th><th>Group</th><th class="num">${config.metric}</th><th>HP</th><th>Last</th></tr>
        </thead>
        <tbody>${body}</tbody>
      </table>`
  }

  scoreRow(bot, points) {
    const frac = Math.max(0, Math.round((bot.hp / (bot.max_hp || 100)) * 100))
    const status = bot.downed
      ? `<span class="tag tag--downed">lamed ${bot.lamed_ticks}</span>`
      : bot.last_error
        ? `<span class="tag tag--error" title="${this.escape(bot.last_error)}">error</span>`
        : `<span class="tag">${this.escape(bot.last_command || "—")}</span>`
    return `
      <tr>
        <td><span class="swatch" style="background:${this.botColor(bot.id)}"></span>${this.escape(bot.name)}</td>
        <td>${this.escape(bot.group_label || "—")}</td>
        <td class="num is-score">${points}</td>
        <td><div class="hpbar"><div class="hpbar__fill" style="width:${frac}%"></div></div></td>
        <td>${status}</td>
      </tr>`
  }

  // Team scores only: each group ranked by its average gems per bot. Highlights the
  // leading (or, once finished, winning) group.
  // Prominent team standings (big score per group), with a winner banner once finished.
  updateResults(state) {
    if (!this.hasResultsTarget) return
    const groups = [...(state.groups || [])].sort((a, b) => b.average - a.average)
    if (groups.every((g) => g.size === 0)) {
      this.resultsTarget.style.display = "none"
      this.resultsTarget.innerHTML = ""
      return
    }
    this.resultsTarget.style.display = ""

    const finished = state.status === "finished"
    const winner = groups.find((g) => g.key === state.winning_group && g.size > 0)
    const banner =
      finished && winner ? `<div class="winner-banner">🏆 ${this.escape(winner.label)} wins!</div>` : ""

    const cards = groups
      .map((g, i) => {
        const isWinner = g.key === state.winning_group && g.size > 0
        return `
        <div class="teamcard${isWinner ? " is-winner" : ""}">
          <div class="teamcard__rank">#${i + 1}</div>
          <div class="teamcard__name">${this.escape(g.label)}</div>
          <div class="teamcard__score">${g.average}</div>
          <div class="teamcard__meta">${g.total} gems · ${g.size} bots</div>
        </div>`
      })
      .join("")

    this.resultsTarget.innerHTML = `
      <div class="teamscores__head">
        <h2>${finished ? "Final team scores" : "Team scores"}</h2>
        <span class="muted">avg gems per bot</span>
      </div>
      ${banner}
      <div class="teamcards">${cards}</div>`
  }

  botColor(id) {
    const palette = ["#f97316", "#a78bfa", "#34d399", "#f472b6", "#facc15", "#60a5fa", "#fb7185", "#2dd4bf"]
    return palette[id % palette.length]
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text == null ? "" : String(text)
    return div.innerHTML
  }
}
