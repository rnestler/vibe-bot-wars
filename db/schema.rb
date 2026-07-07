# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_07_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bots", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.boolean "downed", default: false, null: false
    t.bigint "game_id", null: false
    t.integer "gems_collected", default: 0, null: false
    t.string "heading", default: "N", null: false
    t.integer "hp", default: 100, null: false
    t.string "last_command"
    t.datetime "last_contacted_at"
    t.string "last_error"
    t.string "name", null: false
    t.string "secret"
    t.datetime "updated_at", null: false
    t.integer "vision_radius", default: 1, null: false
    t.string "webhook_host"
    t.string "webhook_url", null: false
    t.integer "x"
    t.integer "y"
    t.index ["game_id"], name: "index_bots_on_game_id"
    t.index ["name"], name: "index_bots_on_name", unique: true
    t.index ["webhook_host"], name: "index_bots_on_webhook_host", unique: true
  end

  create_table "games", force: :cascade do |t|
    t.integer "collision_damage", default: 15, null: false
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "gem_count", default: 15, null: false
    t.jsonb "gems", default: [], null: false
    t.integer "height", default: 20, null: false
    t.integer "max_hp", default: 100, null: false
    t.integer "max_ticks", default: 400, null: false
    t.integer "repair_amount", default: 20, null: false
    t.integer "scan_radius", default: 4, null: false
    t.datetime "started_at"
    t.string "status", default: "setup", null: false
    t.integer "tick", default: 0, null: false
    t.integer "tick_ms", default: 500, null: false
    t.datetime "updated_at", null: false
    t.integer "vision_radius", default: 1, null: false
    t.integer "wall_damage", default: 10, null: false
    t.jsonb "walls", default: [], null: false
    t.integer "webhook_timeout_ms", default: 400, null: false
    t.integer "width", default: 20, null: false
    t.bigint "winner_bot_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  add_foreign_key "bots", "games"
end
