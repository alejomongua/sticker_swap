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

ActiveRecord::Schema[8.1].define(version: 2026_05_12_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "group_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "group_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["group_id", "user_id"], name: "index_group_memberships_on_group_id_and_user_id", unique: true
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["user_id"], name: "index_group_memberships_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.datetime "created_at", null: false
    t.string "invitation_code", null: false
    t.string "name", null: false
    t.boolean "registration_open", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_groups_on_admin_user_id"
    t.index ["invitation_code"], name: "index_groups_on_invitation_code", unique: true
  end

  create_table "inventory_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "quantity", default: 1, null: false
    t.integer "status", null: false
    t.bigint "sticker_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["sticker_id"], name: "index_inventory_items_on_sticker_id"
    t.index ["user_id", "status"], name: "index_inventory_items_on_user_id_and_status"
    t.index ["user_id", "sticker_id"], name: "index_inventory_items_on_user_id_and_sticker_id", unique: true
    t.index ["user_id"], name: "index_inventory_items_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stickers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "group_name", default: "", null: false
    t.string "name"
    t.integer "number", null: false
    t.string "photo"
    t.string "prefix", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["group_name"], name: "index_stickers_on_group_name"
    t.index ["prefix", "number"], name: "index_stickers_on_prefix_and_number", unique: true
  end

  create_table "swap_offers", force: :cascade do |t|
    t.bigint "countered_from_id"
    t.datetime "created_at", null: false
    t.bigint "group_id"
    t.integer "offered_sticker_ids", default: [], null: false, array: true
    t.bigint "receiver_id", null: false
    t.integer "requested_sticker_ids", default: [], null: false, array: true
    t.datetime "responded_at"
    t.bigint "sender_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["countered_from_id"], name: "index_swap_offers_on_countered_from_id"
    t.index ["group_id"], name: "index_swap_offers_on_group_id"
    t.index ["receiver_id", "status"], name: "index_swap_offers_on_receiver_id_and_status"
    t.index ["receiver_id"], name: "index_swap_offers_on_receiver_id"
    t.index ["sender_id", "status"], name: "index_swap_offers_on_sender_id_and_status"
    t.index ["sender_id"], name: "index_swap_offers_on_sender_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "active_group_id"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.boolean "receive_offer_notifications", default: true, null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["active_group_id"], name: "index_users_on_active_group_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "group_memberships", "groups"
  add_foreign_key "group_memberships", "users"
  add_foreign_key "groups", "users", column: "admin_user_id"
  add_foreign_key "inventory_items", "stickers"
  add_foreign_key "inventory_items", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "swap_offers", "groups"
  add_foreign_key "swap_offers", "swap_offers", column: "countered_from_id"
  add_foreign_key "swap_offers", "users", column: "receiver_id"
  add_foreign_key "swap_offers", "users", column: "sender_id"
  add_foreign_key "users", "groups", column: "active_group_id"
end
