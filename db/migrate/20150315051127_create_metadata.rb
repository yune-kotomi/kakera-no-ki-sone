class CreateMetadata < ActiveRecord::Migration
  def change
    create_table :metadata do |t|
      t.text :body_yaml
      t.integer :document_id

      t.timestamps null: false
    end
  end
end
