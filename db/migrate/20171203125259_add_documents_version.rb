class AddDocumentsVersion < ActiveRecord::Migration[5.1]
  def up
    execute 'CREATE SEQUENCE document_version_seq'
    add_column :documents, :version, :integer
  end

  def down
    execute 'DROP SEQUENCE document_version_seq'
    remove_column :documents, :version
  end
end
