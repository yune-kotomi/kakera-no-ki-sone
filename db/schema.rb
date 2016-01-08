# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160108115908) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "pgroonga"

  create_table "document_histories", force: :cascade do |t|
    t.integer  "document_id"
    t.string   "title"
    t.text     "description"
    t.jsonb    "body"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "documents", force: :cascade do |t|
    t.string   "title",              default: "新しい文書",     null: false
    t.text     "description"
    t.jsonb    "body"
    t.boolean  "public",             default: false,       null: false
    t.boolean  "archived",           default: false,       null: false
    t.string   "bcrypt_password"
    t.string   "markup",             default: "plaintext", null: false
    t.integer  "user_id"
    t.datetime "content_updated_at",                       null: false
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
  end

  add_index "documents", ["body"], name: "index_documents_on_body", using: :pgroonga
  add_index "documents", ["description"], name: "index_documents_on_description", using: :pgroonga
  add_index "documents", ["title"], name: "index_documents_on_title", using: :pgroonga

  create_table "users", force: :cascade do |t|
    t.string   "domain_name"
    t.string   "screen_name"
    t.string   "nickname"
    t.text     "profile_text"
    t.string   "default_markup",       default: "plaintext", null: false
    t.integer  "kitaguchi_profile_id"
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

end
