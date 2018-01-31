class AddUsersMigrationStarted < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :migration_started, :boolean
  end
end
