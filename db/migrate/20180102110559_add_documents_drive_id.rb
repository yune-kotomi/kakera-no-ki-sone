class AddDocumentsDriveId < ActiveRecord::Migration[5.1]
  def change
    add_column :documents, :drive_id, :string
  end
end
