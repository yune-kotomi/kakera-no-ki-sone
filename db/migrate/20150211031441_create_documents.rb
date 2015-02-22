class CreateDocuments < ActiveRecord::Migration
  def change
    create_table :documents do |t|
      t.string :title, :default => '新しい文書', :null => false
      t.text :description
      t.text :body_yaml, :default => '--- []', :null => false
      t.text :fulltext
      t.boolean :private, :default => true, :null => false
      t.boolean :archived, :default => false, :null => false
      t.string :password
      t.string :markup, :default => :plaintext, :null => false
      t.integer :user_id

      t.timestamps null: false
    end

    add_index :documents, :fulltext, :using => 'pgroonga'
  end
end
