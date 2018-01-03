class CreateGoogleTokens < ActiveRecord::Migration[5.1]
  def change
    create_table :google_tokens do |t|
      t.string :token_id
      t.jsonb :token

      t.timestamps
    end
  end
end
