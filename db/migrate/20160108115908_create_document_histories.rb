class CreateDocumentHistories < ActiveRecord::Migration
  def change
    create_table :document_histories do |t|
      t.integer :document_id

      t.string :title
      t.text :description
      t.jsonb :body

      t.timestamps null: false
    end
  end
end
