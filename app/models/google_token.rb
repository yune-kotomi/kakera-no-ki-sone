class GoogleToken < ApplicationRecord
  def credential
    data = JSON.parse(token)
    client_id = Google::Auth::ClientId.from_hash(Sone::Application.config.google)

    Google::Auth::UserRefreshCredentials.new(
      client_id: client_id.id,
      client_secret: client_id.secret,
      scope: data['scope'],
      access_token: data['access_token'],
      refresh_token: data['refresh_token'],
      expires_at: data.fetch('expiration_time_millis', 0) / 1000
    )
  end

  class TokenStore < Google::Auth::TokenStore
    def load(id)
      t = GoogleToken.where(:token_id => id).first
      t.token unless t.nil?
    end

    def store(id, token)
      GoogleToken.transaction do
        t = GoogleToken.where(:token_id => id).first
        t = GoogleToken.new(:token_id => id) if t.nil?
        t.token = token
        t.save
      end
    end

    def delete(id)
      GoogleToken.transaction do
        t = GoogleToken.where(:token_id => id).first
        t.update_attribute(:token, nil) unless t.nil?
      end
    end
  end
end
