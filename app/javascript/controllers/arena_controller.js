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
    this.render(this.stateValue)
    this.subscription = consumer.subscriptions.create("ArenaChannel", {
      received: (data) => this.render(data),
    })
  }

  disconnect() {
    if (this.subscription) this.subscription.unsubscribe()
  }

  render(state) {
    if (!state || !state.width) return
    this.drawGrid(state)
    this.updateScoreboard(state)
    this.updateResults(state)
    if (this.hasTickTarget) this.tickTarget.textContent = `${state.tick} / ${state.max_ticks}`
    if (this.hasStatusTarget) this.statusTarget.textContent = this.statusLabel(state)
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
  }

  updateScoreboard(state) {
    if (!this.hasScoreboardTarget) return
    const rows = [...(state.bots || [])].sort((a, b) => b.gems - a.gems)
    this.scoreboardTarget.innerHTML = rows.map((b) => this.scoreRow(b)).join("")
  }

  scoreRow(bot) {
    const frac = Math.max(0, Math.round((bot.hp / (bot.max_hp || 100)) * 100))
    const status = bot.downed
      ? '<span class="tag tag--downed">downed</span>'
      : bot.last_error
        ? `<span class="tag tag--error" title="${this.escape(bot.last_error)}">webhook error</span>`
        : `<span class="tag">${this.escape(bot.last_command || "—")}</span>`
    return `
      <tr>
        <td><span class="swatch" style="background:${this.botColor(bot.id)}"></span>${this.escape(bot.name)}</td>
        <td>${this.escape(bot.group_label || "—")}</td>
        <td class="num">${bot.gems}</td>
        <td><div class="hpbar"><div class="hpbar__fill" style="width:${frac}%"></div></div></td>
        <td>${status}</td>
      </tr>`
  }

  // Overall best bot, best bot per group, and each group's average score. Labels switch
  // between "leading" (mid-match) and "winner" (finished).
  updateResults(state) {
    if (!this.hasResultsTarget) return
    const finished = state.status === "finished"
    const bots = state.bots || []
    const overall = bots.find((b) => b.id === state.overall_best_id)
    const groups = [...(state.groups || [])].sort((a, b) => b.average - a.average)

    if (!overall && groups.every((g) => g.size === 0)) {
      this.resultsTarget.innerHTML = ""
      return
    }

    const overallLine = overall
      ? `<span class="swatch" style="background:${this.botColor(overall.id)}"></span>
         <b>${this.escape(overall.name)}</b> — ${overall.gems} gems`
      : "—"

    const rows = groups
      .map(
        (g) => `
        <tr>
          <td>${this.escape(g.label)}</td>
          <td>${g.best_bot_name ? `${this.escape(g.best_bot_name)} (${g.best_bot_gems})` : "—"}</td>
          <td class="num">${g.average}</td>
          <td class="num">${g.size}</td>
        </tr>`,
      )
      .join("")

    this.resultsTarget.innerHTML = `
      <h2>${finished ? "Final results" : "Standings"}</h2>
      <p class="muted" style="margin:0 0 10px">${finished ? "Winner overall" : "Leading overall"}: ${overallLine}</p>
      <table class="score">
        <thead>
          <tr><th>Group</th><th>${finished ? "Winner" : "Leader"}</th><th class="num">Avg</th><th class="num">Bots</th></tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>`
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
