class CreateDocuments < ActiveRecord::Migration
  def change
    create_table :documents do |t|
      t.string :title, :default => '新しい文書', :null => false
      t.text :description
      t.jsonb :body
      t.boolean :public, :default => false, :null => false
      t.boolean :archived, :default => false, :null => false
      t.string :password
      t.string :markup, :default => :plaintext, :null => false

      t.integer :user_id

      t.timestamp :content_updated_at, :null => false
      t.timestamps null: false
    end

    add_index :documents, :title, :using => 'pgroonga'
    add_index :documents, :description, :using => 'pgroonga'
    add_index :documents, :body, :using => 'pgroonga'
  end
end
