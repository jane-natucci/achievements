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

ActiveRecord::Schema[8.1].define(version: 2026_08_12_081952) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "achievements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "game_id", null: false
    t.boolean "hidden"
    t.string "icon_locked"
    t.string "icon_unlocked"
    t.string "steam_api_name"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["game_id", "steam_api_name"], name: "index_achievements_on_game_id_and_steam_api_name", unique: true
    t.index ["game_id"], name: "index_achievements_on_game_id"
  end

  create_table "chain_edges", force: :cascade do |t|
    t.bigint "chain_id", null: false
    t.datetime "created_at", null: false
    t.string "edge_type"
    t.bigint "from_node"
    t.bigint "to_node"
    t.datetime "updated_at", null: false
    t.index ["chain_id"], name: "index_chain_edges_on_chain_id"
    t.index ["from_node"], name: "index_chain_edges_on_from_node"
    t.index ["to_node"], name: "index_chain_edges_on_to_node"
  end

  create_table "chain_nodes", force: :cascade do |t|
    t.bigint "chain_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "node_type"
    t.text "note"
    t.integer "position_x"
    t.integer "position_y"
    t.bigint "ref_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["chain_id"], name: "index_chain_nodes_on_chain_id"
  end

  create_table "chains", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_user_id"
    t.text "description"
    t.datetime "discarded_at"
    t.integer "featured_score"
    t.bigint "game_id", null: false
    t.string "slug"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "visibility"
    t.index ["creator_user_id"], name: "index_chains_on_creator_user_id"
    t.index ["discarded_at"], name: "index_chains_on_discarded_at"
    t.index ["game_id"], name: "index_chains_on_game_id"
    t.index ["slug"], name: "index_chains_on_slug", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "commentable_id", null: false
    t.string "commentable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "games", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name"
    t.integer "steam_app_id"
    t.datetime "updated_at", null: false
  end

  create_table "user_achievement_favorites", force: :cascade do |t|
    t.bigint "achievement_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["achievement_id"], name: "index_user_achievement_favorites_on_achievement_id"
    t.index ["user_id", "achievement_id"], name: "index_user_achievement_favorites_on_user_id_and_achievement_id", unique: true
    t.index ["user_id"], name: "index_user_achievement_favorites_on_user_id"
  end

  create_table "user_chain_progresses", force: :cascade do |t|
    t.bigint "chain_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.boolean "favorite"
    t.boolean "pinned"
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["chain_id"], name: "index_user_chain_progresses_on_chain_id"
    t.index ["user_id", "chain_id"], name: "index_user_chain_progresses_on_user_id_and_chain_id", unique: true
    t.index ["user_id"], name: "index_user_chain_progresses_on_user_id"
  end

  create_table "user_node_progresses", force: :cascade do |t|
    t.bigint "chain_node_id", null: false
    t.datetime "created_at", null: false
    t.string "source"
    t.string "status"
    t.datetime "unlocked_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["chain_node_id"], name: "index_user_node_progresses_on_chain_node_id"
    t.index ["user_id", "chain_node_id"], name: "index_user_node_progresses_on_user_id_and_chain_node_id", unique: true
    t.index ["user_id"], name: "index_user_node_progresses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.datetime "games_synced_at"
    t.string "steam_id", null: false
    t.integer "total_xp", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["steam_id"], name: "index_users_on_steam_id", unique: true
  end

  create_table "xp_events", force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.string "reason", null: false
    t.bigint "subject_id"
    t.string "subject_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["subject_type", "subject_id"], name: "index_xp_events_on_subject"
    t.index ["user_id", "created_at"], name: "index_xp_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_xp_events_on_user_id"
  end

  add_foreign_key "achievements", "games"
  add_foreign_key "chain_edges", "chain_nodes", column: "from_node"
  add_foreign_key "chain_edges", "chain_nodes", column: "to_node"
  add_foreign_key "chain_edges", "chains"
  add_foreign_key "chain_nodes", "chains"
  add_foreign_key "chains", "games"
  add_foreign_key "comments", "users"
  add_foreign_key "user_achievement_favorites", "achievements"
  add_foreign_key "user_achievement_favorites", "users"
  add_foreign_key "user_chain_progresses", "chains"
  add_foreign_key "user_chain_progresses", "users"
  add_foreign_key "user_node_progresses", "chain_nodes"
  add_foreign_key "user_node_progresses", "users"
  add_foreign_key "xp_events", "users"
end
