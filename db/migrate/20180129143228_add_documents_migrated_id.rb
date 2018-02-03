class AddDocumentsMigratedId < ActiveRecord::Migration[5.1]
  def change
    add_column :documents, :google_document_id, :string
  end
end
