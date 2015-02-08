class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :domain_name
      t.string :screen_name
      t.string :nickname
      t.text :profile_text
      t.string :default_markup, :default => :plaintext, :null => false
      t.integer :kitaguchi_profile_id

      t.timestamps null: false
    end
  end
end
